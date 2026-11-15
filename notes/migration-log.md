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

## 5. Przygotowane pliki (przed transakcją)

- `system/etc/init.d/network-manager` — usługa OpenRC dla NM (supervise-daemon,
  need dbus, provide net, after networking).
- `system/usr/local/sbin/foxoos-sysvinit-links` — reboot/poweroff -> halt,
  telinit -> init.
- `system/etc/apt/preferences.d/99-foxoos-no-systemd` — pin -1 dla managera.
- `system/etc/{os-release,issue,motd}`, `system/etc/default/grub.d/99-foxoos.cfg`.
- `scripts/10..50`, `scripts/90-net-fallback.sh`, `notes/rollback.md`.
- Wszystkie skrypty przeszły `bash -n` / `sh -n`. Repo jest w gicie
  (commit 78edf2d).

## 6. Ustalenia o sesji i GDM

- Terminal agenta to GNOME Terminal w sesji **Wayland** (`XDG_SESSION_TYPE=wayland`),
  gnome-shell działa w `user@1000.service`, a gdm3 (PID 1582) jest w osobnym
  `gdm.service` (KillMode=mixed). Prerm gdm3 robi `invoke-rc.d gdm3 stop`,
  ale zatrzymuje tylko gdm3, nie sesję użytkownika.
- Po reboocie nie będzie GDM/GNOME — zostanie text login na tty1.
  Sesja agenta zginie przy reboocie; dalsza weryfikacja przez konsolę VM.
- Etap 1 uruchamiam przez `systemd-run` (własny cgroup), żeby transakcja
  dokończyła się nawet przy zamknięciu sesji graficznej.

## 7. Testy

(będą dopisywane po każdym etapie)

## 8. Wdrożenie po reboocie (2026-11-15)

- PID 1: `init [2]`, `/proc/1/exe` -> `/usr/sbin/init` (sysvinit-core).
- OpenRC wystartował sysinit/default; NetworkManager, dbus, rsyslog działają.
- LXQt + lightdm + elogind: sesja `foxos` aktywna, `loginctl` pokazuje seat0.
- Usunięto resztki: `systemd`, `systemd-timesyncd`, `libnss-systemd`
  (purge); zainstalowano `systemd-standalone-tmpfiles`.
- Pin APT rozszerzony o `libpam-systemd` i `libnss-systemd`.
- Branding: `/etc/os-release` (ID=debian, NAME=FoxoOS, FOXOS_VERSION=1.0),
  `/etc/issue`, `/etc/issue.net`, `/etc/motd`, `/etc/lsb-release`;
  dywersje `*.debian`; GRUB „FoxoOS 1.0 GNU/Linux”.
- `lsb_release`: Description FoxoOS 1.0, Release 13, Codename trixie.
- `dpkg -C` czyste; `apt-get -s upgrade` bez zmian.

## 9. ISO live-build (2026-11-15)

- Projekt: `/home/foxos/foxoos` (git). Konfiguracja w `auto/config`.
- Baza: debootstrap `--variant=minbase`, live-config-sysvinit.
- Pakiety: sysvinit-core, openrc, NetworkManager, dbus, rsyslog, sudo,
  live-boot/live-config, bez systemd.
- Hooki: branding, user foxos/live, rc-update, cleanup, verify.
- Test: QEMU TCG po serialu (`make test`); wynik dopisany niżej po budowie.

## 10. Wyniki budowy i testu ISO (2026-11-15)

- **Plik ISO**: `/home/foxos/foxoos/foxoos-1.0-amd64.iso`
- **Rozmiar**: 310 MB (324 976 640 B)
- **SHA-256**: `094b662c5678d8a42f620005bb989bd60889f7c1f46cb86d2b7cdc770b436908`
- **Manifest**: brak `systemd`, brak `systemd-sysv`, brak `systemd-timesyncd`, brak `libpam-systemd`, brak `libnss-systemd`. Zachowano: `libsystemd0`, `libsystemd-shared`, `udev`, `systemd-standalone-sysusers`, `systemd-standalone-tmpfiles`.
- **Wynik testu automatycznego QEMU (TCG serial)**:
  - PID 1 is init (`sysvinit-core` / `/usr/sbin/init`): PASS
  - os-release identifies FoxoOS (`PRETTY_NAME="FoxoOS 1.0 (Debian 13 trixie base)"`, `NAME="FoxoOS"`, `ID=debian`, `FOXOS_VERSION="1.0"`): PASS
  - no systemd/systemd-sysv manager packages: PASS (`NO_SYSTEMD_MANAGER`)
  - services started by OpenRC (`network-manager`, `dbus`, `rsyslogd` running): PASS
  - DHCP address from QEMU network (`10.0.2.15/24` on `ens3` via NetworkManager): PASS
  - DNS resolution (`deb.debian.org`): PASS
  - ICMP ping (`1.1.1.1`): PASS
  - Czyste zamknięcie systemu (`poweroff -f` -> `reboot: Power down`): PASS
  - Wszystkie 11 kontroli automatycznych: PASS (`tests/qemu-20261115-210331.log`).
