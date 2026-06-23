# terraform-aws-ipv6-proxy

OpenTofu/Terraform module that provisions a fleet of **IPv6 SOCKS5 proxy nodes
on AWS**, powered by [3proxy](https://github.com/z3APA3A/3proxy). Each node lives
in its own subnet (network isolation, unique IPv6 prefix per node) and is
configured entirely by **Ansible**, which runs locally on the instance at first
boot via cloud-init.

It is a single, self-contained module — networking and compute resources are
defined together, with no nested sub-modules.

## What it creates

Per `instance_count`: a subnet, route table, security group, ENI (with a
delegated IPv6 `/80` prefix) and an EC2 instance, all inside one shared VPC +
internet gateway. On boot each node:

1. installs `ansible-core` (cloud-init),
2. runs `ansible/site.yml` with `connection: local`,
3. builds & configures 3proxy (one SOCKS5 listener per assigned IPv6),
4. optionally installs Prometheus `node_exporter`,
5. runs any roles you supplied via `extra_roles`.

No SSH access, no local Ansible install, and no provisioners are required — a
single `tofu apply` / `terraform apply` is all you run.

## Usage

```hcl
module "ipv6_proxy" {
  source = "github.com/runax-software/terraform-aws-ipv6-proxy?ref=v1.1.0"

  instance_count         = 3
  existing_key_pair_name = "my-keypair"

  # Optional proxy auth (set both, or neither)
  proxy_user = "user"
  proxy_pass = "secret"

  # Toggle Prometheus node_exporter
  node_exporter_enabled = true
}
```

Requires the `aws` provider to be configured (region/credentials) by the caller.

## Adding your own provisioning step

Write a normal Ansible role anywhere in your config and reference it. Its files
are shipped to the node and the role runs **after** the built-ins:

```hcl
extra_roles = [
  { name = "install_redis", path = "${path.root}/roles/install_redis" }
]
```

```
roles/install_redis/
├── tasks/main.yml
├── defaults/main.yml      # optional
├── handlers/main.yml      # optional
└── templates/...          # optional
```

No edits to this module are needed.

Pass configuration (including secrets) to your roles via `extra_vars`. It is
merged into the Ansible extra-vars the play already receives, so your role can
read the keys directly:

```hcl
extra_vars = {
  redis_version = "7.2"
  redis_password = var.redis_password   # sensitive
}
```

## Key inputs

| Variable | Default | Description |
| --- | --- | --- |
| `name_prefix` | `ipv6-proxy` | Prefix for the names/tags of every resource (VPC, IGW, subnet, route table, SG, ENI, instance) |
| `instance_count` | `1` | Nodes (and per-node subnet/SG/ENI) to create |
| `existing_key_pair_name` | — (required) | Existing EC2 key pair name |
| `ipv4_cidr` | `10.10.0.0/16` | VPC IPv4 CIDR (per-node /24s carved from it) |
| `ec2_instance_type` | `t3.micro` | Instance type |
| `ssh_ingress_cidrs` | `[]` | CIDRs allowed to reach SSH (port 22); IPv4/IPv6 may be mixed. Empty = no SSH rule at all |
| `proxy_user` / `proxy_pass` | `""` | Proxy auth; both set = `strong`, both empty = none |
| `proxy_assign_start` / `proxy_assign_count` | `10` / `10` | Range of `/128`s carved from the delegated prefix |
| `proxy_port_range_v4` / `proxy_port_range_v6` | `21000-22000` / `11000-12000` | Listener port ranges (`from` = base port); also opened in the SG |
| `node_exporter_enabled` | `true` | Install node_exporter + open its port |
| `node_exporter_port` | `9100` | node_exporter listen port |
| `node_exporter_version` | `1.9.1` | node_exporter version |
| `threeproxy_repo` | `z3APA3A/3proxy` | Git repo to build 3proxy from |
| `extra_roles` | `[]` | Extra Ansible roles to run (see above) |
| `extra_vars` | `{}` | Extra Ansible variables (`map(string)`, sensitive) merged into the play's extra-vars — typically config/secrets consumed by `extra_roles`. Module-owned keys always win on collision |

See [`variables.tf`](variables.tf) for the full list.

## Outputs

`vpc_id`, `vpc_ipv6_cidr_block`, `subnet_ids`, `security_group_ids`, `eni_ids`,
`eni_ipv6_prefixes`, `instance_ids`, `instance_details`.

## Notes

- Provisioning files are shipped inside EC2 user-data (gzip + base64). AWS caps
  user-data at 16 KB; very large `extra_roles` could exceed it.
- Editing anything under `ansible/` changes the rendered user-data, which
  triggers instance replacement on the next apply
  (`user_data_replace_on_change = true`).
- Bootstrap logs land in `/var/log/proxy-bootstrap.log` on each node.
