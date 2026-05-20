output "vpc_id" {
  description = "The ID of the TechCorp VPC"
  value       = aws_vpc.main.id
}

output "load_balancer_dns_name" {
  description = "DNS name of the Application Load Balancer - use this to access the web application"
  value       = aws_lb.main.dns_name
}

output "bastion_public_ip" {
  description = "Elastic (Public) IP address of the Bastion Host"
  value       = aws_eip.bastion.public_ip
}

output "web_server_1_private_ip" {
  description = "Private IP address of Web Server 1"
  value       = aws_instance.web_1.private_ip
}

output "web_server_2_private_ip" {
  description = "Private IP address of Web Server 2"
  value       = aws_instance.web_2.private_ip
}

output "database_private_ip" {
  description = "Private IP address of the Database Server"
  value       = aws_instance.database.private_ip
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
}

output "alb_target_group_arn" {
  description = "ARN of the ALB target group"
  value       = aws_lb_target_group.web.arn
}

output "ssh_bastion_command" {
  description = "SSH command to connect to the Bastion Host"
  value       = "ssh techcorp-admin@${aws_eip.bastion.public_ip}"
}

output "web_app_url" {
  description = "URL to access the web application via the Load Balancer"
  value       = "http://${aws_lb.main.dns_name}"
}
