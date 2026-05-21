resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${local.name_prefix}/rds/credentials"
  description             = "RDS master credentials"
  recovery_window_in_days = 7
  tags                    = { Name = "${local.name_prefix}-db-secret" }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.main.address
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })
}

resource "aws_db_subnet_group" "main" {
  name        = "${local.name_prefix}-db-subnet-group"
  description = "Private DB subnets for RDS"
  subnet_ids  = [aws_subnet.private_db_az1.id, aws_subnet.private_db_az2.id]
  tags        = { Name = "${local.name_prefix}-db-subnet-group" }
}

resource "aws_db_parameter_group" "main" {
  name        = "${local.name_prefix}-pg15-params"
  family      = "postgres15"
  description = "Custom params for ${local.name_prefix} PostgreSQL 15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = { Name = "${local.name_prefix}-pg15-params" }
}

resource "aws_iam_role" "rds_monitoring" {
  name = "${local.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${local.name_prefix}-rds-monitoring-role" }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"
  tags = { Name = "${local.name_prefix}-alerts" }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ec2/${local.name_prefix}/app"
  retention_in_days = 30
  tags              = { Name = "${local.name_prefix}-app-logs" }
}

resource "aws_db_instance" "main" {
  identifier            = "${local.name_prefix}-postgres"
  engine                = var.db_engine
  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.main.name

  publicly_accessible      = false
  multi_az                 = var.db_multi_az
  backup_retention_period  = var.db_backup_retention_days
  backup_window            = "03:00-04:00"
  maintenance_window       = "Mon:04:00-Mon:05:00"
  deletion_protection      = var.db_deletion_protection
  skip_final_snapshot      = var.environment != "prod"

  final_snapshot_identifier = (
    var.environment == "prod"
    ? "${local.name_prefix}-final-snapshot"
    : null
  )

  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled = true

  tags = { Name = "${local.name_prefix}-postgres", Role = "primary-database" }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${local.name_prefix}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU > 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = { Name = "${local.name_prefix}-rds-cpu-alarm" }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${local.name_prefix}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5368709120
  alarm_description   = "RDS free storage < 5GB"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.identifier
  }

  tags = { Name = "${local.name_prefix}-rds-storage-alarm" }
}
