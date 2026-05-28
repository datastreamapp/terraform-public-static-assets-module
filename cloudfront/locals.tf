data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region     = data.aws_region.current.region
  tags       = var.default_tags
  # Sanitize name: replace any character that is not a letter, number, or hyphen
  # with a hyphen. This makes var.name safe for AWS resource names (CloudWatch
  # log groups, log delivery sources, S3 prefixes) regardless of what the
  # consumer passes in. Replaces what terraform-defaults did externally.
  name              = replace(var.name, "/[^a-zA-Z0-9-]/", "-")
  name_alphanumeric = replace(var.name, "/[^a-zA-Z0-9]/", "")
  account_id        = data.aws_caller_identity.current.account_id

  origins = concat(var.origins, var.origin_groups)

  #sse_algorithm = "AES256"

  logging_bucket = var.logging_bucket != "" ? var.logging_bucket : "${local.name}-${terraform.workspace}-edge-logs"
}

