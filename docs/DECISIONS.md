# Architecture Decisions

This document captures non-obvious decisions made about this module's design and evolution. Each entry is an ADR-lite: context, decision, consequences.

Newest entries first.

---

## 2026-05-28 — v6.1.0: Restore var.default_tags passthrough in cloudfront/locals.tf

### Context

v6.0.2's "remove use of defaults" commit replaced `tags = module.defaults.tags` with
`tags = {}` in `cloudfront/locals.tf`. The old `terraform-defaults` third-party module
(sourced from `git@github.com:willfarrell/terraform-defaults`) had been auto-injecting
tags like `Environment`, `Terraform: true`, `Description` into every CloudFront distribution.
When that dependency was removed, the hardcoded `tags = {}` silently dropped all those tags
from every CloudFront resource on the next consumer apply.

The `variable "default_tags"` remained in `variables.tf` with `default = {}` — it was just
never wired up in locals after the removal.

Discovered during dry-run `terraform plan` of the Phase 1 consumer migration (datastreamapp/issues#1891).

### Decision

Restored the passthrough: `tags = var.default_tags` in `cloudfront/locals.tf`.

Consumer behavior:
- Consumers NOT passing `default_tags` → `tags = {}` (same as v6.0.2 behavior, no regression)
- Consumers passing `default_tags = {...}` → tags forwarded to CloudFront resources as before
- Consumers using AWS provider `default_tags` block → tags flow via `tags_all` regardless; `var.default_tags` is additive

### Consequences

- Tag ownership in plans: when a consumer uses AWS provider `default_tags` + our restored passthrough,
  Terraform shows `.tags` shrinking and `.tags_all` growing — because tags shift from resource-level
  to provider-level ownership. AWS-side tags are preserved; only the Terraform tracking mechanism changes.
- A plan running with `default_tags` uncommented will show `tags_all` updates on ALL resources that
  provider manages (not just CloudFront) — this is expected behavior, not a regression.
- Future maintainers: do NOT hardcode `tags = {}` when removing tag-injection dependencies. Always
  preserve the `var.default_tags` passthrough so consumers retain control.

---

## 2026-05-28 — v6.1.0: Restore v2 CloudFront logging

### Context

Between v5.1.0 and v6.0.2, `cloudfront/logging.tf` was deleted and replaced with the legacy `logging_config {}` block inside `aws_cloudfront_distribution.main`.

**Why it was deleted — and why that matters.** The deletion happened in commit `a4539d4` (message: "remove use of defaults"), authored during the v6.0.x series. The commit's stated purpose was to remove a third-party `terraform-defaults` module that had been sourced in `cloudfront/locals.tf` — a reasonable cleanup. The deletion of `logging.tf` appears to have been an unintentional side effect of that refactor, not a deliberate decision to change the logging mechanism.

There was no CHANGELOG entry, no issue, no PR discussion, and no migration guide explaining that the S3 log path layout had changed. Consumers had no signal that upgrading to v6.0.x would silently break their Athena queries. The breakage was invisible at plan time — it would only surface later, when someone queried CloudFront logs in Athena and got zero rows.

This is exactly why `docs/DECISIONS.md` exists in v6.1.0: so that future engineers making changes to this module understand the downstream contracts before touching logging, path layout, or anything Athena consumers depend on.

The two approaches differ critically in their S3 path layout:

| Logging mode | S3 path layout |
|---|---|
| v2 API (`aws_cloudwatch_log_delivery_*` with `suffix_path`) | `AWSLogs/{account}/CloudFront/{domain}/{yyyy}/{MM}/{dd}/{HH}/` |
| Legacy `logging_config` block | `AWSLogs/{account}/CloudFront/{domain}/` (flat — no time partitions) |

The flat layout silently breaks any consumer whose Athena tables use **partition projection** on `year`/`month`/`day`/`hour` — partition discovery finds no logs because they're not in the expected subdirectory hierarchy.

A real consumer of this module (`datastreamapp/infrastructure terraform/environments/edge/athena.tf:166,357,550`) defines three Glue tables with exactly this partition projection. v6.0.2's flat-logging change would silently degrade those queries to zero results. The breakage would only surface when someone tried to query CloudFront logs and got an empty response.

### Decision

In v6.1.0:

1. **Restored `cloudfront/logging.tf`** bit-for-bit from v5.1.0 — three resources (`aws_cloudwatch_log_delivery_destination`, `aws_cloudwatch_log_delivery_source`, `aws_cloudwatch_log_delivery`) gated by `count = var.logging_bucket != null ? 1 : 0`, with the critical `suffix_path = "${aliases[0]}/{yyyy}/{MM}/{dd}/{HH}"` value preserved.
2. **Removed the legacy `logging_config {}` block** from `aws_cloudfront_distribution.main` in `cloudfront/cloudfront.tf` (to avoid double-logging or conflicting log destinations).
3. **Re-added the `logging_hive_compatible_path` variable** in `cloudfront/variables.tf` that was removed in v6.0.2.
4. **Added 7 `terraform test` cases** in `cloudfront/tests/logging.tftest.hcl` to lock in this behavior so it can't be silently reverted again without test failure.

### Side effects analysis

#### Intended effects (the point of the restoration)

1. **CloudFront access logs return to partitioned path layout** — `AWSLogs/{account}/CloudFront/{domain}/{yyyy}/{MM}/{dd}/{HH}/` instead of v6.0.2's flat `AWSLogs/{account}/CloudFront/{domain}/` layout. Downstream Athena partition projections keep working.
2. **Three resources reappear in state** — `aws_cloudwatch_log_delivery_destination.main`, `aws_cloudwatch_log_delivery_source.main`, `aws_cloudwatch_log_delivery.main` (gated by `count = var.logging_bucket != null ? 1 : 0`).
3. **Legacy `logging_config {}` block removed** from `aws_cloudfront_distribution.main` in the same release — prevents double-logging.

#### Per-consumer-state plan outcomes

| Consumer state | Plan outcome on bumping to v6.1.0 |
|---|---|
| Already on v5.1.0 (had v2 logging) | Plan is ~no-op for logging resources |
| Was on v6.0.2–v6.0.4 (had legacy `logging_config`) | Plan shows: legacy `logging_config` removed from distribution + 3 `aws_cloudwatch_log_delivery_*` resources created. Brief window where logs might switch paths during apply. |
| On v4.x and skipping v6.0.x entirely | Plan is a clean swap — v4.x had legacy `logging_config`, v6.1.0 has v2 logging; one consistent change |

#### Operational side effects

- ✅ **Athena partition projection consumers benefit** — their queries continue to find logs after upgrade. Primary motivation.
- ⚠️ **Anyone who built tooling against v6.0.2–v6.0.4's flat-path layout would see their tooling break.** Unlikely in practice given how short-lived those versions were; no known consumers had migrated to them.
- ⚠️ **`logging_hive_compatible_path` variable re-appears** — consumers who removed references to it after v6.0.2 deleted it would need to verify they don't pass an unsupported variable. No known consumer uses this variable explicitly.

#### What is NOT a side effect

- No change to log retention or S3 lifecycle on the log bucket
- No change to log content or format — only the S3 prefix structure
- No IAM changes
- No KMS or encryption changes
- No impact on the `route53-kms` `moved {}` blocks or `arn` alias work (separate decision below)

#### How tests bound the side effects

The 7 `terraform test` cases in `cloudfront/tests/logging.tftest.hcl` verify the intended behavior and will fail loudly if a future version silently regresses to flat logging again. The side effects are bounded by the tests and observable in plan output before any apply runs.

### Consequences

- The `suffix_path` value is now part of the module's **public contract**. Changing it requires coordinated downstream Athena schema migration in every consumer.
- Future v6.x evolution should NOT silently re-introduce flat logging. If a future AWS API change requires it, tag a new major version and provide an explicit migration tool for partition-projection consumers.
- The v6.0.2 → v6.0.4 line of the module remains inconsistent with v6.1.0+. Consumers on those mid-versions should upgrade to v6.1.0+ to restore the partitioned layout. The v6.0.x line should be considered an aborted release pattern; don't backport fixes to it.
- v6.1.0 added a `moved {}` block in `route53-kms` for v4.x compatibility — same release also addresses the KMS rename gap. See separate entry below.

### Surfaced from

- datastreamapp/issues#1891 (filed this release)
- datastreamapp/issues#1176 (parent epic — AWS provider v6 upgrade)
- Multi-agent investigation 2026-05-28: three verification agents found this breaking change in v6.0.4 before any consumer migration was attempted. Agent 1 (terraform code reviewer) diffed v5.1.0 → v6.0.4 and identified the logging.tf deletion. Agent 3 (production ground truth) confirmed that an actual datastream consumer's edge/athena.tf has partition projections matching v5.1.0's path layout — proving the risk was real, not theoretical.

---

## 2026-05-28 — v6.1.0: Migration support for v4.x → v6.x consumers

### Context

Between v4.4.0 and v5.0.0, two resources in `route53-kms/main.tf` were renamed:
- `aws_kms_key.route53` → `aws_kms_key.main`
- `aws_kms_alias.route53` → `aws_kms_alias.main`

The corresponding output was also renamed:
- `output "arn"` → `output "kms_key_arn"`

Neither rename came with `moved {}` blocks or output aliases. Any consumer pinning v4.x and attempting to bump to any v5.x or v6.x version would experience:

1. **Plan-time error** on `module.X.arn` references (output not found)
2. **Resource destroy + create** of the KMS key on apply (no `moved {}` block to reconcile state)

For consumers using this module's `route53-kms` submodule with DNSSEC (Route53 hosted zones using the KMS key for signing), destroying the KMS key would break DNSSEC validation for the affected zones — a catastrophic failure mode that would take hours to recover from.

### Decision

In v6.1.0:

1. **Added `moved {}` blocks** in `route53-kms/main.tf`:
   ```hcl
   moved { from = aws_kms_key.route53,   to = aws_kms_key.main }
   moved { from = aws_kms_alias.route53, to = aws_kms_alias.main }
   ```
   These let consumers bumping from v4.x state reconcile cleanly without resource destruction.

2. **Added deprecated `arn` output alias** in `route53-kms/outputs.tf`:
   ```hcl
   output "arn" {
     value       = aws_kms_key.main.arn
     description = "DEPRECATED: use kms_key_arn instead. Will be removed in v7.0.0."
   }
   ```

3. **Added 5 `terraform test` cases** in `route53-kms/tests/main.tftest.hcl` to lock in these behaviors.

### Consequences

- v4.x consumers can upgrade to v6.1.0+ without DNSSEC outage risk.
- The deprecated `arn` output adds a small maintenance cost (must remember to remove it in v7.0.0).
- Future major-version renames in this module should add `moved {}` blocks **and** deprecated output aliases **in the same release** as the rename, not as remediation later.

### Surfaced from

- Same investigation as the logging decision above.
- Agent 3 (production ground truth) confirmed all 6 production Route53 hosted zones have DNSSEC actively enabled with the KSK that would have been destroyed without these `moved {}` blocks.
