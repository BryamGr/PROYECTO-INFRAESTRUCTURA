resource "aws_ecr_repository" "auth" {
  name                 = "${var.ecr_repo_prefix}/auth"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = var.tags
}

resource "aws_ecr_repository" "inventario" {
  name                 = "${var.ecr_repo_prefix}/inventario"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = var.tags
}

resource "aws_ecr_repository" "reportes" {
  name                 = "${var.ecr_repo_prefix}/reportes"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "keep10" {
  for_each = {
    auth       = aws_ecr_repository.auth.name
    inventario = aws_ecr_repository.inventario.name
    reportes   = aws_ecr_repository.reportes.name
  }

  repository = each.value
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

output "ecr_repo_urls" {
  value = {
    auth       = aws_ecr_repository.auth.repository_url
    inventario = aws_ecr_repository.inventario.repository_url
    reportes   = aws_ecr_repository.reportes.repository_url
  }
}
