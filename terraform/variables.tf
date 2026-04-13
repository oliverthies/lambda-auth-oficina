variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto (prefixo para recursos)"
  type        = string
  default     = "oficina"
}

# ==================== REDE (outputs do infra-geral-oficina) ====================

variable "vpc_id" {
  description = "ID da VPC (output do infra-geral-oficina)"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs das subnets privadas para a Lambda acessar o RDS"
  type        = list(string)
}

# ==================== BANCO DE DADOS ====================

variable "db_host" {
  description = "Endpoint do RDS PostgreSQL (output do infra-database-oficina)"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
  default     = "oficina"
}

variable "db_user" {
  description = "Usuário do banco de dados"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Senha do banco de dados"
  type        = string
  sensitive   = true
}

# ==================== JWT ====================

variable "jwt_secret" {
  description = "Chave secreta para assinatura JWT (mesmo valor da API)"
  type        = string
  sensitive   = true
}

# ==================== SECURITY GROUPS (para regra de ingress no RDS) ====================

variable "rds_security_group_id" {
  description = "ID do Security Group do RDS (para adicionar regra de ingress para a Lambda)"
  type        = string
  default     = ""
}
