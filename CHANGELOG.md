# Changelog

## v1.0.0

Initial stable release.

### Features

- Single, self-contained OpenTofu/Terraform module that provisions a fleet of IPv6 SOCKS5 proxy nodes on AWS, powered by [3proxy](https://github.com/z3APA3A/3proxy).
- Per-node subnet, route table, security group, and ENI (with a delegated IPv6 `/80` prefix), all inside one shared VPC + internet gateway. Scales by `instance_count`.
- Nodes are configured by Ansible running locally at first boot via cloud-init — no SSH, no Terraform provisioners, no local Ansible install required.
- One SOCKS5 listener per assigned IPv6 address (`/128`s carved from the delegated prefix).
- Optional proxy authentication (`proxy_user` / `proxy_pass`, both-or-neither, enforced by a precondition).
- Optional Prometheus `node_exporter`, with its port opened in the security group when enabled.
- Extensible via `extra_roles` — ship user-supplied Ansible roles into the node without editing the module.
- Secure defaults: IMDSv2 required (`http_tokens = "required"`), encrypted root EBS volume, the VPC default security group locked down to deny all, no SSH ingress unless `ssh_ingress_cidrs` is set, and `proxy_pass` marked `sensitive`.
