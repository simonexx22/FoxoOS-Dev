# Budowanie ISO FoxoOS

## Model

Obraz jest budowany od zera z oficjalnego mirrora Debiana (`trixie`, `main`)
przez `live-build`. Nie kopiujemy zainstalowanego systemu z VM — dzięki temu
wynik jest powtarzalny i nie zawiera śmieci z hosta.

- `sysvinit-core` jako PID 1
- `openrc` jako menedżer usług
- `live-boot` + `live-config` (backend `sysvinit`)
- `network-manager` + `dbus` (DHCP/DNS)
- `rsyslog` (logi), `sudo`, `user-setup`, podstawowe narzędzia
- brak X11/LXQt — to minimalny obraz tekstowy
- brak `systemd`, `systemd-sysv`, `systemd-timesyncd`
- dozwolone: `libsystemd0`, `libsystemd-shared`, `udev`,
  `systemd-standalone-sysusers`, `systemd-standalone-tmpfiles`

## Pliki konfiguracyjne

`auto/config` zawiera całą komendę `lb config`. Nie uruchamiaj `lb config`
ręcznie z innymi opcjami — nadpisałby konfigurację. Po zmianie `auto/config`:

    make reconfigure

`config/package-lists/live.list.chroot` — pakiety live-boot/live-config.
`config/package-lists/foxoos.list.chroot` — reszta systemu.
`config/includes.chroot_before_packages/` — pin APT działa już podczas
instalacji pakietów w chroot.
`config/hooks/normal/0[1-5]00-*.hook.chroot` — branding, użytkownik, runlevel,
czyszczenie i twarda weryfikacja obrazu.

## Przebieg

    make build

Etapy live-build:

1. `bootstrap` — debootstrap `--variant=minbase` (bez `init`/`systemd-sysv`)
2. `chroot` — instalacja list pakietów, potem include i hooki
3. `binary` — squashfs, initramfs, GRUB, ISO hybrydowe
4. `make` kopiuje wynik do `foxoos-1.0-amd64.iso` i liczy SHA-256

## Weryfikacja manifestu

    make manifest

albo bezpośrednio:

    grep -E '^ii +(systemd|systemd-sysv|systemd-timesyncd) ' \
        binary/live/filesystem.packages || echo "brak menedżera systemd"

Hook `0500-foxoos-verify.hook.chroot` przerywa budowę, jeśli:

- zainstalowany jest `systemd`, `systemd-sysv`, `systemd-timesyncd`,
  `libpam-systemd` lub `libnss-systemd`
- brakuje `sysvinit-core`, `openrc`, `live-config`, `live-boot`,
  `network-manager`, `dbus` lub `udev`
- `/sbin/init` nie należy do `sysvinit-core`
- w obrazie istnieje `systemctl`
- brakuje linków OpenRC dla `live-config`, `udev`, `dbus`,
  `network-manager`
- `/etc/os-release` nie ma `NAME="FoxoOS"`, `ID=debian` lub
  `FOXOS_VERSION="1.0"`

## Przerwana budowa (ważne)

live-build trzyma znaczniki etapów w `.build/` i kopię stanu bootstrapu w
`cache/bootstrap`. Jeśli proces `lb build` zostanie zabity (np. zamknięcie
terminala, restart VM), następne uruchomienie **odtworzy `chroot/` z
`cache/bootstrap`**, ale znaczniki `.build/chroot_*` nadal będą mówić
„zrobione”. Skutek: chroot wraca do `minbase`, a budowa przewraca się na
`env: 'update-initramfs': No such file or directory`.

Po każdej przerwanej budowie:

    make distclean
    make build

`make distclean` usuwa `chroot/`, `cache/`, `binary/`, `.build/` i wygenerowane
`config/{common,bootstrap,chroot,binary,source}`. Nie usuwaj tylko `.lock` —
to nie wystarczy.

## Typowe problemy

### `systemd-sysv` próbuje się zainstalować

Sprawdź, czy `--debootstrap-options "--variant=minbase"` jest w `auto/config`
oraz czy pin z `includes.chroot_before_packages` istnieje. `live-config-systemd`
jest zabroniony — używamy `live-config-sysvinit`.

### Brak `rsvg-convert` / błąd splash

W liście pakietów muszą być `librsvg2-bin` i `fonts-dejavu-core`. Live-build
konwertuje `config/bootloaders/grub-pc/splash.svg` do PNG wewnątrz chroot.

### Brak `network-manager` w runlevel

Hook `0300-foxoos-services.hook.chroot` dodaje usługi przez `rc-update`.
Jeśli package install order się zmieni, hook i tak je dopisze.

### Apt nie widzi pakietów w live ISO

`--apt-indices false` celowo nie pakuje list APT do obrazu. W live systemie:

    sudo apt update

## Reproducibility

`SOURCE_DATE_EPOCH` jest stały (2026-11-15 00:00:00 UTC), więc metadane ISO
(m.in. timestamp ISO i `BUILD_ID`) są deterministyczne. Wersje pakietów zależą
od aktualnego stanu mirrora `trixie`; dla bit-identycznych obrazów trzeba
pinować wersje lub użyć snapshotu Debiana.
