mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  mock_resource "aws_cloudfront_distribution" {
    defaults = {
      arn         = "arn:aws:cloudfront::123456789012:distribution/E1ABCDEF"
      id          = "E1ABCDEF"
      domain_name = "d111111abcdef8.cloudfront.net"
    }
  }
  mock_resource "aws_cloudwatch_log_delivery_destination" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:delivery-destination:test-dest"
    }
  }
  mock_resource "aws_cloudwatch_log_delivery_source" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:delivery-source:test-src"
    }
  }
}

variables {
  name    = "example-app-com"
  aliases = ["example.app.com"]
  origins = [
    {
      origin_id   = "s3-origin"
      type        = "s3"
      domain_name = "example-bucket.s3.amazonaws.com"
    }
  ]
  behaviors = [
    {
      origin_id = "s3-origin"
    }
  ]
}

# --- v2 logging: disabled when logging_bucket is null (default) ---

run "logging_disabled_when_bucket_null" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_log_delivery_destination.main) == 0
    error_message = "aws_cloudwatch_log_delivery_destination must not be created when logging_bucket is null"
  }

  assert {
    condition     = length(aws_cloudwatch_log_delivery_source.main) == 0
    error_message = "aws_cloudwatch_log_delivery_source must not be created when logging_bucket is null"
  }

  assert {
    condition     = length(aws_cloudwatch_log_delivery.main) == 0
    error_message = "aws_cloudwatch_log_delivery must not be created when logging_bucket is null"
  }
}

# --- v2 logging: all three resources created when logging_bucket is set ---

run "logging_enabled_creates_destination" {
  command = plan

  variables {
    logging_bucket = "example-app-logs"
  }

  assert {
    condition     = length(aws_cloudwatch_log_delivery_destination.main) == 1
    error_message = "aws_cloudwatch_log_delivery_destination must be created when logging_bucket is set"
  }

  assert {
    condition     = aws_cloudwatch_log_delivery_destination.main[0].name == "example-app-com-logs"
    error_message = "log delivery destination name must be \"$${var.name}-logs\""
  }

  assert {
    condition     = aws_cloudwatch_log_delivery_destination.main[0].delivery_destination_configuration[0].destination_resource_arn == "arn:aws:s3:::example-app-logs"
    error_message = "destination_resource_arn must reference the configured S3 bucket"
  }
}

run "logging_enabled_creates_source" {
  command = plan

  variables {
    logging_bucket = "example-app-logs"
  }

  assert {
    condition     = length(aws_cloudwatch_log_delivery_source.main) == 1
    error_message = "aws_cloudwatch_log_delivery_source must be created when logging_bucket is set"
  }

  assert {
    condition     = aws_cloudwatch_log_delivery_source.main[0].name == "example-app-com"
    error_message = "log delivery source name must equal var.name"
  }

  assert {
    condition     = aws_cloudwatch_log_delivery_source.main[0].log_type == "ACCESS_LOGS"
    error_message = "log delivery source log_type must be ACCESS_LOGS"
  }
}

run "logging_enabled_creates_delivery" {
  command = plan

  variables {
    logging_bucket = "example-app-logs"
  }

  assert {
    condition     = length(aws_cloudwatch_log_delivery.main) == 1
    error_message = "aws_cloudwatch_log_delivery must be created when logging_bucket is set"
  }

  assert {
    condition     = aws_cloudwatch_log_delivery.main[0].s3_delivery_configuration[0].suffix_path == "example.app.com/{yyyy}/{MM}/{dd}/{HH}"
    error_message = "suffix_path must follow \"$${aliases[0]}/{yyyy}/{MM}/{dd}/{HH}\" format"
  }
}

# --- logging_hive_compatible_path: default and override ---

run "hive_compatible_path_defaults_false" {
  command = plan

  variables {
    logging_bucket = "example-app-logs"
  }

  assert {
    condition     = var.logging_hive_compatible_path == false
    error_message = "logging_hive_compatible_path must default to false"
  }

  assert {
    condition     = aws_cloudwatch_log_delivery.main[0].s3_delivery_configuration[0].enable_hive_compatible_path == false
    error_message = "enable_hive_compatible_path must default to false on the log delivery"
  }
}

run "hive_compatible_path_override_true" {
  command = plan

  variables {
    logging_bucket               = "example-app-logs"
    logging_hive_compatible_path = true
  }

  assert {
    condition     = aws_cloudwatch_log_delivery.main[0].s3_delivery_configuration[0].enable_hive_compatible_path == true
    error_message = "enable_hive_compatible_path must propagate var.logging_hive_compatible_path = true"
  }
}

# --- Legacy logging_config removal: distribution must NOT carry a logging_config block ---

run "distribution_has_no_legacy_logging_config" {
  command = plan

  variables {
    logging_bucket = "example-app-logs"
  }

  # v6.x removes the legacy `logging_config` block on the distribution and
  # routes access logs through aws_cloudwatch_log_delivery_* resources instead.
  # Reading a removed-or-never-set block returns an empty list.
  assert {
    condition     = length(aws_cloudfront_distribution.main.logging_config) == 0
    error_message = "aws_cloudfront_distribution.main must not declare a legacy logging_config block in v6.x (replaced by aws_cloudwatch_log_delivery_*)"
  }
}
