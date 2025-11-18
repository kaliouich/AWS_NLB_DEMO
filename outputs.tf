output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.api_nlb.dns_name
}

output "database_endpoint" {
  description = "Database connection endpoint"
  value       = aws_db_instance.api.address
  sensitive   = true
}

output "api_instance_ids" {
  description = "IDs of the API instances"
  value       = aws_instance.api[*].id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}