#!/bin/bash

set -e
set -u

ARCH=x86_64
CACHEDIR=$PWD/cache
OUTDIR=$PWD/images
IMGFORMAT=raw
SIZE=50G
QCADMINPW='$1$04tl7iXr$RrbXcWpFW5lAP4cGTIWTI/'

function base () {
    HOSTNAME=$1
    IPADDRESS=$2
    (cd $OUTDIR;
     virt-builder ubuntu-16.04 \
		  --size $SIZE \
		  --output ${HOSTNAME}.raw \
		  --format $IMGFORMAT \
		  --cache $CACHEDIR \
		  --arch $ARCH \
		  --hostname ${HOSTNAME}.at.quakecon.org \
		  --install "openntpd,vim,iputils-ping,iputils-tracepath" \
		  --install "openssh-client,policykit-1,tcpdump" \
		  --timezone "America/Chicago" \
		  --update \
		  --root-password disabled \
		  --run-command "useradd -m -p '${QCADMINPW}' -s /bin/bash qcadmin" \
		  --ssh-inject qcadmin:file:$OLDPWD/authorized_keys \
		  --copy-in ../id_rsa:/home/qcadmin/.ssh \
		  --run-command 'chown -R qcadmin:qcadmin /home/qcadmin/.ssh' \
		  --run-command 'echo "qcadmin ALL=(ALL) ALL" >> /etc/sudoers' \
		  --run-command 'echo "qcadmin ALL=(root) NOPASSWD: /bin/systemctl" >> /etc/sudoers' \
		  --run-command 'echo "qcadmin ALL=(root) NOPASSWD: /bin/journalctl" >> /etc/sudoers' \
		  --run-command 'echo "GRUB_CMDLINE_LINUX_DEFAULT=\"console=tty0 net.ifnames=0\"" >> /etc/default/grub' \
		  --run-command 'update-grub' \
		  --write "/etc/network/interfaces:
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address ${IPADDRESS}/24
    gateway 172.16.1.1
    dns-nameservers 172.16.1.102 172.16.1.103 172.16.1.104 8.8.8.8
    dns-search at.quakecon.org
" \
		  --run-command "systemctl enable openntpd" \
		  --run-command 'cat <<EOF > /etc/openntpd/ntpd.conf
servers 172.16.1.100
servers 172.16.1.101
constraints from "https://www.google.com/"
EOF
' \
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
