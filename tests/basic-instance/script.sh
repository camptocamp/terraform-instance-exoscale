#!/bin/sh

echo "install goss"
curl -fsSL https://goss.rocks/install | sh

while pgrep cloud-init > /dev/null ; do
  echo "waiting for cloud-init to finish, sleeping for 10 seconds..."
  sleep 10
done

echo "launching goss"
/usr/local/bin/goss validate
