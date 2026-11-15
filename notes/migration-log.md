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

## 11. Naprawa bootowania Live ISO, UEFI i pełny branding (2026-11-15)

- **Diagnoza błędu rozruchu („No root device specified. Boot arguments must include a root= parameter”)**:
  - W dystrybucjach live opartych na `live-boot` skrypt `/init` z initramfs ładuje `/scripts/live` wyłącznie wtedy, gdy parametr `boot=live` zostanie przekazany w linii poleceń jądra.
  - W przeciwnym razie initramfs przyjmuje `BOOT=local` i przekazuje kontrolę do `/scripts/local`. Przy braku parametru `root=` skrypt ten wywołuje `panic` i zrzuca sesję do BusyBoxa.
  - **Rozwiązanie w projekcie live-build**:
    - W `auto/config` jawnie skonfigurowano `--bootappend-live` z parametrem `boot=live components quiet ...`.
    - W `iso_root/boot/grub/grub.cfg` wpisy menu `menuentry` (domyślny, fail-safe oraz weryfikacja) bezwzględnie przekazują `boot=live components`.
    - Dodano obsługę UEFI obok BIOS: `grub-efi-amd64-bin`, `grub-efi-ia32-bin`, wygenerowano obraz FAT `boot/grub/efi.img` oraz hybrydowe nagłówki El Torito w `xorriso`.
- **Wdrożenie logo i tapety użytkownika**:
  - Plik tapety `/home/foxos/Downloads/wallpapermain.png` (1920x1080) wdrożony do:
    - Host VM (aktywny pulpit LXQt użytkownika `foxos` przez `pcmanfm-qt -w`)
    - Live ISO: `/usr/share/wallpapers/foxoos/wallpapermain.png`
    - Domyślna konfiguracja PCManFM-Qt: `/etc/xdg/pcmanfm-qt/lxqt/settings.conf` i `/etc/skel/.config/pcmanfm-qt/lxqt/settings.conf`
    - Ekran logowania LightDM: `/etc/lightdm/lightdm-gtk-greeter.conf`
    - Alternatywa Debiana `desktop-background` (`update-alternatives`)
  - Plik logo `/home/foxos/Downloads/logosystemu.png` (500x500 RGBA) wdrożony do:
    - Host VM: awatar sesji `~/.face` i `~/.face.icon`, ikona menu `~/.local/share/icons/`
    - Live ISO: `/usr/share/icons/foxoos/logosystemu.png`, `/usr/share/icons/hicolor/512x512/places/start-here-lxqt.png`, `/etc/skel/.face`
    - Ekran logowania LightDM (`default-user-image`)
    - Tło startowe menu GRUB: `config/bootloaders/grub-pc/splash.png` (kompozycja tapety 800x600 i logo 140x140 wygenerowana przy użyciu GdkPixbuf/Cairo)
- **Identyfikacja systemu**:
  - `/etc/os-release`: `NAME="FoxoOS"`, `PRETTY_NAME="FoxoOS"`, z zachowaniem `ID=debian`, `VERSION_CODENAME=trixie`, `VERSION_ID="13"`.
- **Nowy obraz ISO**:
  - **Ścieżka**: `/home/foxos/foxoos/foxoos-1.0-amd64.iso`
  - **Rozmiar**: 324 MB (339 052 544 B)
  - **SHA-256**: `6495abb3f593328a39481cd97dbd27353ae720cbb1b63d587f6658711c707d0e`
  - **El Torito**: MBR BIOS grub2-mbr + UEFI El Torito alt-boot (`/boot/grub/efi.img`)
- **Wynik testu automatycznego QEMU TCG (`tests/qemu-20261115-215020.log`)**:
  - PID 1 is init (`sysvinit-core`): PASS
  - `/proc/1/exe` is `/usr/sbin/init`: PASS
  - os-release identifies FoxoOS (`PRETTY_NAME="FoxoOS"`, `NAME="FoxoOS"`): PASS
  - os-release keeps Debian base ID (`ID=debian`): PASS
  - `FOXOS_VERSION="1.0"` present: PASS
  - Brak menedżera systemd (`NO_SYSTEMD_MANAGER`): PASS
  - Usługi OpenRC działają (`network-manager`, `dbus`, `rsyslogd` running): PASS
  - Adres sieciowy DHCP (`10.0.2.15/24` na `ens3`): PASS
  - Rezolucja DNS (`deb.debian.org` -> `2a04:4e42:41::644`): PASS
  - Ping ICMP (`1.1.1.1`): PASS (0% packet loss)
  - Czyste wyłączenie zasilania (`poweroff -f` -> `reboot: Power down`): PASS
  - Wszystkie 11 asercji testowych: PASS


## 12. Wdrożenie instalatora graficznego GUI (Calamares) (2026-11-15)

- **Cel**: Dodanie graficznego instalatora GUI (Calamares) do obrazu Live ISO FoxoOS oraz środowiska roboczego.
- **Wybór komponentu i zgodność z architekturą FoxoOS**:
  - Wybrano **Calamares 3.3.14-1** oraz pakiet konfiguracji bazowej **calamares-settings-debian 13.0.13-1** z repozytorium Debian 13 (trixie) main.
  - Zweryfikowano zależności: Calamares i pakiety towarzyszące (Qt6, KF6, libkpmcore12, cryptsetup, polkitd) **w 100% nie wymagają systemd ani systemd-sysv** i nie naruszają pinu APT.
  - Wykorzystano wbudowany w Calamares moduł `services-openrc`, który zarządza usługami w instalowanym systemie za pomocą polecenia `rc-update` (zamiast modułu `services-systemd`).
- **Wdrożona konfiguracja i moduły Calamares (`/etc/calamares/`)**:
  - `settings.conf`:
    - Ścieżka wyszukiwania modułów: `[ local, /usr/lib/calamares/modules, /usr/lib/x86_64-linux-gnu/calamares/modules ]`.
    - Podmiana modułu usług: zastąpiono `services-systemd` modułem `services-openrc`.
    - Branding: `foxoos`.
  - `modules/services-openrc.conf`:
    - `initdDir: "/etc/init.d"`, `runlevelsDir: "/etc/runlevels"`.
    - Automatyczna rejestracja usług: `udev` (sysinit), `dbus`, `network-manager`, `rsyslog`, `elogind`, `lightdm` (default).
  - `modules/finished.conf`:
    - Komenda ponownego uruchomienia zmieniona na `shutdown -r now` (zastąpiono `systemctl -i reboot`).
  - `modules/bootloader.conf`:
    - Skonfigurowano instalator bootloadera pod GRUB 2 BIOS i UEFI z wpisem rozruchowym `FoxoOS`.
  - `modules/packages.conf`:
    - Zapewniono usunięcie pakietów środowiska live (`live-boot`, `live-config`, `live-config-sysvinit`, `live-tools`, `calamares`) po zakończeniu instalacji na dysku.
  - `modules/welcome.conf`, `modules/machineid.conf`, `modules/fstab.conf`, `modules/unpackfs.conf`, `modules/users.conf`.
- **Dedykowany branding FoxoOS dla Calamares (`branding/foxoos/`)**:
  - `branding.desc`: pełna identyfikacja FoxoOS 1.0, wersja, odnośniki wsparcia, ciemny motyw spójny z tapetą systemową.
  - `foxoos-logo.png`: logo FoxoOS w formacie RGBA (256x256) wygenerowane z pliku użytkownika `logosystemu.png`.
  - `welcome.png`: ekran powitalny (457x300) z motywem tapety `wallpapermain.png` i zintegrowanym logo.
  - `slide1.png`: slajd prezentacji (800x480) z kompozycją tapety i logo.
  - `show.qml`: prezentacja slajdów w QML z polskim komunikatem powitalnym.
- **Integracja ze środowiskiem graficznym i skróty pulpitu**:
  - Utworzono wrapper launchera: `/usr/bin/calamares-install-foxoos` (wsparcie `xhost`, `pkexec` i `sudo`).
  - Skrót aplikacji: `/usr/share/applications/install-foxoos.desktop` (ikona `install-foxoos.png`).
  - Skrót na pulpicie Live użytkownika oraz w `/etc/skel/Desktop/install-foxoos.desktop`: `Zainstaluj FoxoOS`.
  - Reguła PolicyKit: `/etc/polkit-1/rules.d/49-calamares.rules` zezwalająca na uruchomienie instalatora bez hasła w trybie Live.
  - Skrót dodany bezpośrednio na bieżący pulpit użytkownika VM: `/home/foxos/Desktop/install-foxoos.desktop`.
- **Nowy obraz ISO i weryfikacja automatyczna**:
  - **Plik ISO**: `/home/foxos/foxoos/foxoos-1.0-amd64.iso`
  - **Rozmiar**: 367 MB (383 801 344 B)
  - **SHA-256**: `2d2cfc94754b9e22f48d5a6483dc8f8313b7a68c2929048f8b46b1f600eb6eea`
  - **Wynik testu automatycznego QEMU TCG (`tests/qemu-20261115-221949.log`)**:
    - PID 1 is init (`sysvinit-core`): PASS
    - `/proc/1/exe` is `/usr/sbin/init`: PASS
    - os-release identifies FoxoOS (`PRETTY_NAME="FoxoOS"`, `NAME="FoxoOS"`): PASS
    - os-release keeps Debian base ID (`ID=debian`): PASS
    - `FOXOS_VERSION="1.0"` present: PASS
    - Brak menedżera systemd (`NO_SYSTEMD_MANAGER`): PASS
    - Usługi OpenRC działają (`network-manager`, `dbus`, `rsyslogd` running): PASS
    - Adres sieciowy DHCP (`10.0.2.15/24` na `ens3`): PASS
    - Rezolucja DNS (`deb.debian.org` -> `2a04:4e42:41::644`): PASS
    - Ping ICMP (`1.1.1.1`): PASS (0% packet loss)
    - Binarka Calamares obecna i wykonywalna (`CALAMARES_BIN_OK`): PASS
    - Konfiguracja Calamares obecna (`CALAMARES_CONF_OK`): PASS
    - Branding FoxoOS dla Calamares obecny (`CALAMARES_BRANDING_OK`): PASS
    - Skrót pulpitu instalatora obecny (`CALAMARES_DESKTOP_OK`): PASS
    - Czyste wyłączenie zasilania (`poweroff -f` -> `reboot: Power down`): PASS
    - Wszystkie 15 asercji testowych: PASS

## 13. Rozwiązanie problemu bootclean find -delete oraz wdrożenie pełnego środowiska graficznego LXQt i autologinu LightDM (2026-11-15 23:05)

### 1. Diagnoza błędu rozruchu `find: cannot delete './live/rootfs/filesystem.squashfs/...': Read-only file system`
- **Identyfikacja skryptu**: `/usr/lib/init/bootclean.sh` (oraz `/lib/init/bootclean.sh` z pakietu Debian `initscripts`).
- **Katalog wyjściowy czyszczenia**: `$dir = /run` (funkcja `clean /run (...)` wywoływana z `clean_all()`).
- **Przyczyna**:
  W trybie Live (`live-boot`) obraz SquashFS oraz nośnik instalacyjny montowane są w poddrzewie `/run/live/` (w tym montowanie tylko-do-odczytu `/run/live/rootfs/filesystem.squashfs`).
  W Debianie standardowa funkcja `clean /run` wykonywała polecenie `cd "$dir" && find . $findopts -delete`. Ponieważ nie zawierała flagi `-xdev` ani wykluczenia podkatalogów `./live*`, `find` rekursywnie przeszukiwał całe zamontowane drzewo SquashFS i próbował skasować pliki na systemie plików tylko do odczytu, co generowało tysiące błędów na konsoli `tty1`.
- **Wdrożona poprawka**:
  W funkcji `clean()` w pliku `bootclean.sh` zmodyfikowano wywołanie:
  `find . -xdev ! -path './live*' ! -path './rootfs*' $findopts -delete \`
  - `-xdev`: zatrzymuje `find` przed przekraczaniem granic innych systemów plików (innych punktów montowania).
  - `! -path './live*' ! -path './rootfs*'`: jawnie ignoruje strukturę montowania `live-boot`.
  - Zachowano pełne standardowe czyszczenie pozostałych plików tymczasowych w `/run`, `/run/lock` i `/run/shm`.
  - SquashFS pozostaje bezpiecznie w trybie `ro`, a parametr `boot=live` jest zachowany.
- **Trwałość przed aktualizacjami APT**:
  Poprawka została umieszczona w projekcie w `config/includes.chroot/usr/lib/init/bootclean.sh` oraz w `system/usr/lib/init/bootclean.sh`, a w hooku `config/hooks/normal/0100-foxoos-branding.hook.chroot` zarejestrowano dywersję pakietową:
  `dpkg-divert --local --no-rename --add --divert /usr/lib/init/bootclean.sh.debian /usr/lib/init/bootclean.sh`

### 2. Integracja środowiska graficznego LXQt i autologinu LightDM
- **Zainstalowane pakiety GUI (wyłącznie oficjalne repozytoria Debiana 13 trixie, 0 pakietów menedżera systemd)**:
  - `xorg`, `xserver-xorg`, `xserver-xorg-legacy`, `xinit`, `openbox`
  - `lxqt-core`, `qterminal`, `pcmanfm-qt`
  - `lightdm`, `lightdm-gtk-greeter`
  - `elogind`, `libpam-elogind`, `dbus-x11`
  - Pakiety dodano do `config/package-lists/foxoos.list.chroot` oraz zaktualizowano manifest `iso_root/live/filesystem.packages`.
- **Konfiguracja autologinu Live**:
  - Utworzono plik konfiguracyjny `/etc/lightdm/lightdm.conf.d/80-live-autologin.conf`:
    ```ini
    [Seat:*]
    autologin-user=foxos
    autologin-user-timeout=0
    user-session=lxqt
    greeter-session=lightdm-gtk-greeter
    ```
  - Skonfigurowano uprawnienia Xorg (`/etc/X11/Xwrapper.config`): `allowed_users=anybody`, `needs_root_rights=yes` oraz suid dla `/usr/lib/xorg/Xorg.wrap` w SquashFS pseudo-spec (`usr/lib/xorg/Xorg.wrap m 4755 0 0`).
  - Dodano użytkownika `foxos` do grup: `autologin`, `video`, `audio`, `input`, `plugdev`, `netdev`, `dialout`, `users`, `sudo`.
  - Włączono usługi OpenRC w poziomie uruchomieniowym `default`:
    - `lightdm` (`/etc/runlevels/default/lightdm -> /etc/init.d/lightdm`)
    - `elogind` (`/etc/runlevels/default/elogind -> /etc/init.d/elogind`)
  - Skonfigurowano autostart i wygląd pulpitu LXQt (`/home/foxos/.config/pcmanfm-qt/lxqt/settings.conf` oraz `/etc/skel/.config/pcmanfm-qt/lxqt/settings.conf`): tapeta FoxoOS `/usr/share/wallpapers/foxoos/wallpapermain.png`.
  - Na pulpicie umieszczono skrót instalatora graficznego: `/home/foxos/Desktop/install-foxoos.desktop` („Zainstaluj FoxoOS”).

### 3. Zbudowany obraz ISO i weryfikacja automatyczna
- **Ścieżka do pliku ISO**: `/home/foxos/foxoos/foxoos-1.0-amd64.iso`
- **Rozmiar**: 591 MB (618 938 368 B)
- **Suma kontrolna SHA-256**: `337eef103ece43d9ee6a0648b882dde83b08a39fc1a6c474898412926bae0b24`
- **Wynik testu automatycznego QEMU TCG (`scripts/test-qemu.sh`)**:
  - `PASS: PID 1 is init (sysvinit-core)`
  - `PASS: /proc/1/exe is /usr/sbin/init`
  - `PASS: os-release identifies FoxoOS`
  - `PASS: os-release keeps Debian base ID`
  - `PASS: FOXOS_VERSION present`
  - `PASS: no systemd/systemd-sysv manager packages`
  - `PASS: services started by OpenRC`
  - `PASS: DHCP address from QEMU user network`
  - `PASS: DNS resolves deb.debian.org`
  - `PASS: ping 1.1.1.1 succeeds`
  - `PASS: Xorg binary is present and executable`
  - `PASS: LightDM display manager binary is present`
  - `PASS: LXQt session binary is present`
  - `PASS: Calamares installer binary is present and executable`
  - `PASS: Calamares configuration is present`
  - `PASS: FoxoOS branding for Calamares is present`
  - `PASS: FoxoOS installer desktop shortcut is present`
  - `PASS: no find cannot delete flood (bootclean cleanly skipped live mounts)`
  - `PASS: diagnostics completed`
  - Status usług w uruchomionym systemie:
    - `NetworkManager is running.`
    - `dbus is running.`
    - `rsyslogd is running.`
    - `lightdm is running.`
    - `elogind is running.`

## 14. Usunięcie błędów Permission denied i czarnego ekranu w VirtualBoxie (2026-11-15 23:33)

### Przyczyny problemów w VirtualBoxie
1. **Wymuszanie właściciela root w SquashFS (`-all-root` bez `-pseudo-override`)**:
   Flaga `-all-root` w poleceniu `mksquashfs` bez flagi `-pseudo-override` wymuszała właściciela `root:root` (UID 0, GID 0) na dosłownie każdym pliku i katalogu w systemie, ignorując plik pseudo-spec. W efekcie cały katalog domowy `/home/foxos` stał się własnością roota bez praw zapisu dla zwykłego użytkownika. Podczas logowania użytkownik `foxos` (UID 1000) nie mógł zapisać pliku autoryzacji sesji X11 (`/home/foxos/.Xauthority`), plików pamięci podręcznej (`.cache`) ani historii powłoki (`.bash_history`), rzucając błędy `Permission denied` i powodując natychmiastowe załamanie sesji graficznej LXQt.
2. **Brak konta systemowego `lightdm` i katalogów stanu**:
   W pliku `/etc/passwd` i `/etc/group` brakowało konta użytkownika `lightdm` (UID 111, GID 115) oraz `polkitd` i `colord`. Ponadto katalog stanu `/var/lib/lightdm` nie istniał, przez co menedżer LightDM nie mógł utworzyć autoryzacji serwera wyświetlania dla ekranu.
3. **Konfiguracja LightDM**:
   W Debianie LightDM domyślnie **nie** czyta katalogu `/etc/lightdm/lightdm.conf.d/` (czyta `/etc/lightdm/lightdm.conf` oraz `/usr/share/lightdm/lightdm.conf.d/`). Dodatkowo parametr `logind-check-graphical=true` blokował uruchomienie serwera wyświetlania przed zgłoszeniem gotowości graficznej przez udev/logind.
4. **Brak konfiguracji PAM elogind**:
   W `/etc/pam.d/common-session` brakowało wpisu `session optional pam_elogind.so`, przez co nie był tworzony katalog `$XDG_RUNTIME_DIR` (`/run/user/1000`).

### Wdrożone rozwiązania
1. **Pełna specyfikacja uprawnień i `-pseudo-override`**:
   - Wygenerowano wpisy pseudo dla każdego pliku i podkatalogu w `/home/foxos` z UID 1000 i GID 1000 (`m <mode> 1000 1000`).
   - Wprowadzono flagę `-pseudo-override` w poleceniu `mksquashfs`.
   - Poprawiono wpisy modyfikujące istniejące katalogi systemowe (`m` zamiast `d` dla `/var/lib/lightdm`, `/var/log/lightdm`, `/var/cache/lightdm`).
2. **Konta systemowe i grupy**:
   - Zintegrowano użytkowników systemowych: `lightdm:x:111:115`, `polkitd:x:987:987`, `colord:x:109:113`, `rtkit:x:108:112`, `avahi:x:102:107`, `messagebus:x:990:990`.
   - Dodano użytkownika `foxos` do wszystkich niezbędnych grup: `sudo`, `autologin`, `video`, `render`, `audio`, `input`, `plugdev`, `netdev`, `dialout`, `users`.
3. **Usługa wczesnego rozruchu `/etc/init.d/foxoos-live-prepare`**:
   - Zarejestrowana w poziomie `sysinit` OpenRC.
   - Dynamicznie przed uruchomieniem jakichkolwiek demonów zapewnia poprawność uprawnień na warstwie overlay: `/home/foxos` (1000:1000), `/run/user/1000` (1000:1000, 0700), `/tmp` (1777), `/var/lib/lightdm` (111:115, 0750), `/var/log/lightdm` (0:115, 0711) oraz weryfikuje `/etc/X11/default-display-manager`.
4. **Konfiguracja LightDM i X11**:
   - Skonfigurowano bezpośrednio `/etc/lightdm/lightdm.conf` oraz `/usr/share/lightdm/lightdm.conf.d/80-foxoos-live.conf`: `logind-check-graphical=false`, `autologin-user=foxos`, `user-session=lxqt`, `greeter-session=lightdm-gtk-greeter`.
   - Utworzono dowiązanie `/usr/share/xgreeters/lightdm-greeter.desktop -> lightdm-gtk-greeter.desktop`.
   - Zaktualizowano `/etc/pam.d/common-session` o moduł `pam_elogind.so`.

### Weryfikacja
- **Obraz ISO**: `/home/foxos/foxoos/foxoos-1.0-amd64.iso`
- **SHA-256**: `333c10442501a10e0868de0754bd0a22fb57d54ac0f06cd8a2c61c1b4d4a72de`
- **Test rozruchu (`tests/qemu-20261115-232829.log`)**:
  - `WRITE_HOME_OK`: zapis do `/home/foxos` bez błędów uprawnień.
  - `WRITE_TMP_OK`: zapis do `/tmp` bez błędów uprawnień.
  - Uprawnienia zweryfikowane: `/home/foxos` (1000:1000, 0755), `/tmp` (0:0, 1777), `/var/lib/lightdm` (111:115, 0750).
  - Aktywny proces Xorg na tty7: `/usr/lib/xorg/Xorg :0 -seat seat0 -auth /run/lightdm/root/:0 -nolisten tcp vt7 -novtswitch`.
  - Wszystkie asercje: PASS (0 błędów Permission denied).

## 15. Naprawa uruchamiania instalatora Calamares oraz brakujących ikon systemowych (2026-11-16 00:34)

### Przyczyny problemów
1. **Brak reakcji po kliknięciu na skrót „Zainstaluj FoxoOS” na pulpicie**:
   - **Brakujące biblioteki współdzielone Calamares**: Binarka Calamares w Debianie 13 (*trixie*) oraz jej moduły dynamiczne wymagają:
     - `libpython3.13.so.1.0` (pakiet `libpython3.13`),
     - `libparted.so.2` (pakiet `libparted2t64` i `parted`),
     - `libpwquality.so.1` (pakiet `libpwquality1` i `libpwquality-common`),
     - `libproxy.so.1` (pakiet `libproxy1v5` i `libduktape207` wymagane tranzytywnie przez `libQt6Network`).
     Próba uruchomienia Calamares kończyła się błędem dynamic linkera (`cannot open shared object file: No such file or directory`) z kodem wyjścia 127.
   - **Błędny skrypt startowy launchera (`calamares-install-foxoos`)**: Poprzedni skrypt wywoływał `pkexec calamares ""` – binarka `/usr/bin/pkexec` w SquashFS nie posiadała bitu SUID (`0755` zamiast `4755`), powodując natychmiastowe odrzucenie z komunikatem `pkexec must be setuid root`. Ponadto parametr `""` (pusty string) powodował błąd parsowania argumentów Calamares, a sudo w sesji live czyściło zmienne środowiskowe `DISPLAY` i `XAUTHORITY`.
   - **Uszkodzone dowiązanie QML**: Dowiązanie `/etc/calamares/qml` wskazywało na bezwzględną ścieżkę stagingową `/tmp/sq_unpack/usr/share/calamares/qml`, która nie istniała w uruchomionym systemie live.
2. **Brakujące ikony w środowisku graficznym (LXQt / pulpit / menu / LightDM)**:
   - Domyślny motyw ikon LXQt (`/usr/share/lxqt/lxqt.conf`) to `breeze`, a LightDM GTK greeter to `Papirus-Dark`. W obrazie brakowało kompletnych pakietów motywów `kf6-breeze-icon-theme` oraz `papirus-icon-theme`.
   - **Kluczowy brak wtyczki Qt6 SVG**: Motywy Breeze i Papirus składają się w przeważającej większości z plików wektorowych SVG. Aplikacje oparte na Qt6 (panel LXQt, menedżer plików PCManFM-Qt, instalator Calamares) wymagają wtyczki silnika ikon `qt6-svg-plugins` (`/usr/lib/x86_64-linux-gnu/qt6/plugins/iconengines/libqsvgicon.so` oraz `imageformats/libqsvg.so`). Bez tego pakietu Qt6 nie jest w stanie wyrenderować żadnej ikony SVG, wyświetlając puste miejsca zamiast ikon.
   - W pamięci podręcznej modułów GdkPixbuf (`loaders.cache`) brakowało wpisu dla modułu SVG `libpixbufloader_svg.so`.
   - Ikona skrótu instalatora `install-foxoos` znajdowała się tylko w rozdzielczości 256x256, podczas gdy ikony pulpitu LXQt domyślnie używają rozmiaru 48x48.

### Wdrożone rozwiązania
1. **Instalacja kompletnych bibliotek i pakietów Calamares**:
   - Zainstalowano i zintegrowano w SquashFS: `libpython3.13`, `libparted2t64`, `parted`, `libpwquality1`, `libpwquality-common`, `libcrack2`, `dmidecode`, `cracklib-runtime`, `wamerican`, `libproxy1v5`, `libduktape207`.
   - Zweryfikowano rekurencyjnie za pomocą skryptu ELF analizatora brak jakichkolwiek brakujących bibliotek we wszystkich 347 plikach binarnych i modułach Calamares.
2. **Nowy bezpieczny launcher `/usr/bin/calamares-install-foxoos`**:
   - Automatyczny eksport zmiennych środowiskowych `DISPLAY` oraz `XAUTHORITY`.
   - Zezwolenie lokalnemu użytkownikowi root na dostęp do serwera X (`xhost +local:root`).
   - Uruchamianie z uprawnieniami root przez `sudo -E` (w sesji live użytkownik `foxos` ma uprawnienia `NOPASSWD: ALL` w `/etc/sudoers.d/foxos`).
   - Zachowanie zmiennych wyświetlania w `/etc/sudoers.d/foxos`:
     `Defaults:foxos env_keep += "DISPLAY XAUTHORITY WAYLAND_DISPLAY QT_QPA_PLATFORMTHEME"`.
   - Prawidłowe przekazywanie parametrów `"$@"` (brak pustego stringa `""`).
   - Dodatkowe zabezpieczenie w postaci uprawnień SUID (`4755 0 0`) dla `usr/bin/pkexec` oraz `usr/lib/polkit-1/polkit-agent-helper-1` w `pseudo.txt`.
3. **Poprawa dowiązania QML**:
   - Przekształcono `/etc/calamares/qml` w relatywne dowiązanie `../../usr/share/calamares/qml`, poprawne zarówno w stagingu, jak i w docelowym obrazie live.
4. **Instalacja motywów ikon i silnika SVG**:
   - Zainstalowano pakiety motywów `kf6-breeze-icon-theme` oraz `papirus-icon-theme`.
   - Zainstalowano pakiet `qt6-svg-plugins` (dostarczający `libqsvgicon.so` dla Qt6) oraz `librsvg2-common`.
   - Wygenerowano pamięci podręczne ikon `gtk-update-icon-cache` dla motywów: `hicolor`, `breeze`, `Papirus`, `Papirus-Dark` oraz zaktualizowano `loaders.cache` dla GdkPixbuf.
   - Skopiowano ikonę `install-foxoos.png` do wszystkich standardowych rozmiarów: `16x16`, `32x32`, `48x48`, `64x64`, `128x128`, `256x256` w motywach hicolor, breeze i Papirus oraz do `/usr/share/pixmaps/`.
5. **Aktualizacja manifestów i konfiguracji projektu**:
   - Zaktualizowano `config/package-lists/foxoos.list.chroot`, `iso_root/live/filesystem.packages` oraz bazę `/var/lib/dpkg/status`.

### Weryfikacja
- **Nowy obraz ISO**: `/home/foxos/foxoos/foxoos-1.0-amd64.iso`
- **Suma kontrolna SHA-256**: `89e960dd24e71d9cdd5ee4bfd64617b37a17f7239669c157bfb40ab5d668c3d7`
- **Rozmiar ISO**: 626 MB
- **Wynik testu automatycznego QEMU (`tests/qemu-20261116-002942.log`)**:
  - `CALAMARES_BIN_OK`: obecny i wykonywalny.
  - `CALAMARES_CONF_OK`: konfiguracja `/etc/calamares/settings.conf` poprawna.
  - `CALAMARES_BRANDING_OK`: branding FoxoOS obecny.
  - `CALAMARES_DESKTOP_OK`: skrót na pulpicie `/home/foxos/Desktop/install-foxoos.desktop` obecny i wykonywalny.
  - `CALAMARES_LAUNCHER_OK`: launcher `/usr/bin/calamares-install-foxoos` obecny i poprawny.
  - `BREEZE_ICONS_OK`: motyw Breeze w `/usr/share/icons/breeze` zainstalowany.
  - `PAPIRUS_ICONS_OK`: motyw Papirus w `/usr/share/icons/Papirus` zainstalowany.
  - `QT6_SVG_OK`: silnik `libqsvgicon.so` zainstalowany w Qt6 plugins.
  - `CALAMARES_QML_LINK_OK`: symlink `/etc/calamares/qml` poprawny.
  - `CALAMARES_VERSION_OK`: `calamares 3.3.14` wykonany przez bezhasłowe `sudo -n` bez błędów.
  - Wynik testu: **QEMU smoke test PASSED**.
