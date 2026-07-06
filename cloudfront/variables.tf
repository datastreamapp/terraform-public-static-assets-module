// Suggested:
// ${env}-${subdomain}-${domain}-${tld}
variable "name" {
  type        = string
  description = "AWS S3 Bucket. {env}-{name}"
}

variable "default_tags" {
  type    = map(string)
  default = {}
}

variable "http_version" {
  type    = string
  default = "http3" # http2and3
}

variable "price_class" {
  type    = string
  default = "PriceClass_All" # PriceClass_All, PriceClass_200, PriceClass_100
}

variable "aliases" {
  type        = list(string)
  description = "Cloudfront Aliases"
}

variable "acm_certificate_arn" {
  type    = string
  default = ""
}

variable "web_acl_id" {
  type        = string
  default     = ""
  description = "WAF ACL ID"
}

variable "geo_restriction" {
  type    = string
  default = "none"
}

variable "origins" {
  type = list(object({
    origin_id                = string
    type                     = optional(string, "custom")
    domain_name              = string
    origin_access_control_id = optional(string) # aws_cloudfront_origin_access_control._.id
    origin_path              = optional(string)
    origin_shield            = optional(string, "disabled") # aws region
    custom_headers = optional(list(object({
      name  = string
      value = string
    })), [])
  }))
  default = []
}

variable "origin_groups" {
  type = list(object({
    origin_id    = string
    status_codes = list(number)
    origin_ids   = list(string)
  }))
  default = []
}

variable "behaviors" {
  type = list(object({
    path_pattern             = optional(string, "/*")
    origin_id                = string
    allowed_methods          = optional(list(string), ["HEAD", "OPTIONS", "GET"]) # or ["HEAD", "OPTIONS", "GET", "PUT", "POST", "PATCH", "DELETE"]
    viewer_protocol_policy   = optional(string, "https-only")                     # Change to `redirect-to-https` for HTML endpoints
    origin_request_policy_id = optional(string)
    trusted_key_groups       = optional(list(string)) # List of key group IDs that CloudFront can use to validate signed URLs or signed cookies.
    lambda = optional(object({
      viewer-request  = optional(string)
      origin-request  = optional(string)
      origin-response = optional(string)
      viewer-response = optional(string)
    }), {})
    response_headers_policy_id = optional(string)
    cached_methods             = optional(list(string), ["HEAD", "OPTIONS", "GET"])
    cache_policy_id            = optional(string)
    compress                   = optional(bool, false)
  }))
  default = []
}


variable "default_root_object" {
  type    = string
  default = "index.html"
}

# Allowed: 400, 403, 404, 405, 414, 416, 500, 501, 502, 503, 504
variable "error_codes" {
  type    = map(string)
  default = {}
}

# Override the HTTP response code returned for a given error_code.
# Keys must match keys in var.error_codes. Omitted keys fall back to the
# error code itself (preserving v5.1.0 behaviour for existing callers).
variable "error_code_response_overrides" {
  type    = map(number)
  default = {}
  validation {
    condition = alltrue([
      for v in values(var.error_code_response_overrides) :
      contains([200, 400, 403, 404, 405, 414, 416, 500, 501, 502, 503, 504], v)
    ])
    error_message = "Each value in error_code_response_overrides must be a CloudFront-supported response code: 200, 400, 403, 404, 405, 414, 416, 500, 501, 502, 503, 504."
  }
}

variable "logging_bucket" {
  type    = string
  default = null
}

variable "logging_hive_compatible_path" {
  description = "Use Hive-compatible S3 prefix (year=YYYY/month=MM/...) for Athena partition discovery"
  type        = bool
  default     = false
}

# Override S3 bucket used
# variable "bucket_domain_name" {
#   default = ""
# }
# 
# variable "cors_origins" {
#   type    = list(string)
#   default = [
#     "*"]
#   description = "S3 CORS"
# }
