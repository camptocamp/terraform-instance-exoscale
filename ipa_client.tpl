#cloud-config
runcmd:
  - dnf upgrade -y
  - dnf install -y ipa-client # Somehow cloudinit's config-package-update-upgrade-install module is not run on CentOS 8...
  - until ipa-client-install --hostname ${hostname} --unattended --domain ${domain} --password ${password}; do sleep 15; done
