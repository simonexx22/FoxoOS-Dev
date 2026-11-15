#!/bin/bash
# FoxoOS: branding systemu (Uruchamiac po udanej migracji, jako root).
#   sudo bash scripts/50-apply-branding.sh
set -euo pipefail

REPO="/home/foxos/foxoos"
[ "$(id -u)" -eq 0 ] || { echo "BLAD: uruchom przez sudo." >&2; exit 1; }

echo "--- /etc/os-release (dpkg-divert, przezyje aktualizacje base-files)"
if ! dpkg-divert --list /etc/os-release | grep -q '/etc/os-release'; then
	dpkg-divert --local --rename --add /etc/os-release
fi
install -m 0644 "$REPO/system/etc/os-release" /etc/os-release

echo "--- /etc/issue (dpkg-divert)"
if ! dpkg-divert --list /etc/issue | grep -q '/etc/issue'; then
	dpkg-divert --local --rename --add /etc/issue
fi
install -m 0644 "$REPO/system/etc/issue" /etc/issue

echo "--- /etc/motd (plik niezarzadzany przez dpkg)"
install -m 0644 "$REPO/system/etc/motd" /etc/motd

echo "--- GRUB: dystrybutor FoxoOS"
install -m 0644 "$REPO/system/etc/default/grub.d/99-foxoos.cfg" \
	/etc/default/grub.d/99-foxoos.cfg
update-grub

echo "--- weryfikacja"
cat /etc/os-release
echo
head -3 /etc/issue
echo
grep -m1 -E 'menuentry|FoxoOS' /boot/grub/grub.cfg || true
echo
echo "Debian base zachowany: /etc/debian_version = $(cat /etc/debian_version)"
