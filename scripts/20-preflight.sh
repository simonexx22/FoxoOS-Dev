#!/bin/bash
# FoxoOS: kontrole przed rebootem po etapie 1. Tylko czyta system.
set -uo pipefail

echo "== 1. PID 1 / plik init =="
ps -p 1 -o pid,comm,args
ls -l /usr/sbin/init
file /usr/sbin/init
dpkg -S /usr/sbin/init || true
echo

echo "== 2. /etc/inittab (getty + runlevel) =="
grep -E 'initdefault|sysinit|respawn:/sbin/getty' /etc/inittab || echo "BRAK /etc/inittab!"
echo

echo "== 3. runlevels OpenRC =="
for r in sysinit boot default shutdown off; do
	printf '[%s] ' "$r"
	ls "/etc/runlevels/$r" 2>/dev/null | tr '\n' ' '
	echo
done
echo

echo "== 4. krytyczne uslugi w runlevelach =="
for s in mountkernfs.sh hostname.sh checkroot.sh checkfs.sh mountall.sh \
	bootmisc.sh udev dbus networking network-manager; do
	found="$(find /etc/runlevels -maxdepth 2 -name "$s" -printf '%h\n' 2>/dev/null \
		| xargs -r -n1 basename | sort -u | tr '\n' ',')"
	printf '  %-20s -> %s\n' "$s" "${found:-BRAK}"
done
echo

echo "== 5. rc-update show =="
rc-update show
echo

echo "== 6. skladnia uslugi NM =="
sh -n /etc/init.d/network-manager && echo "sh -n: OK"
echo

echo "== 7. siec i DNS (dziala jeszcze pod systemd) =="
ip -br a
ip r
cat /etc/resolv.conf
getent hosts deb.debian.org || echo "UWAGA: DNS nie odpowiada"
echo

echo "== 8. PAM =="
grep -rn 'pam_systemd' /etc/pam.d/ || echo "brak pam_systemd: OK"
echo

echo "== 9. pakiety init (stan) =="
dpkg-query -W -f='${Package} ${Version} ${Status}\n' \
	systemd systemd-sysv sysvinit-core openrc udev libsystemd0 2>/dev/null \
	| sed 's/ install ok installed//'
echo

echo "== 10. pozostale skladniki systemd =="
dpkg -l | awk '/^ii/ && $2 ~ /systemd|logind/ {print "  "$2, $3}'
echo

echo "== 11. polecenia reboot/shutdown =="
ls -l /usr/sbin/shutdown /usr/sbin/reboot /usr/sbin/poweroff /usr/sbin/telinit 2>&1
