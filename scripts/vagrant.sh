#!/usr/bin/env bash

groupadd vagrant
useradd vagrant -g vagrant -G wheel
echo "vagrant" | passwd --stdin vagrant
echo "vagrant        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers.d/99-vagrant

mkdir /home/vagrant/.ssh

# Use my own private key
cat  /tmp/workshop.key.pub >> /home/vagrant/.ssh/authorized_keys
chown -R vagrant /home/vagrant/.ssh
chmod -R go-rwsx /home/vagrant/.ssh
