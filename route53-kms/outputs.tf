output "kms_key_arn" {
  value = aws_kms_key.main.arn
}

# DEPRECATED: use kms_key_arn instead. Kept for v4.x → v6.x backward compat. Remove in v7.0.0.
output "arn" {
  value       = aws_kms_key.main.arn
  description = "DEPRECATED: use kms_key_arn instead. Will be removed in v7.0.0."
}