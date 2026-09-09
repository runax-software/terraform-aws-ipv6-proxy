# Security group rules: proxy port ranges, optional SSH ingress split into
# IPv4/IPv6 CIDRs, and the node_exporter toggle.

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

run "default_rules" {
  command = apply

  # proxy v4 + proxy v6 + http + https + node_exporter, and no SSH by default.
  assert {
    condition     = length(aws_security_group.this[0].ingress) == 5
    error_message = "Default SG should have exactly 5 ingress rules."
  }

  assert {
    condition     = anytrue([for r in aws_security_group.this[0].ingress : r.from_port == 21000 && r.to_port == 22000 && r.cidr_blocks == tolist(["0.0.0.0/0"]) && length(coalesce(r.ipv6_cidr_blocks, [])) == 0])
    error_message = "Default IPv4 proxy port range 21000-22000 should be open to 0.0.0.0/0 only."
  }

  assert {
    condition     = anytrue([for r in aws_security_group.this[0].ingress : r.from_port == 11000 && r.to_port == 12000 && r.ipv6_cidr_blocks == tolist(["::/0"]) && length(coalesce(r.cidr_blocks, [])) == 0])
    error_message = "Default IPv6 proxy port range 11000-12000 should be open to ::/0 only."
  }

  assert {
    condition     = !anytrue([for r in aws_security_group.this[0].ingress : r.from_port == 22])
    error_message = "No SSH ingress rule should exist when ssh_ingress_cidrs is empty."
  }

  assert {
    condition     = anytrue([for r in aws_security_group.this[0].ingress : r.from_port == 9100 && r.to_port == 9100])
    error_message = "node_exporter port should be open by default."
  }

  assert {
    condition     = anytrue([for r in aws_security_group.this[0].egress : r.protocol == "-1" && r.cidr_blocks == tolist(["0.0.0.0/0"]) && r.ipv6_cidr_blocks == tolist(["::/0"])])
    error_message = "All outbound traffic should be allowed."
  }
}

run "ssh_cidrs_split_by_family" {
  command = apply

  variables {
    ssh_ingress_cidrs = ["203.0.113.0/24", "2001:db8::/32", "198.51.100.7/32"]
  }

  assert {
    condition = anytrue([
      for r in aws_security_group.this[0].ingress :
      r.from_port == 22 && r.to_port == 22 &&
      toset(r.cidr_blocks) == toset(["203.0.113.0/24", "198.51.100.7/32"]) &&
      toset(r.ipv6_cidr_blocks) == toset(["2001:db8::/32"])
    ])
    error_message = "SSH rule must split mixed CIDRs into IPv4 cidr_blocks and IPv6 ipv6_cidr_blocks."
  }

  assert {
    condition     = length(aws_security_group.this[0].ingress) == 6
    error_message = "Enabling SSH should add exactly one ingress rule."
  }
}

run "node_exporter_disabled" {
  command = apply

  variables {
    node_exporter_enabled = false
  }

  assert {
    condition     = !anytrue([for r in aws_security_group.this[0].ingress : r.from_port == 9100])
    error_message = "node_exporter port must not be open when node_exporter_enabled = false."
  }

  assert {
    condition     = length(aws_security_group.this[0].ingress) == 4
    error_message = "Disabling node_exporter should leave 4 ingress rules."
  }
}

run "custom_proxy_port_ranges" {
  command = apply

  variables {
    proxy_port_range_v4 = { from = 31000, to = 31500 }
    proxy_port_range_v6 = { from = 41000, to = 41500 }
  }

  assert {
    condition     = anytrue([for r in aws_security_group.this[0].ingress : r.from_port == 31000 && r.to_port == 31500 && r.cidr_blocks == tolist(["0.0.0.0/0"])])
    error_message = "Custom IPv4 proxy port range should be reflected in the SG."
  }

  assert {
    condition     = anytrue([for r in aws_security_group.this[0].ingress : r.from_port == 41000 && r.to_port == 41500 && r.ipv6_cidr_blocks == tolist(["::/0"])])
    error_message = "Custom IPv6 proxy port range should be reflected in the SG."
  }
}
