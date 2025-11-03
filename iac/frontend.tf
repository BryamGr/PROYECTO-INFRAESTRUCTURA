locals {
  frontend_enabled    = var.enable_frontend
  frontend_has_domain = var.enable_frontend && var.domain_name != ""
}

# Buckets S3: dashboard + auth + uploads
resource "aws_s3_bucket" "dashboard" {
  count         = local.frontend_enabled ? 1 : 0
  bucket        = var.frontend_bucket_name
  force_destroy = false
  tags          = merge(var.tags, { Name = "${var.project_name}-dashboard" })

  lifecycle {
    precondition {
      condition     = var.frontend_bucket_name != null && var.frontend_bucket_name != ""
      error_message = "Debes definir frontend_bucket_name cuando enable_frontend es true"
    }
  }
}
resource "aws_s3_bucket_public_access_block" "dashboard" {
  count                  = local.frontend_enabled ? 1 : 0
  bucket                  = aws_s3_bucket.dashboard[count.index].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "auth_spa" {
  count         = local.frontend_enabled ? 1 : 0
  bucket        = var.auth_frontend_bucket_name
  force_destroy = false
  tags          = merge(var.tags, { Name = "${var.project_name}-auth" })

  lifecycle {
    precondition {
      condition     = var.auth_frontend_bucket_name != null && var.auth_frontend_bucket_name != ""
      error_message = "Debes definir auth_frontend_bucket_name cuando enable_frontend es true"
    }
  }
}
resource "aws_s3_bucket_public_access_block" "auth_spa" {
  count                  = local.frontend_enabled ? 1 : 0
  bucket                  = aws_s3_bucket.auth_spa[count.index].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "uploads" {
  count  = local.frontend_enabled ? 1 : 0
  bucket = var.uploads_bucket_name
  tags   = merge(var.tags, { Name = "${var.project_name}-uploads" })

  lifecycle {
    precondition {
      condition     = var.uploads_bucket_name != null && var.uploads_bucket_name != ""
      error_message = "Debes definir uploads_bucket_name cuando enable_frontend es true"
    }
  }
}
resource "aws_s3_bucket_public_access_block" "uploads_block" {
  count                  = local.frontend_enabled ? 1 : 0
  bucket                  = aws_s3_bucket.uploads[count.index].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "oac_dashboard" {
  count                             = local.frontend_enabled ? 1 : 0
  name                              = "${var.project_name}-oac-dashboard"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
resource "aws_cloudfront_origin_access_control" "oac_auth" {
  count                             = local.frontend_enabled ? 1 : 0
  name                              = "${var.project_name}-oac-auth"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


resource "aws_acm_certificate" "cert" {
  count             = local.frontend_has_domain ? 1 : 0
  provider          = aws.use1
  domain_name       = var.domain_name
  validation_method = "DNS"
  tags              = merge(var.tags, { Name = "${var.project_name}-cert" })
}
resource "aws_route53_record" "cert_validation" {
  for_each = local.frontend_has_domain ? {
    for dvo in aws_acm_certificate.cert[0].domain_validation_options :
    dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  } : {}
  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 300
  records = [each.value.value]
}
resource "aws_acm_certificate_validation" "cert" {
  count                   = local.frontend_has_domain ? 1 : 0
  provider                = aws.use1
  certificate_arn         = aws_acm_certificate.cert[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_cloudfront_distribution" "cdn" {
  count               = local.frontend_enabled ? 1 : 0
  enabled             = true
  price_class         = "PriceClass_100"
  default_root_object = "index.html"

  # Orígenes
  origins {
    domain_name              = aws_s3_bucket.dashboard[0].bucket_regional_domain_name
    origin_id                = "s3-dashboard"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac_dashboard[count.index].id
  }
  origins {
    domain_name              = aws_s3_bucket.auth_spa[0].bucket_regional_domain_name
    origin_id                = "s3-auth"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac_auth[count.index].id
  }


  default_cache_behavior {
    target_origin_id       = "s3-dashboard"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
  }
  ordered_cache_behavior {
    path_pattern           = "/auth/*"
    target_origin_id       = "s3-auth"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }


  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
  }
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
  }

  viewer_certificate {
    acm_certificate_arn            = local.frontend_has_domain ? aws_acm_certificate_validation.cert[0].certificate_arn : null
    ssl_support_method             = local.frontend_has_domain ? "sni-only" : null
    minimum_protocol_version       = local.frontend_has_domain ? "TLSv1.2_2021" : null
    cloudfront_default_certificate = !local.frontend_has_domain
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  web_acl_id = local.frontend_enabled && var.waf_enable ? aws_wafv2_web_acl.cf[0].arn : null

  tags = merge(var.tags, { Name = "${var.project_name}-cdn" })
}


data "aws_iam_policy_document" "dash_oac" {
  count = local.frontend_enabled ? 1 : 0
  statement {
    principals { type = "Service", identifiers = ["cloudfront.amazonaws.com"] }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.dashboard[0].arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn[count.index].arn]
    }
  }
}
resource "aws_s3_bucket_policy" "dashboard" {
  count      = local.frontend_enabled ? 1 : 0
  bucket     = aws_s3_bucket.dashboard[count.index].id
  policy     = data.aws_iam_policy_document.dash_oac[count.index].json
  depends_on = [aws_cloudfront_distribution.cdn]
}

data "aws_iam_policy_document" "auth_oac" {
  count = local.frontend_enabled ? 1 : 0
  statement {
    principals { type = "Service", identifiers = ["cloudfront.amazonaws.com"] }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.auth_spa[0].arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn[count.index].arn]
    }
  }
}
resource "aws_s3_bucket_policy" "auth" {
  count      = local.frontend_enabled ? 1 : 0
  bucket     = aws_s3_bucket.auth_spa[count.index].id
  policy     = data.aws_iam_policy_document.auth_oac[count.index].json
  depends_on = [aws_cloudfront_distribution.cdn]
}

# (Opcional) WAF
resource "aws_wafv2_web_acl" "cf" {
  count = local.frontend_enabled && var.waf_enable ? 1 : 0
  name  = "${var.project_name}-cf-waf"
  scope = "CLOUDFRONT"
  default_action { allow {} }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-cf-waf"
    sampled_requests_enabled   = true
  }
  rule {
    name     = "AWSManagedCommon"
    priority = 1
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common"
      sampled_requests_enabled   = true
    }
  }
  tags = var.tags
}


resource "aws_route53_record" "frontend" {
  count  = local.frontend_has_domain ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.cdn[count.index].domain_name
    zone_id                = aws_cloudfront_distribution.cdn[count.index].hosted_zone_id
    evaluate_target_health = false
  }
}
