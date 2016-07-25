# Quakecon Bootstrap

## Requirements

To create services VMs:
 - virt-builder
 - ssh-keygen
 - dd
 
To generate BYOC DHCP & DNS configuration:
 - Python 2.7 or 3.2+
 - jinja2
 
## Generating Services VMs

~~~ bash
git clone --recursive https://github.com/quakecon/qcbootstrap.git
cd qcbootstrap
./makecon.sh
~~~

## Generating BYOC DNS & DHCP

Download BYOC Sheet from Google Docs as CSV (hereafter called
`byoc.csv`).

Automatically install prerequisites:
~~~ bash
cd qcbootstrap
virtualenv .env
. .env/bin/activate
pip install -r requirements.txt
~~~

~~~ bash
scripts/generate-byoc.py dns-fwd byoc.csv > db.byoc
scripts/generate-byoc.py dns-rev byoc.csv > db.19.172.in-addr.arpa.
scripts/generate-byoc.py dhcp byoc.csv > dhcpd.byoc.conf
~~~


   
