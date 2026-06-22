locals {
  vpc_name               = "${var.name_prefix}-vpc"
  internet_gateway_name  = "${var.name_prefix}-internet-gateway"
  subnet_name            = "${var.name_prefix}-subnet"
  route_table_name       = "${var.name_prefix}-route-table"
  security_group_name    = "${var.name_prefix}-security-group"
  network_interface_name = "${var.name_prefix}-network-interface"
  instance_name          = "${var.name_prefix}-instance"

  ssh_ipv4_cidrs = [for c in var.ssh_ingress_cidrs : c if !strcontains(c, ":")]
  ssh_ipv6_cidrs = [for c in var.ssh_ingress_cidrs : c if strcontains(c, ":")]
}

# Networking
resource "aws_vpc" "this" {
  cidr_block                       = var.ipv4_cidr
  assign_generated_ipv6_cidr_block = true
  enable_dns_support               = true
  enable_dns_hostnames             = false

  tags = {
    Name = local.vpc_name
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = local.internet_gateway_name
  }
}

# Take over the VPC's default security group and deny all traffic (no rules).
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name_prefix}-default-security-group"
  }
}

resource "aws_subnet" "this" {
  count                           = var.instance_count
  vpc_id                          = aws_vpc.this.id
  cidr_block                      = cidrsubnet(var.ipv4_cidr, 8, count.index)
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.this.ipv6_cidr_block, 8, count.index)
  assign_ipv6_address_on_creation = true
  map_public_ip_on_launch         = true

  enable_resource_name_dns_a_record_on_launch    = false
  enable_resource_name_dns_aaaa_record_on_launch = false
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "${local.subnet_name}-${count.index + 1}"
  }
}

resource "aws_route_table" "this" {
  count  = var.instance_count
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.route_table_name}-${count.index + 1}"
  }
}

resource "aws_route_table_association" "this" {
  count          = var.instance_count
  subnet_id      = aws_subnet.this[count.index].id
  route_table_id = aws_route_table.this[count.index].id
}

# Compute
resource "aws_security_group" "this" {
  count       = var.instance_count
  name        = "${local.security_group_name}-${count.index + 1}"
  description = "Security group for IPv6 proxy server"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "proxy ports range v4"
    from_port   = var.proxy_port_range_v4.from
    to_port     = var.proxy_port_range_v4.to
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description      = "proxy ports range v6"
    from_port        = var.proxy_port_range_v6.from
    to_port          = var.proxy_port_range_v6.to
    protocol         = "tcp"
    ipv6_cidr_blocks = ["::/0"]
  }

  dynamic "ingress" {
    for_each = length(var.ssh_ingress_cidrs) > 0 ? [1] : []
    content {
      description      = "ssh"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = local.ssh_ipv4_cidrs
      ipv6_cidr_blocks = local.ssh_ipv6_cidrs
    }
  }

  ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "https"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  dynamic "ingress" {
    for_each = var.node_exporter_enabled ? [1] : []
    content {
      description      = "prometheus node_exporter"
      from_port        = var.node_exporter_port
      to_port          = var.node_exporter_port
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }

  egress {
    description      = "all outbound"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${local.security_group_name}-${count.index + 1}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_network_interface" "this" {
  count             = var.instance_count
  subnet_id         = aws_subnet.this[count.index].id
  ipv6_prefix_count = 1
  source_dest_check = false

  security_groups = [
    aws_security_group.this[count.index].id
  ]

  tags = {
    Name = "${local.network_interface_name}-${count.index + 1}"
  }
}

resource "aws_instance" "this" {
  count         = var.instance_count
  ami           = data.aws_ami.ubuntu_22_04.id
  instance_type = var.ec2_instance_type
  key_name      = data.aws_key_pair.this.key_name

  network_interface {
    network_interface_id = aws_network_interface.this[count.index].id
    device_index         = 0
  }

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_tokens = "required"
  }

  user_data_base64            = data.cloudinit_config.this[count.index].rendered
  user_data_replace_on_change = true

  tags = {
    Name = "${local.instance_name}-${count.index + 1}"
  }
}
