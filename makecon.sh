#!/bin/bash

set -u
set -e

source base.sh

IP_CORE1=172.16.1.100
IP_CORE2=172.16.1.101
IP_NS1=172.16.1.102
IP_NS2=172.16.1.103
IP_NS3=172.16.1.104

# Note: base changes director to IMGDIR, so local paths must be
# absolute or relative to IMGDIR

function core {
    base "$1" "$2" \
	 --install "nsd,git,dnsutils,isc-dhcp-server" \
	 --run-command "systemctl enable nsd.service" \
	 --run-command "git clone https://github.com/Quakecon/dhcp.git /home/qcadmin/dhcp" \
	 --copy /home/qcadmin/dhcp/scripts/pre-commit:/home/qcadmin/dhcp/.git/hooks \
	 --copy /home/qcadmin/dhcp/scripts/post-commit:/home/qcadmin/dhcp/.git/hooks \
	 --run-command "chgrp -R qcadmin /home/qcadmin/dhcp" \
	 --run-command "chmod -R g+w /home/qcadmin/dhcp" \
	 --run-command "cp /home/qcadmin/dhcp/*.conf* /etc/dhcp" \
	 --move /etc/dhcp/dhcpd.conf.${1}:/etc/dhcp/dhcpd.conf \
	 --run-command "chgrp -R qcadmin /etc/dhcp" \
	 --run-command "systemctl enable isc-dhcp-server.service" \
	 --run-command "chmod -R g+w /etc/dhcp" \
	 --copy /home/qcadmin/dhcp/isc-dhcp-server.service:/etc/systemd/system \
	 --run-command 'cat <<EOF > /etc/openntpd/ntpd.conf
servers pool.ntp.org
constraints from "https://www.google.com/"
listen on *
EOF
' \
	 "${@:3}"
}

function core1 {
    # DHCP Primary, DNS Master, NTP Server
    core core1 $IP_CORE1 \
	  --run-command "git clone https://github.com/Quakecon/dns.git /home/qcadmin/dns" \
	 --copy /home/qcadmin/dns/scripts/pre-commit:/home/qcadmin/dns/.git/hooks \
	 --copy /home/qcadmin/dns/scripts/post-commit:/home/qcadmin/dns/.git/hooks \
	 --copy-in ../dns/secret.keys:/etc/nsd \
	 --run-command "chgrp -R qcadmin /home/qcadmin/dns" \
	 --run-command "chmod -R g+w /home/qcadmin/dns" \
	 --copy /home/qcadmin/dns/zones:/etc/nsd \
	 --copy /home/qcadmin/dns/nsd.conf.master:/etc/nsd \
	 --move /etc/nsd/nsd.conf.master:/etc/nsd/nsd.conf \
	 --run-command "chgrp -R qcadmin /etc/nsd" \
	 --run-command "chmod -R g+w /etc/nsd/zones" \
	 --run-command "chmod g+w /etc/nsd/nsd.conf" \
	 --run-command 'echo "servers 172.16.1.101" >> /etc/openntpd/ntpd.conf'
}

function core2 {
    # DHCP Secondary, DNS Slave, NTP Server
    core core2 $IP_CORE2 \
	 --copy-in ../dns/secret.keys:/etc/nsd \
	 --copy-in ../dns/nsd.conf.slave:/etc/nsd \
	 --move /etc/nsd/nsd.conf.slave:/etc/nsd/nsd.conf \
	 --mkdir /etc/nsd/zones \
	 --run-command "chown -R nsd:qcadmin /etc/nsd" \
	 --run-command "chmod -R g+w /etc/nsd/zones" \
	 --run-command "chmod g+w /etc/nsd/nsd.conf" \
	 --run-command 'echo "servers 172.16.1.100" >> /etc/openntpd/ntpd.conf'
}
	 

function recursive_ns {
    base $1 $2 \
	 --install "unbound,git,dnsutils" \
	 --copy-in ../dns/unbound.conf:/etc/unbound \
	 --run-command "unbound-control-setup" \
	 --run-command "chgrp -R qcadmin /etc/unbound" \
	 --run-command "chmod g+w /etc/unbound/unbound.conf" \
	 --run-command "systemctl enable unbound.service" \
	 --run-command 'echo "net.core.rmem_max=4194304" >> /etc/sysctl.conf' \
	 --run-command 'echo "net.core.wmem_max=4194304" >> /etc/sysctl.conf' \
	 "${@:3}"
}

# base dhcp1 $IP_DHCP1 \
#      --install "dhcpd,git"

if [ $# -eq 0 ]; then
    ssh-keygen -N "" -f id_rsa
    cat id_rsa.pub authorized_keys.template > authorized_keys
    dns/scripts/gen-secret.sh dns/secret.keys.template > dns/secret.keys
    core1
    core2
    recursive_ns ns1 $IP_NS1
    recursive_ns ns2 $IP_NS2
    recursive_ns ns3 $IP_NS3
else
    $@
fi

