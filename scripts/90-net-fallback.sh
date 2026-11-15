#!/bin/bash
# FoxoOS: AWARYJNE przywrocenie sieci, gdyby NetworkManager nie wystartowal.
# Dotyczy tej VM (VirtualBox NAT): enp0s3, 10.0.2.15/24, gw 10.0.2.2, DNS 10.0.2.3.
# Uruchom jako root, tylko gdy `ip -br a` pokazuje enp0s3 bez adresu.
set -euo pipefail

ip link set enp0s3 up
ip addr add 10.0.2.15/24 dev enp0s3 2>/dev/null || true
ip route add default via 10.0.2.2 2>/dev/null || true
printf 'nameserver 10.0.2.3\n' > /etc/resolv.conf

ip -br a show enp0s3
ip r
getent hosts deb.debian.org
