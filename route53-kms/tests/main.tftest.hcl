mock_provider "aws" {
  mock_resource "aws_kms_key" {
    defaults = {
      arn    = "arn:aws:kms:us-east-1:123456789012:key/abcd1234-ef56-7890-abcd-ef1234567890"
      key_id = "abcd1234-ef56-7890-abcd-ef1234567890"
    }
  }
  mock_resource "aws_kms_alias" {
    defaults = {
      arn = "arn:aws:kms:us-east-1:123456789012:alias/route53"
    }
  }
}

# --- KMS key + alias creation ---

run "kms_key_created" {
  command = plan

  assert {
    condition     = aws_kms_key.main.key_usage == "SIGN_VERIFY"
    error_message = "aws_kms_key.main must use SIGN_VERIFY for Route53 DNSSEC"
  }

  assert {
    condition     = aws_kms_key.main.customer_master_key_spec == "ECC_NIST_P256"
    error_message = "aws_kms_key.main must use ECC_NIST_P256 spec (required by Route53 DNSSEC)"
  }

  assert {
    condition     = aws_kms_key.main.deletion_window_in_days == 7
    error_message = "aws_kms_key.main must have deletion_window_in_days == 7"
  }
}

run "kms_alias_created" {
  command = plan

  assert {
    condition     = aws_kms_alias.main.name == "alias/route53"
    error_message = "aws_kms_alias.main must be named alias/route53"
  }
}

# --- Policy: Route53 DNSSEC service permissions ---

run "policy_allows_route53_dnssec" {
  command = plan

  assert {
    condition     = strcontains(aws_kms_key.main.policy, "dnssec-route53.amazonaws.com")
    error_message = "KMS key policy must allow the dnssec-route53 service principal"
  }

  assert {
    condition     = strcontains(aws_kms_key.main.policy, "kms:Sign")
    error_message = "KMS key policy must grant kms:Sign to Route53 DNSSEC"
  }

  assert {
    condition     = strcontains(aws_kms_key.main.policy, "kms:CreateGrant")
    error_message = "KMS key policy must grant kms:CreateGrant to Route53 DNSSEC"
  }
}

# --- Outputs: deprecated arn aliases kms_key_arn ---

run "arn_alias_matches_kms_key_arn" {
  command = apply

  assert {
    condition     = output.arn == output.kms_key_arn
    error_message = "Deprecated arn output should alias to kms_key_arn"
  }
}

run "kms_key_arn_output_set" {
  command = apply

  assert {
    condition     = output.kms_key_arn == aws_kms_key.main.arn
    error_message = "kms_key_arn output must equal aws_kms_key.main.arn"
  }
}
