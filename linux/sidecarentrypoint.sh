#!/bin/sh

# download package and move to shared folder
apt-get update && mkdir /tmp/pkgs/ && cd /tmp && apt download puppet 
sleep 25
mv /tmp/puppet*.deb /tmp/pkgs/puppet.deb
tail -f /dev/null