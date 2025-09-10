resource "aws_iam_role" "ecs_task_execution_role" {
  for_each = var.applications

  name = "${var.project}-${var.environment}-${each.key}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assume_role.json

  tags = {
    Name        = "${var.project}-${var.environment}-${each.key}-ecs-execution-role"
    Application = each.key
  }
}

data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  for_each = var.applications

  role       = aws_iam_role.ecs_task_execution_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_execution_secrets_policy" {
  for_each = var.applications

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = concat(
      [
        "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project}-${var.environment}-${each.key}-*"
      ],
      values(each.value.secrets)
    )
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/${var.environment}/${each.key}/*"
    ]
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_secrets_policy" {
  for_each = var.applications

  name   = "${var.project}-${var.environment}-${each.key}-ecs-execution-secrets-policy"
  role   = aws_iam_role.ecs_task_execution_role[each.key].id
  policy = data.aws_iam_policy_document.ecs_task_execution_secrets_policy[each.key].json

  depends_on = [aws_secretsmanager_secret.rds_credentials]
}

resource "aws_iam_role" "ecs_task_role" {
  for_each = var.applications

  name               = "${var.project}-${var.environment}-${each.key}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name        = "${var.project}-${var.environment}-${each.key}-ecs-task-role"
    Application = each.key
  }
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecs_task_policy" {
  for_each = var.applications

  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = concat(
      [
        "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project}-${var.environment}-${each.key}-*"
      ],
      values(each.value.secrets)
    )
  }

  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/${var.environment}/${each.key}/*"
    ]
  }

}

# Policy for ECS tasks to access AWS services during runtime
resource "aws_iam_role_policy" "ecs_task_policy" {
  for_each = var.applications

  name   = "${var.project}-${var.environment}-${each.key}-ecs-task-policy"
  role   = aws_iam_role.ecs_task_role[each.key].id
  policy = data.aws_iam_policy_document.ecs_task_policy[each.key].json
}
