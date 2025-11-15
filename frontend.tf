resource "aws_s3_bucket" "frontend" {
  bucket = var.frontend_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket" "auth_frontend" {
  bucket = var.auth_frontend_bucket_name
  tags   = var.tags
}
resource "aws_s3_bucket_public_access_block" "auth_frontend" {
  bucket = aws_s3_bucket.auth_frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI para los buckets de ${var.project_name}"
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "s3:GetObject",
      Effect    = "Allow",
      Principal = { AWS = aws_cloudfront_origin_access_identity.oai.iam_arn },
      Resource  = "${aws_s3_bucket.frontend.arn}/*"
    }]
  })
}


resource "aws_s3_bucket_policy" "auth_frontend" {
  bucket = aws_s3_bucket.auth_frontend.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "s3:GetObject",
      Effect    = "Allow",
      Principal = { AWS = aws_cloudfront_origin_access_identity.oai.iam_arn },
      Resource  = "${aws_s3_bucket.auth_frontend.arn}/*"
    }]
  })
}

resource "aws_wafv2_web_acl" "main" {
  provider    = aws.use1 
  name        = "${var.project_name}-waf"
  scope       = "CLOUDFRONT"
  description = "WAF para la distribución de CloudFront"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-Managed-CommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-managed-common"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "waf-main"
    sampled_requests_enabled   = true
  }
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN para ${var.project_name}"
  price_class         = "PriceClass_All"
  
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-${var.frontend_bucket_name}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  origin {
    domain_name = aws_s3_bucket.auth_frontend.bucket_regional_domain_name
    origin_id   = "S3-${var.auth_frontend_bucket_name}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  origin {
    origin_id   = "API-${var.project_name}"
    domain_name = replace(aws_apigatewayv2_api.api.api_endpoint, "https://", "")
    
    custom_origin_config {
      http_port                = 443
      https_port               = 443
      origin_protocol_policy   = "https-only"
      origin_ssl_protocols     = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id = "S3-${var.frontend_bucket_name}" 
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true
  }
  
  ordered_cache_behavior {
    path_pattern     = "/auth/*"
    target_origin_id = "S3-${var.auth_frontend_bucket_name}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true
  }

  ordered_cache_behavior {
    path_pattern     = "/api/*"
    target_origin_id = "API-${var.project_name}"
    
    viewer_protocol_policy = "https-only"
    allowed_methods    = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods     = ["GET", "HEAD", "OPTIONS"]
    compress           = true
    
    default_ttl = 0
    min_ttl     = 0
    max_ttl     = 0
    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
      headers = ["Authorization", "Content-Type", "Origin"]
    }
  }

  web_acl_id = var.waf_enable ? aws_wafv2_web_acl.main.arn : null
  count      = var.waf_enable ? 1 : 0

  aliases = var.domain_name != "" ? [var.domain_name] : []

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn != "" ? var.acm_certificate_arn : null
    ssl_support_method       = var.acm_certificate_arn != "" ? "sni-only" : null
    cloudfront_default_certificate = var.acm_certificate_arn == "" ? true : null
  }
}

