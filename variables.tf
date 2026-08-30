variable "region" {
  description = "Região AWS RDS."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente."
  type        = string
  default     = "prod"
  validation {
    condition     = var.environment == "prod"
    error_message = "Apenas o ambiente de produção (prod) é suportado."
  }
}

variable "db_name" {
  description = "Nome do banco de dados."
  type        = string
  default     = "mecanicadmdb"
}

variable "db_username" {
  description = "Usuário administrador do banco."
  type        = string
  default     = "mecanicadm_admin"
}

variable "db_instance_class" {
  description = "Classe de instância RDS."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "Armazenamento alocado em GB."
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Replica síncrona em outra AZ."
  type        = bool
  default     = false
}

variable "postgres_version" {
  description = "Versão do PostgreSQL gerenciado."
  type        = string
  default     = "16.3"
}

variable "deletion_protection" {
  description = "Protege o banco contra exclusão acidental."
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Dias de retenção de backup."
  type        = number
  default     = 1
}
