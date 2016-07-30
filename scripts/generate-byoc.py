#!/bin/env python

import csv
import os
import random
import re
import sys
import yaml

DNS_SERVERS = ["172.16.1.102","172.16.1.103","172.16.1.104"]
NAME_FILTER=re.compile('([a-z]*)[0-9]*-[0-9]*([a-z]?)')

random.seed(os.urandom(16))

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
        self.prefix, self.suffix = NAME_FILTER.match(
            self.name).groups()

    @property
    def sort_hash(self):
        return self.prefix + self.suffix

def reserve_network(network_list, network):
    """Removes network from list, if it's a subnet, split the super net
       and re-add remaining subnets
    """
    for target_net in network_list:
        if network == target_net:
            network_list.remove(target_net)
            break
        if network.prefixlen > target_net.prefixlen:
            target_subs = list(target_net.subnet(network.prefixlen))
            for sub in target_subs:
                target_net_hit = False
                if sub == network:
                    target_net_hit = True
                    target_subs.remove(sub)
                if target_net_hit:
                    network_list.remove(target_net)
                    network_list+=target_subs
                    break
    return sorted(network_list, key=lambda n: n.prefixlen)

def randomize_dns_string():
    random.shuffle(DNS_SERVERS)
    return ', '.join(DNS_SERVERS)
        
if __name__ == "__main__":
    TABLES = []
    TABLES_NEED_NETWORK=[]
    if len(sys.argv) != 3:
        print("Usage: {} <dns-fwd|dns-rev|dhcp> <config.yaml>".format(
            sys.argv[0]))
        sys.exit(1)
    configfile = open(sys.argv[2])
    config = yaml.load(configfile)
    configfile.close()

    # Build List of Available Networks
    target_subnets=[]
    if 'global' in config:
        if 'networks' in config['global']:
            for network in config['global']['networks']:
                target_subnets += IPNetwork(network).subnet(
                    config['global']['default_netmask'])
                
        if 'shape' in config['global']: 
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
                        if name in config['tables']:
                            table_config=config['tables'][name]
                            if 'netmask' in table_config:
                                netmask=table_config['netmask']
                            if 'network' in table_config:
                                network=IPNetwork(table_config['network'])
                                if network.prefixlen == 32 and netmask:
                                    network=IPNetwork(
                                        table_config[
                                            'network']+'/{}'.format(
                                                netmask))
                                target_subnets=reserve_network(
                                    target_subnets, network)
                                TABLES.append(Table(name, network))
                                continue
                        TABLES_NEED_NETWORK.append((name, netmask))
            TABLES_NEED_NETWORK=sorted(TABLES_NEED_NETWORK, key=lambda tup: tup[1])

    for table in TABLES_NEED_NETWORK:
        try:
            network=target_subnets.pop(0)
        except:
            print("Ran out of networks, bailing")
            sys.exit(3)
        assert network.prefixlen <= table[1], """
Table {} has a larger netmask than packing algorithm can handle.
""".format(table[0])
        if network.prefixlen == table[1]:
            TABLES.append(Table(table[0], network))
            continue
        networks = list(network.subnet(table[1]))
        TABLES.append(Table(table[0], networks[0]))
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
    print(template.render(tables=TABLES,
                          shuffle_dns=randomize_dns_string))
    #print("Unused networks: ", target_subnets)
