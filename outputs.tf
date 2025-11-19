output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.api_nlb.dns_name
}

output "nlb_target_group_arn" {
  description = "ARN of the NLB target group"
  value       = aws_lb_target_group.api.arn
}

output "database_endpoint" {
  description = "Database connection endpoint"
  value       = aws_db_instance.api.address
  sensitive   = true
}

output "api_instance_ids" {
  description = "IDs of the API instances"
  value       = join(", ", aws_instance.api[*].id)
}

output "api_instance_private_ips" {
  description = "Private IPs of the API instances"
  value       = join(", ", aws_instance.api[*].private_ip)
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "nat_gateway_ips" {
  description = "Public IPs of NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}