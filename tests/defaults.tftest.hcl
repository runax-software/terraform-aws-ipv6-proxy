# Default configuration: one node, sane naming, secure compute settings.

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
}

run "defaults" {
  command = apply

  assert {
    condition     = aws_vpc.this.tags["Name"] == "ipv6-proxy-vpc"
    error_message = "VPC Name tag should be derived from the default name_prefix."
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "10.10.0.0/16"
    error_message = "VPC should use the default IPv4 CIDR."
  }

  assert {
    condition     = length(aws_subnet.this) == 1 && length(aws_route_table.this) == 1 && length(aws_security_group.this) == 1 && length(aws_network_interface.this) == 1 && length(aws_instance.this) == 1
    error_message = "Default instance_count = 1 should create exactly one of each per-instance resource."
  }

  assert {
    condition     = aws_subnet.this[0].cidr_block == "10.10.0.0/24"
    error_message = "First subnet should be the first /24 carved from the VPC CIDR."
  }

  assert {
    condition     = aws_subnet.this[0].ipv6_cidr_block == "2600:1f28:3d:c000::/64"
    error_message = "First subnet should get the first /64 carved from the VPC IPv6 block."
  }

  assert {
    condition     = aws_network_interface.this[0].ipv6_prefix_count == 1 && aws_network_interface.this[0].source_dest_check == false
    error_message = "ENI must request one delegated IPv6 prefix and disable source/dest check."
  }

  assert {
    condition     = aws_instance.this[0].metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must stay required."
  }

  assert {
    condition     = aws_instance.this[0].root_block_device[0].encrypted == true && aws_instance.this[0].root_block_device[0].delete_on_termination == true
    error_message = "Root volume must be encrypted and deleted on termination."
  }

  assert {
    condition     = aws_instance.this[0].user_data_replace_on_change == true
    error_message = "user-data changes must force instance replacement."
  }

  assert {
    condition     = aws_instance.this[0].tags["Name"] == "ipv6-proxy-instance-1"
    error_message = "Instance Name tag should be prefix + 1-based index."
  }

  assert {
    condition     = length(aws_default_security_group.this.ingress) == 0 && length(aws_default_security_group.this.egress) == 0
    error_message = "The VPC default security group must be taken over with no rules."
  }

  assert {
    condition     = output.vpc_ipv6_cidr_block == "2600:1f28:3d:c000::/56"
    error_message = "vpc_ipv6_cidr_block output should expose the VPC IPv6 block."
  }

  assert {
    condition     = length(output.instance_details) == 1 && output.instance_details[0].instance_id == aws_instance.this[0].id
    error_message = "instance_details output should describe each instance."
  }
}
