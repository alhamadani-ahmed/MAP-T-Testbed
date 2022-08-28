#!/bin/bash

#Cleaning up namespaces and interfaces upon exit
function cleanup {
 trap - EXIT SIGINT SIGTERM
 echo "cleaning up namespaces and interfaces"
 ip netns exec napt ip addr flush dev eth0
 ip netns exec napt ip link delete to_global
 ip -6 addr flush dev eth1
 ip netns exec napt ip link set eth0 netns 1
 ip link set eth1 netns 1
 ip netns del napt
 exit 0
}

trap cleanup EXIT SIGINT SIGTERM
sh -c "echo -n 0000:02:01.0 > \ /sys/bus/pci/drivers/pcnet32/bind" 2>/dev/null 
sh -c "echo -n 0000:02:04.0 > \ /sys/bus/pci/drivers/pcnet32/bind" 2>/dev/null

# Create a new namespace and enable loopback on it
ip netns add napt
ip netns exec napt ip link set dev lo up

# Connect the two namespaces through veth pair #interfaces
ip link add to_napt type veth peer name \
to_global netns napt

#Send the physical eth0 interface to the new namespace
ip link set eth0 netns napt

# Assign addresses to each interface
ip address add 2001:db8:6::41/64 dev eth1
ip address add 10.0.0.1/24 dev to_napt
ip netns exec napt ip address add 10.0.0.2/24 \ 
dev to_global
ip netns exec napt ip address add \ 
192.168.0.1/24 dev eth0

# Activate all interfaces
ip link set eth1 up
ip link set to_napt up
ip netns exec napt ip link set to_global up
ip netns exec napt ip link set eth0 up

# Add essential routes to both namespaces
ip netns exec napt ip route add default via 10.0.0.1
ip route add 64:ff9b::/96 via 2001:db8:6::1
ip route add 192.0.2.2/32 via 10.0.0.2

# Turn both namespaces into routers
ip netns exec napt sysctl -w \ net.ipv4.conf.all.forwarding=1
sysctl -w net.ipv4.conf.all.forwarding=1
sysctl -w net.ipv6.conf.all.forwarding=1

#NAPT function
ip netns exec napt iptables \
           -t nat -A POSTROUTING \
           -s 192.168.0.0/24 -o to_global -p tcp \
           -j SNAT --to-source 192.0.2.2:2048-4095
ip netns exec napt iptables \
           -t nat -A POSTROUTING \
           -s 192.168.0.0/24 -o to_global -p udp \
           -j SNAT --to-source 192.0.2.2:2048-4095
#JOOL CE
/sbin/modprobe jool_mapt
jool_mapt instance add "CE 41" --netfilter \
--dmr 64:ff9b::/96
jool_mapt -i "CE 41" global update \
end-user-ipv6-prefix 2001:db8:ce:41::/64
jool_mapt -i "CE 41" global \
update bmr 2001:db8:ce::/51 192.0.2.0/24 13 0
jool_mapt -i "CE 41" global update map-t-type CE

#Get into CE shell
/bin/bash --rcfile <(echo "PS1=\"CE 41> \"")
