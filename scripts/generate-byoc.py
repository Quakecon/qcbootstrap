#!/bin/env python

import csv
import re
import sys

from jinja2 import Environment, FileSystemLoader
env = Environment(loader=FileSystemLoader('templates'))

NETMASK=27
NAME_FILTER=re.compile('[a-c][0-9]{1,2}-[0-9]{1,2}[ab]?')

class Table:
    def __init__(self, row, netmask=NETMASK):
        num_clients=2**(32-netmask)-4
        self.subnet = row['Internal Subnet']
        self.name = table_name_filter(row['Table'])
        self.netmask = bits_to_mask(netmask)
        self.router = incr_ip(self.subnet)
        self.range_first = incr_ip(self.router)
        self.range_last = incr_ip(self.range_first, num_clients)

    def __str__(self):
        return "{}: {}/{}\n\tRouter: {}\n\tRange: {}-{}".format(
            self.name,
            self.subnet, self.netmask,
            self.router, self.range_first, self.range_last)

def table_name_filter(name):
    match = NAME_FILTER.search(name.lower())
    if match:
        return match.group()
    return None

def bits_to_mask(mask):
    maskint = 0
    for i in range(mask):
        maskint |= (1 << (31 - i))
    return "{}.{}.{}.{}".format(
        maskint >> 24,
        (maskint >> 16) & 0xFF,
        (maskint >> 8) & 0xFF,
        maskint & 0xFF)

def incr_ip(ip_str, num=1):
    parts = ip_str.split('.')
    return '.'.join([
        *parts[:-1],
        str(int(parts[-1])+num)])

if __name__ == "__main__":
    TABLES = []
    CURRENT_TABLE = None
    if len(sys.argv) != 3:
        print("Usage: {} <dns|dhcp> <csv.file>".format(sys.argv[0]))
        sys.exit(1)
    with open(sys.argv[2]) as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            if row['Table'] and row['Table'] != 'UNUSED':
                # Start new table
                TABLES.append(Table(row))

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
