# CONTRATO SSM:
#   - mecanicadm-k8s-v3 é o DONO da VPC e publica: vpc_id,
#     lambda_sg_id, lambda_subnet_a/b, eks_node_sg_id.
#     Também gera/publica o jwt_secret e jwt_expires_minutes (assinatura
#     compartilhada entre Lambda e API, sem relação com o banco).
#   - Este repo publica apenas db_host, db_port, db_name, db_user, db_password.

# Configura parametros gerados pelo projeto K8s
data "aws_ssm_parameter" "vpc_id" {
  name = "/mecanicadm/${var.environment}/vpc_id"
}

data "aws_ssm_parameter" "private_subnet_a" {
  name = "/mecanicadm/${var.environment}/lambda_subnet_a"
}

data "aws_ssm_parameter" "private_subnet_b" {
  name = "/mecanicadm/${var.environment}/lambda_subnet_b"
}

data "aws_ssm_parameter" "lambda_sg_id" {
  name = "/mecanicadm/${var.environment}/lambda_sg_id"
}

data "aws_ssm_parameter" "eks_node_sg_id" {
  name = "/mecanicadm/${var.environment}/eks_node_sg_id"
}

# Gera senha
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}:?"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1

  keepers = {
    environment = var.environment
  }
}

# Cria Security Group: Libera só o SG da Lambda e o SG dos worker nodes do EKS da api.
resource "aws_security_group" "rds" {
  name   = "mecanicadm-${var.environment}-rds"
  vpc_id = data.aws_ssm_parameter.vpc_id.value

  dynamic "ingress" {
    for_each = [
      data.aws_ssm_parameter.lambda_sg_id.value,
      data.aws_ssm_parameter.eks_node_sg_id.value,
    ]
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Environment = var.environment }
}

# Subnet group — RDS exige no mínimo 2 AZs pro multi_az
resource "aws_db_subnet_group" "main" {
  name = "mecanicadm-${var.environment}-subnet-group"
  subnet_ids = [
    data.aws_ssm_parameter.private_subnet_a.value,
    data.aws_ssm_parameter.private_subnet_b.value,
  ]

  tags = { Environment = var.environment }
}

# IAM Role para Enhanced Monitoring (CloudWatch metrics granulares do RDS)
data "aws_iam_policy_document" "rds_monitoring_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "mecanicadm-${var.environment}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume_role.json
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Cria RDS
resource "aws_db_instance" "mecanicadm" {
  identifier = "mecanicadm-${var.environment}"

  engine            = "postgres"
  engine_version    = var.postgres_version
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_encrypted = true
  storage_type      = "gp3"

  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                  = var.multi_az
  publicly_accessible       = false
  skip_final_snapshot       = true
  final_snapshot_identifier = "mecanicadm-${var.environment}-final"
  deletion_protection       = var.deletion_protection

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:05:00-sun:06:00"

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn

  tags = { Environment = var.environment }
}

# Credenciais centralizadas no AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "mecanicadm/${var.environment}/db-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    dbname   = var.db_name
    host     = aws_db_instance.mecanicadm.address
    port     = aws_db_instance.mecanicadm.port
    username = var.db_username
    password = random_password.db_password.result
  })
}

# Publicação no SSM para os secrets gerados nesse repo
resource "aws_ssm_parameter" "db_host" {
  name  = "/mecanicadm/${var.environment}/db_host"
  type  = "SecureString"
  value = aws_db_instance.mecanicadm.address
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/mecanicadm/${var.environment}/db_port"
  type  = "String"
  value = tostring(aws_db_instance.mecanicadm.port)
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/mecanicadm/${var.environment}/db_name"
  type  = "String"
  value = var.db_name
}

resource "aws_ssm_parameter" "db_user" {
  name  = "/mecanicadm/${var.environment}/db_user"
  type  = "SecureString"
  value = var.db_username
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/mecanicadm/${var.environment}/db_password"
  type  = "SecureString"
  value = random_password.db_password.result
}

resource "aws_ssm_parameter" "db_sslmode" {
  name  = "/mecanicadm/${var.environment}/db_sslmode"
  type  = "String"
  value = "require"
}
