# --- S3 Bucket para el Frontend Principal (Dashboard) ---
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

# --- S3 Bucket para el Frontend de Auth (Login) ---
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

# --- Identidad de Origen de CloudFront (para ambos buckets) ---
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI para los buckets de ${var.project_name}"
}

# Política para el bucket principal
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

# Política para el bucket de auth
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

# --- AWS WAF (Firewall) ---
resource "aws_wafv2_web_acl" "main" {
  provider    = aws.use1 # ¡Importante! WAF para CloudFront debe estar en us-east-1
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

# --- Distribución de CloudFront ---
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN para ${var.project_name}"
  price_class         = "PriceClass_All"
  
  # --- Origen 1: S3 (para el frontend principal) ---
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-${var.frontend_bucket_name}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  # --- Origen 2: S3 (para el frontend de auth) ---
  origin {
    domain_name = aws_s3_bucket.auth_frontend.bucket_regional_domain_name
    origin_id   = "S3-${var.auth_frontend_bucket_name}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  # --- Origen 3: API Gateway (para el backend) ---
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

  # --- Comportamiento por Defecto (va al Dashboard) ---
  default_cache_behavior {
    target_origin_id = "S3-${var.frontend_bucket_name}" # Origen principal
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true
  }
  
  # --- Comportamiento para Auth (va al bucket de Auth) ---
  ordered_cache_behavior {
    path_pattern     = "/auth/*"
    target_origin_id = "S3-${var.auth_frontend_bucket_name}" # Origen de Auth
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true
  }

  # --- Comportamiento para la API (va a API Gateway) ---
  ordered_cache_behavior {
    path_pattern     = "/api/*" # O "/auth*", "/inventario*", etc.
    target_origin_id = "API-${var.project_name}"
    
    viewer_protocol_policy = "https-only"
    allowed_methods    = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods     = ["GET", "HEAD", "OPTIONS"]
    compress           = true
    
    # Reenviar todo a la API
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

  # Configuración del WAF
  web_acl_id = var.waf_enable ? aws_wafv2_web_acl.main[0].arn : null
  count      = var.waf_enable ? 1 : 0

  aliases = var.domain_name != "" ? [var.domain_name] : []

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # Usar certificado personalizado si se provee un ARN
    acm_certificate_arn      = var.acm_certificate_arn != "" ? var.acm_certificate_arn : null
    ssl_support_method       = var.acm_certificate_arn != "" ? "sni-only" : null
    # Usar certificado default de CloudFront si no hay ARN
    cloudfront_default_certificate = var.acm_certificate_arn == "" ? true : null
  }
}

# --- Registro de Route 53 ---
resource "aws_route53_record" "www" {
  count   = var.domain_name != "" ? 1 : 0
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn.domain_name
    zone_id                = aws_cloudfront_distribution.cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

# --- Output para el ID de CloudFront ---
output "cloudfront_distribution_id" {
  description = "El ID de la distribución de CloudFront"
  value       = aws_cloudfront_distribution.cdn.id
}
