resource "aws_security_group" "alb" {
  for_each = var.applications

  name_prefix = "${var.project}-${var.environment}-${each.key}-alb-"
  vpc_id      = aws_vpc.main.id
  description = "ALB security group for ${each.key} application"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = each.value.allowed_cidr_blocks
    description = "HTTP access for ${each.key} from allowed CIDRs"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = each.value.allowed_cidr_blocks
    description = "HTTPS access for ${each.key} from allowed CIDRs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic for ${each.key} ALB"
  }

  tags = {
    Name = "${var.project}-${var.environment}-${each.key}-alb-sg"
    Application = each.key
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "ecs" {
  for_each = var.applications

  name_prefix = "${var.project}-${var.environment}-${each.key}-ecs-"
  vpc_id      = aws_vpc.main.id
  description = "ECS security group for ${each.key} application"

  ingress {
    from_port       = each.value.port
    to_port         = each.value.port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb[each.key].id]
    description     = "Allow ${each.key} ALB to access container port ${each.value.port}"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic for ${each.key}"
  }

  tags = {
    Name = "${var.project}-${var.environment}-${each.key}-ecs-sg"
    Application = each.key
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.project}-${var.environment}-rds-"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.applications
    content {
      from_port       = ingress.value.rds_config != null ? (
        ingress.value.rds_config.engine == "mysql" ? 3306 :
        ingress.value.rds_config.engine == "postgres" ? 5432 :
        ingress.value.rds_config.engine == "sqlserver" ? 1433 : 3306
      ) : 3306
      to_port         = ingress.value.rds_config != null ? (
        ingress.value.rds_config.engine == "mysql" ? 3306 :
        ingress.value.rds_config.engine == "postgres" ? 5432 :
        ingress.value.rds_config.engine == "sqlserver" ? 1433 : 3306
      ) : 3306
      protocol        = "tcp"
      security_groups = [aws_security_group.ecs[ingress.key].id]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-${var.environment}-rds-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
