#!/bin/bash

#Cleaning up interfaces upon exit
Function cleanup{
trap -EXIT SIGINT SIGTERM
echo “cleaning up interfaces”
ip addr flush dev eth0
ip -6 addr flush dev eth1
exit 0
}

trap cleanup EXIT SIGINT SIGTERM
sh -c “echo -n 0000:02:01.0 > \ /sys/bus/pci/drivers/pcnet32/bind” 2>/dev/null

sh -c “echo -n 0000:02:02.0 > \ /sys/bus/pci/drivers/pcnet32/bind” 2>/dev/null

# Activate both interfaces and assign addresses for #each one of them

ip link set eth0 up
ip address add 203.0.113.1/24 dev eth0

ip link set eth1 up
ip address add 2001:db8:6::1/64 dev eth1

# Add essential routes
ip route add 2001:db8:ce:41::/64 via 2001:db8:6::41

# Turn on forwarding
sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -w net.ipv6.conf.all.forwarding=1

#JOOL BR
/sbin/modprobe jool_mapt
jool_mapt instance add "BR" –netfilter \
 --dmr 64:ff9b::/96
jool_mapt -i "BR" fmrt add \
2001:db8:ce::/51 192.0.2.0/24 13 0
jool_mapt -i "BR" global update map-t-type BR

# Get into BR shell
/bin/bash –rcfile <(echo “PS1=\”BR> \””)
