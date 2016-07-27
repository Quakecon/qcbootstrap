#!/bin/env python

import csv
import re
import requests
import sys
import yaml

from io import StringIO

from netaddr import IPAddress

NAME_FILTER=re.compile('[a-c][0-9]{1,2}-[0-9]{1,2}[ab]?')

if __name__ == "__main__":
    TABLES = {}
    if len(sys.argv) != 2:
        print("Usage: {} '<shared-link-to-csv-download>'".format(sys.argv[0]))
        sys.exit(1)
    r = requests.get(sys.argv[1])
    reader = csv.DictReader(StringIO(r.text))
    for row in reader:
        if (row['Description'].startswith('Table:') and
                    row['Global Address'].strip() != ''):
            match = NAME_FILTER.search(row['Description'].lower())
            if match:
                if match.group() in TABLES:
                    print("Duplicate Table: {}".format(
                        row['Description']))
                    sys.exit(4)
                TABLES[match.group()] = (row['Global Address'] +
                                                 row['Mask'], row['Subnet'])
            else:
                print("Ambiguous table name: {}".format(
                    row['Description']))
                sys.exit(2)
    shape = {}
    shape_tmp = []
    for name in TABLES.keys():
        col, table_start, table_end, suffix = re.match('([a-z]*)([0-9]*)-([0-9]*)([a-z]?)',
                             name).groups()
        group = '_'.join([col, suffix]) if suffix != '' else col
        tables = int(table_end) - int(table_start) + 1
        shape_tmp.append((group, int(table_start), int(table_end),
                              tables))
    shape_tmp = sorted(shape_tmp, key=lambda n: n[1])
    for entry in shape_tmp:
        group, start, end, num = entry
        if not group in shape:
            shape[group] = [[start, end, num]]
            continue
        else:
            if (num == shape[group][-1][2] and
                    shape[group][-1][1] == int(start) - 1):
                shape[group][-1][1] = end
            else:
                shape[group].append([start, end, num])
    print(
        yaml.dump(
            {'global': {'shape': shape,
                        'networks': ['12.97.0.0/20'],
                        'default_netmask': 27},
             'tables': {
                 table: {
                     'network': network,
                     'mgt': str(IPAddress(local)+2)} for table, (network, local) in TABLES.items()}
        }))
