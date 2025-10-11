output "cloudfront_domain" {
  value       = var.enable_frontend ? aws_cloudfront_distribution.cdn[0].domain_name : null
  description = "Dominio de CloudFront (null si frontend deshabilitado)"
}

output "api_invoke_url" {
  value       = aws_apigatewayv2_stage.stage.invoke_url
  description = "Base URL del API Gateway"
}

output "alb_dns" {
  value       = aws_lb.internal.dns_name
  description = "DNS del ALB interno (debug)"
}

output "rds_endpoint" {
  value       = aws_db_instance.db.address
  description = "Endpoint de MySQL"
}

output "ecr_repos" {
  value = {
    auth       = aws_ecr_repository.auth.repository_url
    inventario = aws_ecr_repository.inventario.repository_url
    reportes   = aws_ecr_repository.reportes.repository_url
  }
  description = "URIs de repositorios ECR"
}
