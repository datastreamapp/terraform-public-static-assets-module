# Changelog

## [v6.1.0] — 2026-05-28

### Added
- **route53-kms**: `moved {}` blocks for consumers upgrading from v4.x (the `aws_kms_key.route53` → `aws_kms_key.main` rename now migrates cleanly without resource destruction)
- **route53-kms**: deprecated `arn` output alias for backward compat (will be removed in v7.0.0; use `kms_key_arn` for new code)

### Changed (restoration)
- **cloudfront**: restored v2 logging via `aws_cloudwatch_log_delivery_*` resources (deleted in v6.0.2). Athena consumers depending on `{yyyy}/{MM}/{dd}/{HH}` partition path will continue to work.
- **cloudfront**: removed legacy `logging_config {}` block from `aws_cloudfront_distribution.main` (re-introduced in v6.0.2). v2 logging takes its place.
- **cloudfront**: re-added `logging_hive_compatible_path` variable (removed in v6.0.2)

### Migration notes (v5.x → v6.1.0)

- The KMS resource rename (`aws_kms_key.route53` → `aws_kms_key.main`, `aws_kms_alias.route53` → `aws_kms_alias.main`) that happened pre-v5 is now handled cleanly by `moved {}` blocks. Consumers bumping from v4.x will see plan reconciliation, not destroy/recreate.
- The deprecated `arn` output is kept as an alias for `kms_key_arn`. New code should use `kms_key_arn`. The `arn` output will be removed in v7.0.0.
- v2 CloudFront logging (`aws_cloudwatch_log_delivery_*`) is preserved with the `{yyyy}/{MM}/{dd}/{HH}` S3 path layout matching v5.1.0 behavior, so Athena partition projections continue to work without consumer-side schema changes.

## [v6.0.4] — 2026-05-05 (previous release)
See git history for v6.0.0 through v6.0.4 changes.
