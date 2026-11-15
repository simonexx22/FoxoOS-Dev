#!/bin/bash
# FoxoOS: raport po reboocie. Uruchom jako root:
#   sudo bash /home/foxos/foxoos/scripts/40-post-boot-check.sh
# Wynik mozna skopiowac do czatu lub zapisac:
#   sudo bash ... | tee /root/foxoos-boot-report.txt
set -uo pipefail

echo "===== FoxoOS post-boot report $(date -Is) ====="
echo

echo "== PID 1 =="
ps -p 1 -o pid,comm,args
readlink -f /proc/1/exe
echo

echo "== rc-status -a =="
rc-status -a
echo

echo "== uslugi crashed/failed =="
rc-status --crashed 2>/dev/null || true
echo

echo "== getty / logowanie =="
ps -ef | grep -E '[a]getty|[g]etty' || echo "BRAK getty!"
who || true
echo

echo "== siec =="
ip -br a
ip r
echo "resolv.conf:"; cat /etc/resolv.conf
echo
getent hosts deb.debian.org || echo "BLAD: DNS nie dziala"
ping -c1 -W2 10.0.2.2 >/dev/null 2>&1 && echo "ping gw 10.0.2.2: OK" || echo "ping gw: FAIL"
ping -c1 -W2 1.1.1.1 >/dev/null 2>&1 && echo "ping 1.1.1.1: OK" || echo "ping 1.1.1.1: FAIL"
echo

echo "== NetworkManager =="
rc-service network-manager status || true
nmcli -t -f NAME,DEVICE,STATE,AUTOCONNECT con show 2>/dev/null || true
echo

echo "== polecenia wylaczenia =="
for c in reboot poweroff shutdown telinit halt; do
	printf '  %-10s ' "$c"; command -v "$c" || echo BRAK
done
ls -l /usr/sbin/reboot /usr/sbin/poweroff /usr/sbin/telinit 2>&1
echo

echo "== PAM / nsswitch =="
grep -rn 'pam_systemd' /etc/pam.d/ || echo "brak pam_systemd: OK"
grep -rn 'pam_elogind' /etc/pam.d/ || echo "brak pam_elogind"
grep -E '^(passwd|group|shadow|gshadow|hosts):' /etc/nsswitch.conf
echo

echo "== pakiety init =="
dpkg-query -W -f='${Package} ${Version} ${Status}\n' \
	systemd systemd-sysv systemd-timesyncd sysvinit-core openrc udev \
	libsystemd0 systemd-standalone-sysusers elogind 2>/dev/null \
	| sed 's/ install ok installed//'
echo

echo "== APT: czy upgrade przywroci systemd =="
apt-get -s upgrade 2>/dev/null | grep -E '^(Inst|Remv).*(systemd|sysvinit|openrc)' || echo "brak zmian w systemd/sysvinit/openrc"
echo

echo "===== koniec raportu ====="
