#!/bin/env python

import csv
import re
import sys
import yaml

from netaddr import IPNetwork

from jinja2 import Environment, FileSystemLoader
env = Environment(loader=FileSystemLoader('templates'))

class Table:
    def __init__(self, name, network):
        self.subnet = str(network[0])
        self.name = name
        self.netmask = network.netmask
        self.router = network[1]
        self.range_first = network[2]
        self.range_last = network[-2]

if __name__ == "__main__":
    TABLES = []
    if len(sys.argv) != 3:
        print("Usage: {} <dns-fwd|dns-rev|dhcp> <config.yaml>".format(
            sys.argv[0]))
        sys.exit(1)
    configfile = open(sys.argv[2])
    config = yaml.load(configfile)
    configfile.close()

    for column, ranges in config['global']['shape'].items():
        parts = column.split('_')
        prefix = parts[0]
        suffix = parts[1] if len(parts) > 1 else ''
        for r in ranges:
            for i in range(*r):
                numeric = '-'.join(
                    [str(j) for j in range(i, i+r[2])])
                name = prefix + numeric + suffix
                netmask=config['global']['default_netmask']
                if (name in config['tables'] and
                    'netmask' in config['tables'][name]):
                    netmask=config['tables'][name]['netmask']
                TABLES.append((name, netmask))
    TABLES=sorted(TABLES, key=lambda tup: tup[1])

    target_subnets=[]
    for network in config['global']['networks']:
        target_subnets += IPNetwork(network).subnet(
            config['global']['default_netmask'])
    for i in range(len(TABLES)):
        table = TABLES[i]
        network=target_subnets.pop(0)
        assert network.prefixlen <= table[1], """
Table {} has a larger netmask than packing algorithm can handle.
 Try increasing default_subnet.""".format(table[0])
        if network.prefixlen == table[1]:
            TABLES[i] = Table(table[0], network)
            continue
        networks = list(network.subnet(table[1]))
        TABLES[i] = Table(table[0], networks[0])
        target_subnets = networks[1:] + target_subnets

    if sys.argv[1] == "dns-fwd":
        template = env.get_template('db.at.quakecon.org.template')
    elif sys.argv[1] == "dns-rev":
        template = env.get_template('db.19.172.in-addr.arpa.template')
    elif sys.argv[1] == "dhcp":
        template = env.get_template("dhcpd.byoc.template")
                
    else:
        print("Unknown command: {}".format(sys.argv[1]))
        sys.exit(2)
    print(template.render(tables=TABLES))
