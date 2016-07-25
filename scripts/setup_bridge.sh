#!/bin/bash

BRIDGE=qc0
NATNIC=$1

if [ $# -lt 1 ]; then
    echo "Warning: NIC not specified, traffic on the bridge will not be NATed"
fi

ip link add name $BRIDGE type bridge
ip addr add 172.16.1.1/24 dev $BRIDGE

if [ "${NATNIC}x" != "x" ]; then
    iptables -t nat -A POSTROUTING -o $NATNIC -j MASQUERADE
    iptables -A FORWARD -i $NATNIC -o $BRIDGE -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i $BRIDGE -o $NATNIC -j ACCEPT
fi

sleep 5
ip link set up dev $BRIDGE
sysctl net.ipv4.ip_forward=1
