#cloud-config
packages:
  - freeipa-client
runcmd:
  - ipa-client-install --hostname ${hostname} --unattended --domain ${domain} --password ${password}
