# Input validation rules and the proxy_user/proxy_pass precondition.

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

run "rejects_zero_proxy_assign_count" {
  command = plan

  variables {
    proxy_assign_count = 0
  }

  expect_failures = [var.proxy_assign_count]
}

run "rejects_inverted_v4_port_range" {
  command = plan

  variables {
    proxy_port_range_v4 = { from = 22000, to = 21000 }
  }

  expect_failures = [var.proxy_port_range_v4]
}

run "rejects_inverted_v6_port_range" {
  command = plan

  variables {
    proxy_port_range_v6 = { from = 12000, to = 11000 }
  }

  expect_failures = [var.proxy_port_range_v6]
}

run "rejects_user_without_pass" {
  command = plan

  variables {
    proxy_user = "proxyuser"
    proxy_pass = ""
  }

  expect_failures = [data.cloudinit_config.this]
}

run "rejects_pass_without_user" {
  command = plan

  variables {
    proxy_user = ""
    proxy_pass = "s3cret"
  }

  expect_failures = [data.cloudinit_config.this]
}

run "accepts_user_and_pass_together" {
  command = plan

  variables {
    proxy_user = "proxyuser"
    proxy_pass = "s3cret"
  }

  assert {
    condition     = length(data.cloudinit_config.this) == 1
    error_message = "Plan should succeed when proxy_user and proxy_pass are both set."
  }
}
