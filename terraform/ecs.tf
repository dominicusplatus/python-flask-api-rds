resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}-cluster"

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"
      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project}-${var.environment}-ecs-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_ecs_task_definition" "app" {
  for_each = var.applications

  family                   = "${var.project}-${var.environment}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role[each.key].arn
  task_role_arn            = aws_iam_role.ecs_task_role[each.key].arn

  container_definitions = jsonencode([
    {
      name  = each.key
      image = "${each.value.image_name}:${each.value.image_tag}"

      portMappings = [
        {
          containerPort = each.value.port
          hostPort      = each.value.port
          protocol      = "tcp"
        }
      ]

      environment = [
        for key, value in merge(
          each.value.environment_variables,
          {
            AWS_REGION = var.aws_region
            DATABASE_TYPE = "rds"
            DATABASE_ENGINE = aws_db_instance.rds[each.key].engine
            DATABASE_HOST = aws_db_instance.rds[each.key].endpoint
            DATABASE_NAME = aws_db_instance.rds[each.key].db_name
            DATABASE_PORT = tostring(aws_db_instance.rds[each.key].port)
          }
        ) : {
          name  = key
          value = value
        }
      ]

      secrets = [
        for key, value in merge(
          each.value.secrets,
          {
            DATABASE_USERNAME = "${aws_secretsmanager_secret.rds_credentials[each.key].arn}:username::"
            DATABASE_PASSWORD = "${aws_secretsmanager_secret.rds_credentials[each.key].arn}:password::"
          }
        ) : {
          name      = key
          valueFrom = value
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app[each.key].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name = "${var.project}-${var.environment}-${each.key}-task"
  }
}

resource "aws_ecs_service" "app" {
  for_each = var.applications

  name            = "${var.project}-${var.environment}-${each.key}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.ecs[each.key].id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main[each.key].arn
    container_name   = each.key
    container_port   = each.value.port
  }

  depends_on = [aws_lb_listener.main]

  tags = {
    Name = "${var.project}-${var.environment}-${each.key}-service"
  }
}

resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/aws/ecs/${var.project}-${var.environment}-exec"
  retention_in_days = 7

  tags = {
    Name = "${var.project}-${var.environment}-ecs-exec-logs"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  for_each = var.applications

  name              = "/ecs/${var.project}-${var.environment}-${each.key}"
  retention_in_days = 14

  tags = {
    Name = "${var.project}-${var.environment}-${each.key}-logs"
  }
}