# FoxoOS

Dystrybucja oparta na Debian GNU/Linux 13 (Trixie), z **sysvinit-core jako PID 1**
i **OpenRC** do usług. Repozytoria i pakiety pozostają oficjalnie Debiana
(bez Devuan). Jest też minimalny **live ISO** budowany przez live-build.

## Stan prac

- [x] Audyt VM i warstwy terminala (realna VM VirtualBox, nie sandbox)
- [x] Symulacja etapu 1 i etapu 2 (bez zmian w systemie)
- [x] Snapshot VirtualBox (po stronie użytkownika)
- [x] Etap 1: sysvinit-core + openrc, usunięcie systemd-sysv, reboot
- [x] Weryfikacja: PID 1, rc-status, login, sieć, DNS
- [x] Etap 2: usunięcie pakietu systemd + pin APT
- [x] LXQt + lightdm + elogind (zamiast GNOME/GDM)
- [x] Branding FoxoOS (os-release, issue, motd, GRUB)
- [ ] ISO live-build + test bootu w osobnej VM
- [ ] KDE Plasma (później; wybrano LXQt)

## FoxoOS na tej VM

- PID 1: `sysvinit-core` (`/usr/sbin/init`)
- Usługi: OpenRC (`rc-status`, `rc-service`, `rc-update`)
- Sieć: NetworkManager + DHCP + DNS
- Pulpit: LXQt, logowanie przez lightdm (elogind zamiast systemd-logind)
- Brak menedżera systemd: `systemctl` nie istnieje
- Dozwolone biblioteki/narzędzia: `libsystemd0`, `libsystemd-shared`, `udev`,
  `systemd-standalone-sysusers`, `systemd-standalone-tmpfiles`
- Pin APT: `/etc/apt/preferences.d/99-foxoos-no-systemd` blokuje powrót
  `systemd`, `systemd-sysv`, `systemd-timesyncd`, `libpam-systemd`,
  `libnss-systemd`

### Branding

`/etc/os-release` ma `NAME="FoxoOS"`, `PRETTY_NAME="FoxoOS 1.0 (Debian 13 trixie base)"`,
`FOXOS_VERSION="1.0"` i celowo `ID=debian` oraz `ID_LIKE=debian` — dzięki temu
narzędzia Debiana nadal rozpoznają bazę. Dodatkowo:

- `/etc/issue`, `/etc/issue.net`, `/etc/motd` — powitanie konsoli
- `/etc/lsb-release` — identyfikacja FoxoOS
- `/etc/debian_version` — nietknięte (kompatybilność)
- GRUB: `GRUB_DISTRIBUTOR="FoxoOS 1.0 GNU/Linux"`
- pliki Debiana są odsunięte przez `dpkg-divert` (`*.debian`), więc aktualizacja
  `base-files` nie skasuje brandingu

## ISO live-build

Minimalny obraz tekstowy (bez X11): sysvinit-core + OpenRC, NetworkManager,
rsyslog, text login. Nie zawiera `systemd`/`systemd-sysv`.

### Wymagania (host budujący)

    apt-get install live-build xorriso squashfs-tools mtools dosfstools rsync

Do testu QEMU dodatkowo:

    apt-get install qemu-system-x86 expect

### Budowanie

    cd /home/foxos/foxoos
    make build

Wynik:

    foxoos-1.0-amd64.iso
    foxoos-1.0-amd64.iso.sha256
    foxoos-1.0-amd64.packages        # manifest pakietów (jeśli live-build go zapisał)

`make reconfigure` odtwarza konfigurację po zmianie `auto/config`.
`make distclean` usuwa artefakty — **użyj go po każdej przerwanej budowie**
(szczegóły w `docs/BUILD.md`).

### Logowanie w live ISO

    login: foxos
    hasło: live
    sudo:  bez hasła (NOPASSWD)

To obraz demonstracyjny. Nie używaj tego hasła na komputerze z danymi.

### Test bootu

Automatyczny test przez konsolę szeregową (QEMU TCG, bez KVM):

    make test

Ręcznie w VirtualBox:

1. Nowa VM „FoxoOS-test”, typ Linux/Debian 64-bit, 2048 MB RAM, 2 CPU.
2. Napęd optyczny: `foxoos-1.0-amd64.iso`; boot z CD/DVD (BIOS).
3. W menu GRUB wybierz „Live system (amd64)”.
4. Zaloguj się `foxos` / `live`.
5. Sprawdź:

       cat /proc/1/comm          # init
       rc-status default         # NetworkManager, dbus, rsyslog...
       ip -br a                  # adres DHCP
       getent hosts deb.debian.org
       ping -c1 1.1.1.1
       dpkg -l | grep -E '^ii +(systemd|systemd-sysv) ' || echo brak systemd

6. `sudo poweroff` — QEMU/VirtualBox powinien się wyłączyć bez błędu.

### Reproducibility

`auto/config` ustawia `SOURCE_DATE_EPOCH` (stały timestamp metadanych ISO).
Identyczne wejścia + identyczny stan mirrora Debiana dają identyczny obraz.
Pakiety nie są pinowane do wersji, więc po aktualizacji mirrora manifest i
suma SHA-256 mogą się zmienić — to normalne dla obrazu zbudowanego z `trixie`.

## Struktura

    notes/migration-log.md       dziennik: audyt, symulacje, decyzje, wyniki
    notes/rollback.md            jak cofnąć zmiany
    packages/README.md           wybrane pakiety, wyjątki (libsystemd0, udev...)
    services/README.md           mapowanie runleveli, usługi krytyczne
    system/                      pliki wdrażane na FoxoOS (branding, pin, init.d)
    scripts/10-stage1-init-swap.sh       transakcja init (wymaga snapshotu)
    scripts/20-preflight.sh              kontrole przed rebootem
    scripts/30-stage2-remove-systemd.sh  symulacja/--apply usunięcia systemd
    scripts/40-post-boot-check.sh        raport po reboocie
    scripts/50-apply-branding.sh         branding systemu
    scripts/90-net-fallback.sh           awaryjne przywrócenie sieci (VBox NAT)
    scripts/qemu-login.expect            test konsoli live ISO
    scripts/test-qemu.sh                 wrapper testu QEMU
    auto/config                  pełna konfiguracja live-build
    config/package-lists/        listy pakietów live ISO
    config/includes.chroot/      pliki brandingu/konfiguracji w ISO
    config/hooks/normal/         hooki: branding, użytkownik, usługi,
                                 czyszczenie, weryfikacja, menu GRUB
    config/bootloaders/grub-pc/  motyw i splash GRUB

## Zasady

- Zero repozytoriów Devuan; tylko deb.debian.org + security.
- Nie usuwamy jądra, GRUB-a, apt/dpkg, NetworkManagera, dbus, udev.
- `libsystemd0`, `libsystemd-shared`, `udev`, `systemd-standalone-*`
  zostają (uzasadnienie w `packages/README.md`).
- `--allow-remove-essential` tylko dla reviewed wymiany init, po snapshocie.
- Snapshot przed każdą nieodwracalną zmianą; wyniki testów w `notes/`.
