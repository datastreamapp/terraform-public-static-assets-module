mock_provider "aws" {}

# Shared base variables — satisfy all required inputs with minimal fixtures.
variables {
  name    = "test-distribution"
  aliases = ["test.example.com"]
  origins = [{
    origin_id   = "app"
    domain_name = "app.example.com"
  }]
  behaviors = [{
    origin_id = "app"
  }]
}

# Empty overrides — identical to v5.1.0 behaviour (backwards-compat).
run "empty_overrides_accepted" {
  command = plan
}

# Valid overrides — 502/504 → 503 (the primary use case for #1884).
# Asserts the mapping actually produces response_code = 503, not just that plan succeeds.
run "valid_overrides_accepted" {
  command = plan
  variables {
    error_codes = {
      "502" = "/en/maintenance.html"
      "504" = "/en/maintenance.html"
    }
    error_code_response_overrides = {
      "502" = 503
      "504" = 503
    }
  }
  assert {
    condition = one([
      for r in aws_cloudfront_distribution.main.custom_error_response :
      r.response_code if r.error_code == 502
    ]) == 503
    error_message = "502 origin error must produce response_code 503, not 502"
  }
  assert {
    condition = one([
      for r in aws_cloudfront_distribution.main.custom_error_response :
      r.response_code if r.error_code == 504
    ]) == 503
    error_message = "504 origin error must produce response_code 503, not 504"
  }
}

# Partial overrides — only some error_codes have an override; others fall back.
# Asserts the fallback branch of try(): overridden code uses override, un-overridden falls back.
run "partial_overrides_accepted" {
  command = plan
  variables {
    error_codes = {
      "500" = "/en/maintenance.html"
      "502" = "/en/maintenance.html"
      "504" = "/en/maintenance.html"
    }
    error_code_response_overrides = {
      "502" = 503
    }
  }
  assert {
    condition = one([
      for r in aws_cloudfront_distribution.main.custom_error_response :
      r.response_code if r.error_code == 502
    ]) == 503
    error_message = "502 with override must produce response_code 503"
  }
  assert {
    condition = one([
      for r in aws_cloudfront_distribution.main.custom_error_response :
      r.response_code if r.error_code == 500
    ]) == 500
    error_message = "500 with no override must fall back to response_code 500"
  }
  assert {
    condition = one([
      for r in aws_cloudfront_distribution.main.custom_error_response :
      r.response_code if r.error_code == 504
    ]) == 504
    error_message = "504 with no override must fall back to response_code 504"
  }
}

# Override to 200 — valid CloudFront response code (mask errors as success).
run "override_to_200_accepted" {
  command = plan
  variables {
    error_codes = {
      "404" = "/en/not-found.html"
    }
    error_code_response_overrides = {
      "404" = 200
    }
  }
}

# Invalid response code — must be rejected at plan, not at apply.
run "invalid_response_code_rejected" {
  command = plan
  variables {
    error_codes = {
      "502" = "/en/maintenance.html"
    }
    error_code_response_overrides = {
      "502" = 999
    }
  }
  expect_failures = [var.error_code_response_overrides]
}

# Another invalid value — 600 is not a valid CloudFront response code.
run "response_code_600_rejected" {
  command = plan
  variables {
    error_codes = {
      "504" = "/en/maintenance.html"
    }
    error_code_response_overrides = {
      "504" = 600
    }
  }
  expect_failures = [var.error_code_response_overrides]
}
