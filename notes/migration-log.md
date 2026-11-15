# FoxoOS — dziennik migracji (start: 2026-11-15)

## 0. Audyt VM (odczyt)

| Element | Wartość |
|---|---|
| System | Debian GNU/Linux 13.7 (trixie) |
| Kernel | 6.12.117+deb13-amd64 |
| Wirtualizacja | VirtualBox (innotek GmbH / product: VirtualBox) |
| Boot | BIOS/Legacy (brak /sys/firmware/efi), GRUB 2.12 do MBR |
| Dysk | /dev/sda1 48G ext4 /, /dev/sda5 2.6G swap; 38G wolne |
| PID 1 | systemd (`/sbin/init -> ../lib/systemd/systemd`) |
| User | foxos (uid 1000, grupa sudo); sudo wymaga hasła |
| Target | graphical.target, GDM3 + GNOME zainstalowane |
| Sieć | NetworkManager 1.52.1, enp0s3 DHCP 10.0.2.15, DNS 192.168.0.1 |
| APT | deb.debian.org trixie + trixie-security + trixie-updates |
| Init pakiety | systemd 257.13-1~deb13u1, systemd-sysv (Protected), sysvinit-utils 3.14-4 |

Terminal działa **wewnątrz faktycznej VM** (DMI VirtualBox, /dev/sda, moduły vboxguest/vboxsf),
nie w sandboxie agenta. Brakuje tylko hasła sudo.

## 1. Symulacja APT (bez zmian w systemie)

```
apt-get -s --allow-remove-essential --no-install-recommends \
  install sysvinit-core openrc systemd-sysv-
```

Nowe: sysvinit-core 3.14-4, openrc 0.56-1, initscripts 3.14-4, insserv,
libeinfo1, librc1t64, dbus-x11.

Usuwane (30): stos GNOME/GDM3 (gnome, gnome-core, gnome-shell, gdm3,
gnome-session*, gnome-software*, gnome-tweaks, gnome-control-center, colord),
packagekit*, polkitd, pkexec, libpam-systemd, malcontent*, modemmanager,
nm-connection-editor, rtkit, task-gnome-desktop, gnome-browser-connector.
Powód: gdm3/libpam-systemd/polkitd zależą od systemd-sysv/logind.

NIE usuwane: jądro, GRUB, apt/dpkg, network-manager, dbus, udev, libsystemd0.

## 2. Symulacja pełna (etap 2: usunięcie systemd)

```
apt-get -s --allow-remove-essential --no-install-recommends \
  install sysvinit-core openrc systemd- systemd-sysv-
```

Dodatkowo: usuwa systemd, systemd-timesyncd, libnss-systemd; instaluje
systemd-standalone-sysusers (zaspokaja udev) i elogind (logind dla sesji).
udev pozostaje.

## 3. Wykryte pułapki przed rebootem

1. **NetworkManager nie ma skryptu /etc/init.d** w Debian 13 → po przejściu
   na sysvinit nie wystartuje i VM wstanie bez sieci. Trzeba dodać lokalny
   skrypt OpenRC `/etc/init.d/network-manager` (need dbus, provide net).
2. Po usunięciu systemd-sysv znikają `/sbin/reboot`, `/sbin/poweroff`,
   `/sbin/telinit` (symlinki do systemctl). sysvinit-core daje tylko
   init/halt/shutdown/runlevel → trzeba odtworzyć symlinki do halt/init.
3. Plymouth jest zainstalowany i zależy od systemd; do text-login niepotrzebny
   (propozycja: usunąć przed rebootem).
4. GDM3/GNOME odpada (zależność od systemd-sysv); zgodne z „text login first”.
5. initramfs-tools nie wymaga systemd jako PID1; po zmianach: update-initramfs -u -k all.

## 4. Decyzje

- Etap 1: instalacja sysvinit-core + openrc, usunięcie systemd-sysv
  (--allow-remove-essential, tylko po snapshocie).
- Etap 2 (po udanym boot): usunięcie systemd, pin zakazujący powrotu.
- Sieć: pozostać przy NetworkManager + własny skrypt OpenRC (nie zmieniamy
  stosu sieciowego).
- Branding: dpkg-divert na /etc/os-release i /etc/issue, zachować
  /etc/debian_version oraz ID_LIKE=debian.

## 5. Testy

(będą dopisywane po każdym etapie)
