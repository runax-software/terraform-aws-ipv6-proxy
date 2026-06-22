# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in `terraform-aws-ipv6-proxy`, please report it responsibly.

**Do not open a public issue.**

Instead, [open a private security advisory](https://github.com/runax-software/terraform-aws-ipv6-proxy/security/advisories/new) on GitHub.

Please include:

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Response

We will acknowledge your report within 48 hours and aim to provide a fix or mitigation within 7 days for critical issues.

## Supported Versions

| Version | Supported |
|---------|-----------|
| latest  | Yes       |

## Scope

This policy covers the Terraform/OpenTofu module code and the bundled Ansible roles under `ansible/`. Third-party components the module builds or installs at runtime (e.g. [3proxy](https://github.com/z3APA3A/3proxy), Prometheus `node_exporter`) and Terraform providers are maintained upstream; please report issues in those to their respective projects.
