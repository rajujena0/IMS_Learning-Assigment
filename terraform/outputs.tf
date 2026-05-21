output "vpc_id"               { value = aws_vpc.main.id }
output "public_subnet_id"     { value = aws_subnet.public.id }
output "private_app_subnet_id" { value = aws_subnet.private_app.id }

output "ec2_instance_id"  { value = aws_instance.app.id }
output "ec2_private_ip"   { value = aws_instance.app.private_ip }

output "ssm_session_command" {
  description = "Run this to open a shell on the EC2 instance (no SSH needed)"
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.aws_region}"
}

output "rds_endpoint"     { value = "${aws_db_instance.main.address}:${aws_db_instance.main.port}" }
output "db_secret_arn"    { value = aws_secretsmanager_secret.db_credentials.arn }

output "retrieve_db_secret_command" {
  description = "Run this to fetch DB credentials from Secrets Manager"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.db_credentials.name} --region ${var.aws_region} --query SecretString --output text | jq ."
}
