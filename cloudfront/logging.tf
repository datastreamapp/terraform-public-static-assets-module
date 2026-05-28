# CloudFront access logging via the v2 logging API (aws_cloudwatch_log_delivery_*).
#
# This file was deleted in v6.0.2 and the module reverted to the legacy `logging_config {}`
# block inside `aws_cloudfront_distribution.main`. v6.0.2's legacy logging writes flat
# files (no `{yyyy}/{MM}/{dd}/{HH}/` subdirectories), which silently breaks downstream
# Athena partition projection queries that depend on the time-partitioned layout.
#
# v6.1.0 restored this file bit-for-bit from v5.1.0 and removed the legacy `logging_config`
# block in cloudfront.tf so a distribution gets exactly one logging mechanism (this one).
#
# The `suffix_path` value below is a PUBLIC CONTRACT with downstream Athena consumers.
# Changing it requires coordinated schema migration in every consumer's Athena tables.
# See docs/DECISIONS.md (v6.1.0 — Restore v2 CloudFront logging) for full rationale.
#
# Test coverage: cloudfront/tests/logging.tftest.hcl (7 tests):
#   - logging_disabled_when_bucket_null
#   - logging_enabled_creates_destination / _source / _delivery
#   - hive_compatible_path_defaults_false / _override_true
#   - distribution_has_no_legacy_logging_config

resource "aws_cloudwatch_log_delivery_destination" "main" {
  count = var.logging_bucket != null ? 1 : 0
  name  = "${var.name}-logs"

  delivery_destination_configuration {
    destination_resource_arn = "arn:aws:s3:::${var.logging_bucket}"
  }
}

resource "aws_cloudwatch_log_delivery_source" "main" {
  count        = var.logging_bucket != null ? 1 : 0
  name         = var.name
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.main.arn
}

resource "aws_cloudwatch_log_delivery" "main" {
  count                    = var.logging_bucket != null ? 1 : 0
  delivery_source_name     = aws_cloudwatch_log_delivery_source.main[0].name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.main[0].arn

  s3_delivery_configuration {
    enable_hive_compatible_path = var.logging_hive_compatible_path
    suffix_path                 = "${var.aliases[0]}/{yyyy}/{MM}/{dd}/{HH}"
  }
}
