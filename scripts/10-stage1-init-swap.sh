#!/bin/bash
# FoxoOS etap 1: wymiana systemd-sysv -> sysvinit-core + OpenRC.
# Uruchom jako root PO zrobieniu snapshotu:
#   sudo bash scripts/10-stage1-init-swap.sh --snapshot-ok
set -euo pipefail

REPO="/home/foxos/foxoos"
LOG="/var/log/foxoos-stage1.log"

if [ "$(id -u)" -ne 0 ]; then
	echo "BLAD: uruchom przez sudo/root." >&2
	exit 1
fi
if [ "${1:-}" != "--snapshot-ok" ]; then
	echo "BLAD: brak potwierdzenia snapshotu." >&2
	echo "Uzycie: $0 --snapshot-ok" >&2
	exit 1
fi
[ -x "$REPO/system/etc/init.d/network-manager" ] || {
	echo "BLAD: brak repo w $REPO" >&2; exit 1; }

exec > >(tee -a "$LOG") 2>&1
echo "=== $(date -Is) START etapu 1 ==="

echo "--- PID 1 przed: $(ps -p 1 -o comm=)"
[ "$(ps -p 1 -o comm=)" = "systemd" ] || {
	echo "BLAD: PID 1 nie jest systemd - przerywam."; exit 1; }

. /etc/os-release
echo "--- system: $PRETTY_NAME (codename=${VERSION_CODENAME:-?})"
[ "${VERSION_CODENAME:-}" = "trixie" ] || {
	echo "BLAD: to nie Debian 13 trixie - przerywam."; exit 1; }

echo "--- [1/7] kontrola symulacji APT"
SIM="$(apt-get -s --allow-remove-essential --no-install-recommends \
	install sysvinit-core openrc systemd-sysv- 2>&1)"
echo "$SIM" | sed -n '/will be REMOVED/,/^[0-9]* upgraded/p'
if echo "$SIM" | grep -qE '^Remv (linux-image|grub-|apt|dpkg|libc6|network-manager|dbus |udev |libsystemd-shared)'; then
	echo "BLAD: symulacja usuwa pakiet krytyczny - przerywam."
	exit 1
fi
echo "$SIM" | grep -q '^Remv systemd-sysv' || {
	echo "BLAD: systemd-sysv nie jest w liście usuwanych - przerywam."; exit 1; }

echo "--- [2/7] usuwanie plymouth (niepotrzebny przy text login)"
DEBIAN_FRONTEND=noninteractive apt-get purge -y \
	-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
	plymouth plymouth-label libplymouth5

echo "--- [3/7] transakcja glowna: sysvinit-core + openrc, -systemd-sysv"
DEBIAN_FRONTEND=noninteractive apt-get install -y \
	--allow-remove-essential --no-install-recommends \
	-o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
	sysvinit-core openrc systemd-sysv-

echo "--- [4/7] usluga OpenRC dla NetworkManager"
install -m 0755 "$REPO/system/etc/init.d/network-manager" /etc/init.d/network-manager
rc-update add network-manager default
rc-update add dbus default 2>/dev/null || true
rc-update add networking sysinit 2>/dev/null || true

echo "--- [5/7] symlinki reboot/poweroff/telinit"
install -m 0755 "$REPO/system/usr/local/sbin/foxoos-sysvinit-links" \
	/usr/local/sbin/foxoos-sysvinit-links
/usr/local/sbin/foxoos-sysvinit-links

echo "--- [6/7] PAM: usuniecie wpisow pam_systemd (modul juz nie istnieje)"
sed -i '/pam_systemd\.so/d' /etc/pam.d/common-session /etc/pam.d/runuser-l 2>/dev/null || true
if grep -rqs 'pam_systemd' /etc/pam.d/; then
	echo "UWAGA: pozostaly wpisy pam_systemd:"; grep -rn 'pam_systemd' /etc/pam.d/ || true
else
	echo "PAM bez pam_systemd: OK"
fi

echo "--- [7/7] initramfs"
update-initramfs -u -k all

echo
echo "=== KONTROLA PRZED REBOOT ==="
bash "$REPO/scripts/20-preflight.sh"

echo
echo "=== $(date -Is) KONIEC etapu 1 - gotowe do rebootu ==="
echo "Nie rebootuj automatycznie: najpierw przeczytaj kontrole powyzej."
