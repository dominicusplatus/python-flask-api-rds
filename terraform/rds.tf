resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet-group"
  subnet_ids = aws_subnet.database[*].id

  tags = {
    Name = "${var.project}-${var.environment}-db-subnet-group"
  }
}

resource "random_password" "rds_password" {
  for_each = var.applications

  length  = 32
  special = true
}

resource "aws_db_instance" "rds" {
  for_each = var.applications

  identifier = "${var.project}-${var.environment}-${each.key}-db"

  engine         = each.value.rds_config.engine
  engine_version = each.value.rds_config.engine_version
  instance_class = each.value.rds_config.instance_class

  allocated_storage     = each.value.rds_config.allocated_storage
  max_allocated_storage = each.value.rds_config.max_allocated_storage
  storage_encrypted     = each.value.rds_config.storage_encrypted

  db_name  = "${var.project}_${var.environment}_${replace(each.key, "-", "_")}"
  username = "${var.project}${var.environment}dbadmin"
  password = random_password.rds_password[each.key].result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  multi_az               = each.value.rds_config.multi_az
  backup_retention_period = each.value.rds_config.backup_retention_period
  backup_window          = each.value.rds_config.backup_window
  maintenance_window     = each.value.rds_config.maintenance_window

  deletion_protection = each.value.rds_config.deletion_protection
  skip_final_snapshot = each.value.rds_config.skip_final_snapshot

  tags = {
    Name = "${var.project}-${var.environment}-${each.key}-db"
    Application = each.key
  }
}

resource "aws_secretsmanager_secret" "rds_credentials" {
  for_each = var.applications

  name        = "${var.project}-${var.environment}-${each.key}-db-credentials"
  description = "RDS credentials for ${each.key}"

  tags = {
    Name = "${var.project}-${var.environment}-${each.key}-db-credentials"
    Application = each.key
  }
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  for_each = var.applications

  secret_id = aws_secretsmanager_secret.rds_credentials[each.key].id
  secret_string = jsonencode({
    username = aws_db_instance.rds[each.key].username
    password = random_password.rds_password[each.key].result
    engine   = aws_db_instance.rds[each.key].engine
    host     = aws_db_instance.rds[each.key].endpoint
    port     = aws_db_instance.rds[each.key].port
    dbname   = aws_db_instance.rds[each.key].db_name
  })
}