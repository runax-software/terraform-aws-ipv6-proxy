# Naming
variable "name_prefix" {
  description = "Prefix applied to the names/tags of every resource this module creates (VPC, IGW, subnets, route tables, security groups, ENIs, instances)."
  type        = string
  default     = "ipv6-proxy"
}

# Networking
variable "instance_count" {
  description = "How many EC2 instances / subnets / route tables / security groups to create."
  type        = number
  default     = 1
}

variable "ipv4_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.10.0.0/16"
}

# Compute
variable "existing_key_pair_name" {
  description = "Name of an existing EC2 key pair for SSH access."
  type        = string
}

variable "ec2_instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "ssh_ingress_cidrs" {
  description = "CIDR blocks allowed to reach SSH (TCP 22). IPv4 and IPv6 CIDRs may be mixed. Empty (the default) creates no SSH ingress rule at all."
  type        = list(string)
  default     = []
}

variable "root_volume_type" {
  description = "EBS volume type for the root block device."
  type        = string
  default     = "gp2"
}

variable "root_volume_size" {
  description = "EBS volume size (GB) for the root block device."
  type        = number
  default     = 30
}

# Proxy (3proxy)
variable "proxy_user" {
  description = "Proxy auth username. Leave empty together with proxy_pass for no auth."
  type        = string
  default     = ""
}

variable "proxy_pass" {
  description = "Proxy auth password. Leave empty together with proxy_user for no auth."
  type        = string
  default     = ""
  sensitive   = true
}

variable "proxy_assign_start" {
  description = "Starting index for the /128 IPv6 addresses carved from the delegated prefix."
  type        = number
  default     = 10
}

variable "proxy_assign_count" {
  description = "How many /128 IPv6 addresses to assign per instance."
  type        = number
  default     = 10

  validation {
    condition     = var.proxy_assign_count > 0
    error_message = "proxy_assign_count must be greater than 0."
  }
}

variable "proxy_port_range_v4" {
  description = "IPv4 TCP listener port range for the proxy (opened in the security group). 'from' is the base listener port."
  type = object({
    from = number
    to   = number
  })
  default = {
    from = 21000
    to   = 22000
  }

  validation {
    condition     = var.proxy_port_range_v4.from <= var.proxy_port_range_v4.to
    error_message = "proxy_port_range_v4.from must be <= proxy_port_range_v4.to."
  }
}

variable "proxy_port_range_v6" {
  description = "IPv6 TCP listener port range for the proxy (opened in the security group). 'from' is the base listener port."
  type = object({
    from = number
    to   = number
  })
  default = {
    from = 11000
    to   = 12000
  }

  validation {
    condition     = var.proxy_port_range_v6.from <= var.proxy_port_range_v6.to
    error_message = "proxy_port_range_v6.from must be <= proxy_port_range_v6.to."
  }
}

variable "threeproxy_repo" {
  description = "Git repository to build 3proxy from."
  type        = string
  default     = "https://github.com/z3APA3A/3proxy.git"
}

# Prometheus node_exporter (optional)
variable "node_exporter_enabled" {
  description = "Whether to install and run Prometheus node_exporter on each node, and open its port in the security group."
  type        = bool
  default     = true
}

variable "node_exporter_port" {
  description = "TCP port node_exporter listens on (opened in the security group when enabled)."
  type        = number
  default     = 9100
}

variable "node_exporter_version" {
  description = "Version of node_exporter to install."
  type        = string
  default     = "1.9.1"
}

# Extensibility
variable "extra_roles" {
  description = <<-EOT
    Additional Ansible roles to run after the built-in roles. Each entry points
    at a local role directory; its files are shipped to the instance under
    ansible/roles/<name>/ and the role is appended to the play. Example:

      extra_roles = [
        { name = "install_foo", path = "$${path.root}/roles/install_foo" }
      ]
  EOT
  type = list(object({
    name = string
    path = string
  }))
  default = []
}
