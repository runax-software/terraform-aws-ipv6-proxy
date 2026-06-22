# AGENTS.md

Instructions for AI coding agents working on this repository.

## Project overview

`terraform-aws-ipv6-proxy` is a single, self-contained Terraform/OpenTofu module
that provisions a fleet of IPv6 SOCKS5 proxy nodes on AWS, powered by
[3proxy](https://github.com/z3APA3A/3proxy). Each node gets its own subnet,
security group, and ENI with a delegated IPv6 `/80` prefix, and is configured
entirely by Ansible running locally on the instance at first boot via cloud-init
— no SSH, no provisioners, no local Ansible install.

This project is developed primarily against **OpenTofu**; Terraform is fully
supported and exercised in CI. Examples below use `tofu`, but `terraform` works
identically.

## Key patterns

- **One module, no sub-modules.** Networking and compute live together at the
  repo root. Keep it that way.
- **Everything scales by `var.instance_count`.** Each node gets its own
  `aws_subnet` / `aws_route_table` / `aws_security_group` / `aws_network_interface`
  / `aws_instance` (all `count`-indexed) inside one shared VPC + internet gateway.
- **Provisioning happens via cloud-init, not Terraform provisioners.**
  `cloudinit.tf` ships the whole `ansible/` tree (plus any `extra_roles`) into
  EC2 user-data as gzip+base64, then runs `ansible-playbook -c local site.yml`.
- **Editing anything under `ansible/` changes the rendered user-data**, which
  triggers instance replacement on the next apply
  (`user_data_replace_on_change = true`). This is intentional.
- **User-data has a 16 KB AWS limit.** Large `extra_roles` can blow it — keep
  shipped files small.
- **`name_prefix` drives every resource `Name` tag** via `locals` in `main.tf`.
- **Security defaults**: IMDSv2 required (`http_tokens = "required"`),
  `proxy_pass` is `sensitive`. Don't weaken these.
- **`proxy_user` / `proxy_pass` are both-or-neither** — enforced by a
  `precondition` in `cloudinit.tf`. Per-instance values are passed to Ansible via
  `/opt/ipv6-proxy/extra-vars.json`.

## Build & validate

These mirror CI, so run them before pushing. Swap `tofu` for `terraform` if you
prefer:

```bash
tofu fmt -recursive          # CI runs with -check
tofu init -backend=false
tofu validate

tflint --init && tflint      # GITHUB_TOKEN avoids rate limits for plugin download

cd ansible && ansible-lint   # only if you touched ansible/

trivy config .               # IaC security scan (CI fails on HIGH/CRITICAL)
```

An AWS account is only needed to actually `apply`; all checks above run without
one.

## Conventions

- **OpenTofu-first**, Terraform-supported — keep both working; CI runs the
  matrix.
- Every variable has a `description`; add `validation` blocks for constrained
  inputs and `sensitive = true` for secrets.
- **When you add/rename an input or output, update the matching table in
  [`README.md`](README.md).**
- Prefer extending behavior through `var.extra_roles` over hard-coding new roles
  into the module.
- Conventional commit prefixes are preferred: `feat:`, `fix:`, `docs:`,
  `refactor:`, `chore:`.

## Adding a built-in Ansible role

1. Create `ansible/roles/<name>/` (`tasks/main.yml`, optional `defaults/`,
   `handlers/`, `templates/`).
2. Wire it into `ansible/site.yml` (as a role or a guarded `import_role`/
   `include_role`, following the `node_exporter` example).
3. If it needs config from Terraform, add the variable in `variables.tf`, thread
   it into the `extra-vars.json` block in `cloudinit.tf`, and consume it in the
   role.
4. Run `ansible-lint`. Remember: any change here forces instance replacement.

For *user-supplied* provisioning, no module edits are needed — consumers pass
`var.extra_roles` (see the README).

## Do not

- Split this into nested sub-modules.
- Add Terraform `provisioner` blocks or require SSH — provisioning is cloud-init
  + local Ansible by design.
- Remove `http_tokens = "required"`, drop `sensitive` on `proxy_pass`, or widen
  the security group beyond what a change needs.
- Commit `*.tfvars`, state files, or lock files (see [`.gitignore`](.gitignore)).
- Break Terraform compatibility — both engines must pass CI.
