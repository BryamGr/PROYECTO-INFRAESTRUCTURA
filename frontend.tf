# --- S3 Bucket para el Frontend Estático ---
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

# --- Identidad de Origen de CloudFront (para que S3 sea privado) ---
resource "aws_cloudfront_origin_access_identity" "oai" {
  comment = "OAI para el bucket ${var.frontend_bucket_name}"
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

# --- AWS WAF (Firewall) ---
resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-waf"
  scope       = "CLOUDFRONT"
  description = "WAF para la distribución de CloudFront"

  default_action {
    allow {}
  }

  # Regla: Usar el conjunto de reglas gestionadas por AWS (bloquea IPs malas, SQLi, XSS)
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
  
  # --- Origen 1: S3 (para el frontend) ---
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = "S3-${var.frontend_bucket_name}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.oai.cloudfront_access_identity_path
    }
  }

  # --- Origen 2: API Gateway (para el backend) ---
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

  # --- Comportamiento por Defecto (va a S3) ---
  default_cache_behavior {
    target_origin_id = "S3-${var.frontend_bucket_name}"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    compress         = true
  }

  # --- Comportamiento para la API (va a API Gateway) ---
  # Cualquier solicitud a /api/*, /auth*, /inventario* irá al backend
  ordered_cache_behavior {
    path_pattern     = "/api/*" # Puedes añadir más patrones como "/auth*", etc.
    target_origin_id = "API-${var.project_name}"
    
    viewer_protocol_policy = "https-only"
    allowed_methods    = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods     = ["GET", "HEAD", "OPTIONS"]
    compress           = true
    
    # Reenviar todas las cabeceras, cookies y query strings a la API
    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
      headers = ["*"]
    }
  }

  # Configuración del WAF
  web_acl_id = aws_wafv2_web_acl.main.arn

  # Configuración de SSL/TLS (asume que tienes un dominio)
  # Necesitarás un certificado en ACM en us-east-1
  # aliases = [var.domain_name]
  # viewer_certificate {
  #   acm_certificate_arn = var.acm_certificate_arn # Necesitarías añadir esta variable
  #   ssl_support_method  = "sni-only"
  # }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# --- Registro de Route 53 ---
# Esto apunta tu dominio (ej. app.tu-tienda.com) a la distribución de CloudFront
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