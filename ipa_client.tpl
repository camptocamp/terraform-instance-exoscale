#cloud-config
packages:
  - ipa-client
  - freeipa-client
runcmd:
  - until ipa-client-install --hostname ${hostname} --unattended --domain ${domain} --password ${password}; do sleep 15; done
