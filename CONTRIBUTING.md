# Contributing

Thanks for your interest in improving `terraform-aws-ipv6-proxy`! This is a
single, self-contained OpenTofu/Terraform module (root-level `.tf` files plus
the Ansible roles under `ansible/`). Contributions of all sizes are welcome.

This project is developed primarily against [OpenTofu](https://opentofu.org/);
Terraform is fully supported and exercised in CI, so examples below use `tofu`
but `terraform` works identically.

## Getting started

You'll need:

- [OpenTofu](https://opentofu.org/docs/intro/install/) **or**
  [Terraform](https://developer.hashicorp.com/terraform/install) `>= 1.10.0` —
  the module supports both.
- [tflint](https://github.com/terraform-linters/tflint)
- [ansible-lint](https://ansible.readthedocs.io/projects/lint/) (for changes
  under `ansible/`)
- An AWS account is only required to actually `apply`; the checks below run
  without one.

## Making a change

1. Fork the repo and create a branch off `main`.
2. Make your change. If you add or rename an input/output, update the relevant
   table in [`README.md`](README.md).
3. Run the checks below and make sure they pass.
4. Open a pull request with a clear description of *what* changed and *why*.

## Local checks

These mirror the CI workflows, so running them first avoids a red build. Swap
`tofu` for `terraform` if you prefer:

```bash
# Format (CI runs with -check; this rewrites in place)
tofu fmt -recursive

# Validate
tofu init -backend=false
tofu validate

# Lint Terraform
tflint --init
tflint

# Lint Ansible (only if you touched ansible/)
cd ansible && ansible-lint
```

A [Trivy](https://aquasecurity.github.io/trivy/) IaC scan also runs in CI; to
reproduce it locally:

```bash
trivy config .
```

## What CI runs

Every pull request runs three workflows under
[`.github/workflows/`](.github/workflows):

- **CI** — `fmt -check`, `validate`, and `tflint`, against **both OpenTofu and
  Terraform**.
- **Security** — Trivy IaC scan (fails on `HIGH`/`CRITICAL`).
- **Ansible Lint** — `ansible-lint` over `ansible/`.

## Guidelines

- Keep the module self-contained — no nested sub-modules.
- Prefer extending behavior through the existing `extra_roles` mechanism (see
  the README) rather than hard-coding new roles into the module.
- Mark any new sensitive input with `sensitive = true`.
- Don't commit `*.tfvars`, state files, or anything else covered by
  [`.gitignore`](.gitignore).

## Reporting issues

Open a GitHub issue with the OpenTofu/Terraform version, the module version
(tag or commit), a minimal reproduction, and the relevant output. For anything
security-sensitive, please avoid filing a public issue with exploit details.
