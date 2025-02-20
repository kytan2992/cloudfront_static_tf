locals {
  resource_prefix = "ky-tf"
  bucket_name     = "${local.resource_prefix}-s3.sctp-sandbox.com"
}

### RUN THIS ALONE FIRST TO CREATE EMPTY BUCKET THEN AWS SYNC IN OBJECTS ####
resource "aws_s3_bucket" "static_bucket" {
  bucket        = local.bucket_name
  force_destroy = true
}

### THEN DO THE REST ####

resource "aws_s3_bucket_policy" "name" {
  bucket = aws_s3_bucket.static_bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_acm_certificate" "bucket_cert" {
  domain_name       = local.bucket_name
  validation_method = "DNS" # You can also use "EMAIL" but DNS is preferred
  key_algorithm     = "RSA_2048"

  tags = {
    Name = "${local.bucket_name}-certificate"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${local.resource_prefix}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cloudfront" {
  origin {
    domain_name              = aws_s3_bucket.static_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = aws_s3_bucket.static_bucket.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = [local.bucket_name]

  web_acl_id = aws_wafv2_web_acl.waf_acl.arn

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = aws_s3_bucket.static_bucket.id
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.bucket_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Description = "KY-TF-CF"
  }
}

resource "aws_route53_record" "dns_bucket" {
  zone_id = data.aws_route53_zone.sctp_zone.zone_id
  name    = local.bucket_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cloudfront.domain_name
    zone_id                = aws_cloudfront_distribution.cloudfront.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_wafv2_web_acl" "waf_acl" {
  name        = "${local.resource_prefix}-waf"
  scope       = "CLOUDFRONT"
  description = "WAF for ${local.bucket_name}"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.resource_prefix}-WAF"
    sampled_requests_enabled   = true
  }
}

