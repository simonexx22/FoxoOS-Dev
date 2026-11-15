#!/bin/bash
# FoxoOS etap 2: usuniecie pozostalego pakietu systemd (po udanym bootcie).
# Najpierw symulacja, potem (po review) to samo z --apply:
#   sudo bash scripts/30-stage2-remove-systemd.sh
#   sudo bash scripts/30-stage2-remove-systemd.sh --apply
set -euo pipefail

REPO="/home/foxos/foxoos"
LOG="/var/log/foxoos-stage2.log"

if [ "$(id -u)" -ne 0 ]; then
	echo "BLAD: uruchom przez sudo/root." >&2; exit 1
fi
if [ "$(ps -p 1 -o comm=)" != "init" ]; then
	echo "BLAD: PID 1 to '$(ps -p 1 -o comm=)', a nie sysvinit. Przerywam." >&2
	exit 1
fi

exec > >(tee -a "$LOG") 2>&1
echo "=== $(date -Is) etap 2: usuniecie systemd ==="
ps -p 1 -o pid,comm,args
readlink -f /proc/1/exe
rc-status -a || true

echo "--- symulacja transakcji"
SIM="$(apt-get -s --allow-remove-essential --no-install-recommends \
	install openrc elogind libpam-elogind systemd-standalone-sysusers \
	systemd- systemd-sysv- 2>&1)"
echo "$SIM" | sed -n '/will be REMOVED/,/^[0-9]* upgraded/p'

if echo "$SIM" | grep -qE '^Remv (linux-image|grub-|apt|dpkg|libc6|network-manager|dbus |udev |libsystemd-shared)'; then
	echo "BLAD: symulacja usuwa pakiet krytyczny - przerywam."
	exit 1
fi

if [ "${1:-}" != "--apply" ]; then
	echo
	echo "To byla tylko symulacja. Po review uruchom ponownie z --apply."
	exit 0
fi

echo "--- transakcja: usuniecie systemd/systemd-sysv"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
	--allow-remove-essential --no-install-recommends \
	-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
	openrc elogind libpam-elogind systemd-standalone-sysusers \
	systemd- systemd-sysv-

echo "--- pin APT: zakaz powrotu systemd"
install -m 0644 "$REPO/system/etc/apt/preferences.d/99-foxoos-no-systemd" \
	/etc/apt/preferences.d/99-foxoos-no-systemd

echo "--- nsswitch: usuniecie wpisow systemd (libnss-systemd juz nie istnieje)"
if ! dpkg -s libnss-systemd >/dev/null 2>&1; then
	sed -i -E 's/^(passwd|group|shadow|gshadow):([[:space:]]+)files systemd[[:space:]]*$/\1:\2files/' \
		/etc/nsswitch.conf
fi
grep -E '^(passwd|group|shadow|gshadow|hosts):' /etc/nsswitch.conf

echo "--- initramfs"
update-initramfs -u -k all

echo "--- PAM (elogind)"
grep -rn 'pam_elogind' /etc/pam.d/ || echo "brak pam_elogind (opcjonalnie)"

echo "--- kontrola spojnosci"
dpkg --audit || true
apt-get check

echo "--- zainstalowane skladniki systemd (ma byc pusto dla managera)"
dpkg -l | awk '/^ii/ && $2 ~ /^systemd($|-sysv$|-timesyncd$)/ {print "  "$2, $3}'
echo "--- biblioteki/narzedzia systemd, ktore zostaja"
dpkg -l | awk '/^ii/ && $2 ~ /libsystemd|systemd-standalone|^udev$/ {print "  "$2, $3}'

echo "--- czy upgrade chce przywrocic systemd"
apt-get -s upgrade | tail -n 20
apt-cache policy systemd systemd-sysv | sed -n '1,12p'

echo
echo "=== $(date -Is) KONIEC etapu 2 ==="
echo "Zalecany test: sudo reboot, po powrocie: bash scripts/40-post-boot-check.sh"
