output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_ipv6_cidr_block" {
  description = "Assigned IPv6 CIDR block for the VPC."
  value       = aws_vpc.this.ipv6_cidr_block
}

output "subnet_ids" {
  description = "IDs of the per-instance subnets."
  value       = aws_subnet.this[*].id
}

output "security_group_ids" {
  description = "IDs of the per-instance security groups."
  value       = aws_security_group.this[*].id
}

output "eni_ids" {
  description = "IDs of the per-instance network interfaces."
  value       = aws_network_interface.this[*].id
}

output "eni_ipv6_prefixes" {
  description = "Delegated IPv6 prefixes on each ENI."
  value       = aws_network_interface.this[*].ipv6_prefixes
}

output "instance_ids" {
  description = "IDs of the EC2 instances."
  value       = aws_instance.this[*].id
}

output "instance_details" {
  description = "Detailed information about each instance."
  value = [
    for i in range(var.instance_count) : {
      instance_id       = aws_instance.this[i].id
      instance_name     = aws_instance.this[i].tags["Name"]
      public_ip         = aws_instance.this[i].public_ip
      private_ip        = aws_instance.this[i].private_ip
      eni_id            = aws_instance.this[i].primary_network_interface_id
      subnet_id         = aws_instance.this[i].subnet_id
      eni_ipv6_prefixes = aws_network_interface.this[i].ipv6_prefixes
    }
  ]
}
