#!/bin/bash

set -e
set -u

ARCH=x86_64
CACHEDIR=$PWD/cache
OUTDIR=$PWD/images
IMGFORMAT=raw
SIZE=50G
QCADMINPW='$1$04tl7iXr$RrbXcWpFW5lAP4cGTIWTI/'
http_proxy="http://172.16.1.1:3128"

function base () {
    HOSTNAME=$1
    IPADDRESS=$2
    (cd $OUTDIR;
     touch ${HOSTNAME}.img
     chattr +C ${HOSTNAME}.img
     virt-builder ubuntu-16.04 \
		  --size $SIZE \
		  --output ${HOSTNAME}.img \
		  --format $IMGFORMAT \
		  --cache $CACHEDIR \
		  --arch $ARCH \
		  --hostname ${HOSTNAME}.at.quakecon.org \
		  --install "vim,iputils-ping,iputils-tracepath,openssh-client" \
		  --timezone "America/Chicago" \
		  --update \
		  --root-password disabled \
		  --run-command "useradd -m -p '${QCADMINPW}' -s /bin/bash qcadmin" \
		  --ssh-inject qcadmin:file:$OLDPWD/authorized_keys \
		  --copy-in ../id_rsa:/home/qcadmin/.ssh \
		  --run-command 'chown -R qcadmin:qcadmin /home/qcadmin/.ssh' \
		  --run-command 'echo "qcadmin ALL=(ALL) ALL" >> /etc/sudoers' \
		  --run-command 'echo "qcadmin ALL=(root) NOPASSWD: /bin/systemctl" >> /etc/sudoers' \
		  --run-command 'echo GRUB_CMDLINE_LINUX_DEFAULT="console=tty0" >> /etc/default/grub' \
		  --run-command 'update-grub' \
		  --write "/etc/network/interfaces:
auto lo
iface lo inet loopback

auto ens3
iface ens3 inet static
    address ${IPADDRESS}/24
    gateway 172.16.1.1
    dns-nameservers 172.16.1.102 172.16.1.103 172.16.1.104 8.8.8.8
    dns-search at.quakecon.org
" \
		  "${@:3}"
     
     cd $OLDPWD)
}

if [ "$0" == "$BASH_SOURCE" ]; then
    if [ $# -lt 2 ]; then
	echo "Usage: $0 <hostname> <ipaddress>"
	exit 1
    fi
    base "$@"
fi
