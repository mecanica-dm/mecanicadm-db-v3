output "db_host" {
  description = "Endpoint do RDS (usado para testes e dashboards)."
  value       = aws_db_instance.mecanicadm.address
}

output "db_secretsmanager_arn" {
  description = "ARN do secret com as credenciais (para rotação/auditoria)."
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_security_group_id" {
  description = "SG do banco (adicionar como origem em outros recursos)."
  value       = aws_security_group.rds.id
}
