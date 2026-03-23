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
  count                   = var.logging_bucket != null ? 1 : 0
  delivery_source_name    = aws_cloudwatch_log_delivery_source.main[0].name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.main[0].arn

  s3_delivery_configuration {
    enable_hive_compatible_path = var.logging_hive_compatible_path
    suffix_path                 = "${var.aliases[0]}/{yyyy}/{MM}/{dd}/{HH}"
  }
}