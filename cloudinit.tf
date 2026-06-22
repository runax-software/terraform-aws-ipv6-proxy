locals {
  ansible_dir   = "${path.module}/ansible"
  ansible_files = fileset(local.ansible_dir, "**")

  # Map: in-bundle destination path => absolute source path, for every file in
  # every user-supplied extra role. Shipped alongside the built-in roles.
  extra_role_files = merge([
    for r in var.extra_roles : {
      for f in fileset(r.path, "**") :
      "roles/${r.name}/${f}" => "${r.path}/${f}"
    }
  ]...)

  extra_role_names = [for r in var.extra_roles : r.name]
}

data "cloudinit_config" "this" {
  count         = var.instance_count
  gzip          = true
  base64_encode = true

  lifecycle {
    precondition {
      condition     = (var.proxy_user == "" && var.proxy_pass == "") || (var.proxy_user != "" && var.proxy_pass != "")
      error_message = "proxy_user and proxy_pass must both be set or both be empty."
    }
  }

  # Ship the Ansible bundle, per-instance vars, and install Ansible.
  part {
    content_type = "text/cloud-config"
    content = join("\n", [
      "#cloud-config",
      yamlencode({
        package_update = true
        packages       = ["ansible-core", "python3-apt"]
        write_files = concat(
          [
            for f in local.ansible_files : {
              path        = "/opt/ipv6-proxy/ansible/${f}"
              owner       = "root:root"
              permissions = "0644"
              content     = file("${local.ansible_dir}/${f}")
            }
          ],
          [
            for dest, src in local.extra_role_files : {
              path        = "/opt/ipv6-proxy/ansible/${dest}"
              owner       = "root:root"
              permissions = "0644"
              content     = file(src)
            }
          ],
          [
            {
              path        = "/opt/ipv6-proxy/extra-vars.json"
              owner       = "root:root"
              permissions = "0600"
              content = jsonencode({
                proxy_ipv6_prefix     = try(tolist(aws_network_interface.this[count.index].ipv6_prefixes)[0], "")
                proxy_user            = var.proxy_user
                proxy_pass            = var.proxy_pass
                proxy_assign_start    = var.proxy_assign_start
                proxy_assign_count    = var.proxy_assign_count
                proxy_socks_base_port = var.proxy_port_range_v6.from
                proxy_v4_base_port    = var.proxy_port_range_v4.from
                threeproxy_repo       = var.threeproxy_repo
                node_exporter_enabled = var.node_exporter_enabled
                node_exporter_version = var.node_exporter_version
                node_exporter_port    = var.node_exporter_port
                extra_roles           = local.extra_role_names
              })
            }
          ]
        )
      })
    ])
  }

  # Run the playbook locally against the node.
  part {
    content_type = "text/x-shellscript"
    content      = <<-BOOT
      #!/usr/bin/env bash
      set -euo pipefail
      exec > >(tee -a /var/log/proxy-bootstrap.log) 2>&1

      cd /opt/ipv6-proxy/ansible
      ansible-playbook -i 'localhost,' -c local site.yml \
        -e @/opt/ipv6-proxy/extra-vars.json
    BOOT
  }
}
