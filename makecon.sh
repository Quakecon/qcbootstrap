#!/bin/bash

set -u
set -e

source base.sh

IP_NS=172.16.1.105
IP_NS1=172.16.1.102
IP_NS2=172.16.1.103
IP_NS3=172.16.1.104
IP_DHCP1=172.16.1.174
IP_DHCP2=172.16.1.175

# Note: base changes director to IMGDIR, so local paths must be
# absolute or relative to IMGDIR

function master_auth_ns {
    base "$1" "$2" \
	 --install "nsd,git,dnsutils,unbound" \
	 --run-command "git clone https://github.com/Quakecon/dns.git /home/qcadmin/dns" \
	 --copy /home/qcadmin/dns/scripts/pre-commit:/home/qcadmin/dns/.git/hooks \
	 --copy /home/qcadmin/dns/scripts/post-commit:/home/qcadmin/dns/.git/hooks \
	 --copy-in ../dns/secret.keys:/etc/nsd \
	 --run-command "chgrp -R qcadmin /home/qcadmin/dns" \
	 --run-command "chmod -R g+w /home/qcadmin/dns" \
	 --copy /home/qcadmin/dns/zones:/etc/nsd \
	 --copy /home/qcadmin/dns/nsd.conf.master:/etc/nsd \
	 --move /etc/nsd/nsd.conf.master:/etc/nsd/nsd.conf \
	 --run-command "nsd-control-setup" \
	 --run-command "chgrp -R qcadmin /etc/nsd" \
	 --run-command "chmod -R g+w /etc/nsd/zones" \
	 --run-command "chmod -R g+w /etc/nsd/nsd.conf" \
	 --run-command "systemctl enable nsd.service" \
	 "${@:3}"
}

function slave_recurse_ns {
    base $1 $2 \
	 --install "nsd,unbound,git,dnsutils" \
	 --copy-in ../dns/secret.keys:/etc/nsd \
	 --copy-in ../dns/unbound.conf:/etc/unbound \
	 --copy-in ../dns/nsd.conf.slave:/etc/nsd \
	 --mkdir /etc/nsd/zones \
	 --move /etc/nsd/nsd.conf.slave:/etc/nsd/nsd.conf \
	 --run-command "nsd-control-setup" \
	 --run-command "unbound-control-setup" \
	 --run-command "chgrp -R qcadmin /etc/nsd" \
	 --run-command "chgrp -R qcadmin /etc/unbound" \
	 --run-command "chmod g+w /etc/nsd/nsd.conf" \
	 --run-command "chmod g+w /etc/unbound/unbound.conf" \
	 --run-command "systemctl enable nsd.service" \
	 --run-command "systemctl enable unbound.service" \
	 "${@:3}"
}

# base dhcp1 $IP_DHCP1 \
#      --install "dhcpd,git"

if [ $# -eq 0 ]; then
    ssh-keygen -N "" -f id_rsa
    cat id_rsa.pub authorized_keys.template > authorized_keys
    dns/scripts/gen-secret.sh dns/secret.keys.template > dns/secret.keys
    master_auth_ns ns $IP_NS
    slave_recurse_ns ns1 $IP_NS1
    slave_recurse_ns ns2 $IP_NS2
    slave_recurse_ns ns3 $IP_NS3
else
    $@
fi

