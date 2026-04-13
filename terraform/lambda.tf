# ==================== IAM ROLE ====================
# Learner Lab não permite iam:CreateRole — usar LabRole pré-existente

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# ==================== SECURITY GROUP ====================

resource "aws_security_group" "lambda" {
  name_prefix = "${var.project_name}-lambda-auth-"
  vpc_id      = var.vpc_id
  description = "Security group para a Lambda de autenticacao"

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "PostgreSQL RDS"
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS (CloudWatch Logs)"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Regra de ingress no SG do RDS para permitir tráfego da Lambda
resource "aws_security_group_rule" "rds_from_lambda" {
  count = var.rds_security_group_id != "" ? 1 : 0

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = var.rds_security_group_id
  source_security_group_id = aws_security_group.lambda.id
  description              = "PostgreSQL from Lambda auth"
}

# ==================== LAMBDA FUNCTION ====================

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/.."
  output_path = "${path.module}/function.zip"

  excludes = [
    "terraform",
    ".github",
    ".git",
    ".gitignore",
    "README.md",
    "*.test.mjs",
  ]
}

resource "aws_lambda_function" "auth" {
  function_name = "${var.project_name}-auth-cpf"
  description   = "Autenticacao via CPF - valida CPF, consulta cliente, gera JWT"
  role          = data.aws_iam_role.lab_role.arn

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime     = "nodejs20.x"
  handler     = "src/index.handler"
  timeout     = 30
  memory_size = 128

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_HOST     = var.db_host
      DB_PORT     = "5432"
      DB_NAME     = var.db_name
      DB_USER     = var.db_user
      DB_PASSWORD = var.db_password
      JWT_SECRET  = var.jwt_secret
    }
  }
}

# ==================== CLOUDWATCH LOG GROUP ====================

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.auth.function_name}"
  retention_in_days = 7
}
