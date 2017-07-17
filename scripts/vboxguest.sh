#!/usr/bin/env bash

mkdir /tmp/virtualbox
mount /dev/sr1 /tmp/virtualbox
sh /tmp/virtualbox/VBoxLinuxAdditions.run
umount /tmp/virtualbox
rmdir /tmp/virtualbox
