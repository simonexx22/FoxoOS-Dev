# Branding FoxoOS

## Zasada

FoxoOS ma nazwę widoczną w identyfikacji systemu, powitaniu konsoli i menu
bootowania, ale **baza Debian pozostaje rozpoznawalna**:

- `ID=debian`, `ID_LIKE=debian`
- `VERSION_ID="13"`, `VERSION_CODENAME=trixie`
- `/etc/debian_version` nietknięte
- `DEBIAN_CODENAME`, `DEBIAN_VERSION_FULL`
- dodatkowo `FOXOS_VERSION="1.0"`, `FOXOS_BASE`, `FOXOS_BUILD`

Dzięki `ID=debian` narzędzia Debiana, które sprawdzają tylko `ID`, nadal
działają. FoxoOS-specific kod powinien sprawdzać `FOXOS_VERSION` lub
`FOXOS_BASE`.

## Pliki

| Plik | Rola |
|---|---|
| `/etc/os-release` | `NAME="FoxoOS"`, `PRETTY_NAME`, `FOXOS_*`, `ID=debian` |
| `/etc/issue` | powitanie getty na tty1 |
| `/etc/issue.net` | powitanie dla logowania sieciowego |
| `/etc/motd` | powitanie po zalogowaniu (ASCII + informacje) |
| `/etc/lsb-release` | `DISTRIB_ID=FoxoOS` |
| `/etc/debian_version` | bez zmian, kompatybilność |
| `/etc/default/grub.d/99-foxoos.cfg` | `GRUB_DISTRIBUTOR` |
| `/etc/apt/preferences.d/99-foxoos-no-systemd` | pin |

## Przetrwanie aktualizacji

`base-files` jest właścicielem `/etc/issue`, `/etc/issue.net` i źródła
`/etc/os-release`. Dlatego:

- `/etc/os-release` jest zwykłym plikiem FoxoOS, a oryginalny symlink Debiana
  jest odsunięty przez `dpkg-divert` do `/etc/os-release.debian`.
- `/etc/issue` i `/etc/issue.net` są odsunięte do `*.debian`.
- `/etc/motd` i `/etc/lsb-release` nie należą do `dpkg`, więc nie ma konfliktu.

Po aktualizacji `base-files` nowe pliki Debiana trafią do `*.debian`, a
FoxoOS zostanie na swoim miejscu.

Sprawdzenie:

    dpkg-divert --list | grep -E 'os-release|/etc/issue'
    cat /etc/os-release
    lsb_release -a

## GRUB

`/etc/default/grub.d/99-foxoos.cfg` jest źródłem prawdy:

    GRUB_DISTRIBUTOR="FoxoOS 1.0 GNU/Linux"

`update-grub` wpisuje to do `/boot/grub/grub.cfg`. To nie reinstaluje
bootloadera — tylko regeneruje konfigurację.

## Live ISO

W obrazie live:

- `--iso-application "FoxoOS 1.0"`
- `--iso-volume "FOXOOS"`
- motyw GRUB: `config/bootloaders/grub-pc/live-theme/theme.txt`
  z tytułem „FoxoOS 1.0 Live”
- splash: `config/bootloaders/grub-pc/splash.svg`
- `/etc/os-release` jest generowany w hooku `0100`, z zachowaniem
  `IMAGE_ID`/`BUILD_ID` z live-build
- wpisy menu „Live system (amd64)” pochodzą z live-build; tytuł menu i
  branding ISO są FoxoOS

## Zmiana na `ID=foxoos`

Jeśli wolisz klasyczną identyfikację derivative (jak Ubuntu):

    sed -i 's/^ID=debian$/ID=foxoos/' /etc/os-release

Wtedy zaktualizuj też `config/hooks/normal/0100-foxoos-branding.hook.chroot`
i `0500-foxoos-verify.hook.chroot` (kontrola `ID=debian`). Domyślnie
zostawiamy `ID=debian` dla maksymalnej kompatybilności z Debianem.
