# ECR repositories for each application
resource "aws_ecr_repository" "app_repositories" {
  for_each = var.applications

  name = "${var.project}-${var.environment}-${each.value.name}"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name        = "${var.project}-${var.environment}-${each.value.name}"
    Application = each.value.name
  })
}

# ECR repository policy to allow ECS task execution role to pull images
resource "aws_ecr_repository_policy" "app_repository_policies" {
  for_each = var.applications

  repository = aws_ecr_repository.app_repositories[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSTaskExecutionRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ecs_task_execution_role[each.key].arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      },
      {
        Sid    = "AllowECSTaskRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.ecs_task_role[each.key].arn
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
