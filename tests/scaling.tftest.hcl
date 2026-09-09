# Everything scales by var.instance_count: one subnet / route table / SG /
# ENI / instance per node, all inside the one shared VPC.

mock_provider "aws" {
  mock_resource "aws_vpc" {
    defaults = {
      ipv6_cidr_block = "2600:1f28:3d:c000::/56"
    }
  }

  mock_resource "aws_network_interface" {
    defaults = {
      ipv6_prefixes = ["2600:1f28:3d:c000:1000::/80"]
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }
}

mock_provider "cloudinit" {
  mock_data "cloudinit_config" {
    defaults = {
      # aws_instance validates user_data_base64, so the mock must be valid base64.
      rendered = "IyBtb2NrIGNsb3VkLWluaXQ="
    }
  }
}

variables {
  existing_key_pair_name = "test-key"
  instance_count         = 3
}

run "three_instances" {
  command = apply

  assert {
    condition     = length(aws_subnet.this) == 3 && length(aws_route_table.this) == 3 && length(aws_route_table_association.this) == 3 && length(aws_security_group.this) == 3 && length(aws_network_interface.this) == 3 && length(aws_instance.this) == 3
    error_message = "instance_count = 3 should create three of each per-instance resource."
  }

  assert {
    condition     = tolist(aws_subnet.this[*].cidr_block) == tolist(["10.10.0.0/24", "10.10.1.0/24", "10.10.2.0/24"])
    error_message = "Each subnet should get a consecutive /24 from the VPC CIDR."
  }

  assert {
    condition     = tolist(aws_subnet.this[*].ipv6_cidr_block) == tolist(["2600:1f28:3d:c000::/64", "2600:1f28:3d:c001::/64", "2600:1f28:3d:c002::/64"])
    error_message = "Each subnet should get a consecutive /64 from the VPC IPv6 block."
  }

  assert {
    condition     = alltrue([for i in range(3) : aws_route_table_association.this[i].subnet_id == aws_subnet.this[i].id && aws_route_table_association.this[i].route_table_id == aws_route_table.this[i].id])
    error_message = "Each subnet must be associated with its own route table."
  }

  assert {
    condition     = alltrue([for i in range(3) : contains(aws_network_interface.this[i].security_groups, aws_security_group.this[i].id)])
    error_message = "Each ENI must use its own per-instance security group."
  }

  assert {
    condition     = aws_instance.this[2].tags["Name"] == "ipv6-proxy-instance-3" && aws_subnet.this[2].tags["Name"] == "ipv6-proxy-subnet-3"
    error_message = "Per-instance Name tags should use 1-based suffixes."
  }

  assert {
    condition     = length(output.subnet_ids) == 3 && length(output.security_group_ids) == 3 && length(output.eni_ids) == 3 && length(output.instance_ids) == 3 && length(output.instance_details) == 3
    error_message = "List outputs should have one element per instance."
  }
}
