#! /bin/bash
set -x
sed -i "/\/media\/CentOS/d" /etc/fstab
echo "$1        /media/CentOS   iso9660 ro      0       0" >> /etc/fstab
[ -e /media/CentOS ] || mkdir -p /media/CentOS
mount /media/CentOS
yum --disablerepo=* --enablerepo=*media install -y yum-utils
yum-config-manager --disable \* > /dev/null
yum-config-manager --enable \*media > /dev/null
