# FoxoOS

[![Release](https://img.shields.io/badge/release-v0.1.0--alpha-orange.svg)](https://github.com/)
[![Base](https://img.shields.io/badge/base-Debian%2013%20Trixie-blue.svg)](https://www.debian.org)
[![Init](https://img.shields.io/badge/init-sysvinit--core%20%2B%20OpenRC-green.svg)](https://wiki.debian.org/OpenRC)

Lekka dystrybucja bazująca na **Debianie 13 (Trixie)**, z **sysvinit-core jako PID 1** oraz **OpenRC** do zarządzania usługami. Repozytoria i pakiety pochodzą w 100% z oficjalnego Debiana (bez repozytoriów Devuan). System zawiera graficzny pulpit **LXQt**, menedżer logowania **LightDM** (z elogind) oraz instalator graficzny **Calamares**.

> [!IMPORTANT]
> Wydanie **v0.1.0-alpha** to wczesna wersja deweloperska przeznaczona dla współtwórców (contributors) oraz do testów na maszynach wirtualnych (VM).

---

## Cechy FoxoOS

- **PID 1:** `sysvinit-core` (`/sbin/init`)
- **Menedżer usług:** OpenRC (`rc-status`, `rc-service`, `rc-update`)
- **Brak menedżera systemd:** polecenie `systemctl` nie istnieje; brak `systemd-sysv`
- **Dozwolone biblioteki systemd:** `libsystemd0`, `libsystemd-shared`, `udev`, `systemd-standalone-sysusers`, `systemd-standalone-tmpfiles`
- **APT Pinning:** `/etc/apt/preferences.d/99-foxoos-no-systemd` trwale blokuje pakiety `systemd`, `systemd-sysv`, `systemd-timesyncd`, `libpam-systemd`, `libnss-systemd`
- **Środowisko graficzne:** LXQt + Openbox + panel i motywy FoxoOS
- **Menedżer logowania:** LightDM + `elogind` (zastępuje systemd-logind)
- **Instalator:** Calamares dostosowany do pracy w środowisku SysVinit / OpenRC
- **Bootloader:** Minimalistyczny, czytelny motyw ciemny GRUB z pełną obsługą UTF-8 (DejaVu Sans) zarówno w sesji Live USB, jak i po zainstalowaniu na dysku twardym

---

## Wymagania do budowy obrazu ISO

Budowanie obrazu Live ISO odbywa się przy użyciu pakietu `live-build` oraz narzędzi ISO:

```bash
sudo apt-get update
sudo apt-get install -y live-build xorriso squashfs-tools mtools dosfstools rsync
```

Do testów automatycznych w QEMU przydatne są:
```bash
sudo apt-get install -y qemu-system-x86 expect
```

---

## Procedura budowania ISO

### 1. Pełna kompilacja przez live-build:
```bash
cd /home/foxos/foxoos
make build
```
Wynikiem jest plik `foxoos-0.1.0-alpha-amd64.iso` oraz plik sumy kontrolnej `.sha256`.

### 2. Szybka finalizacja / ponowne spakowanie SquashFS:
Jeśli wprowadzono zmiany w strukturze plików, można użyć skryptu pomocniczego:
```bash
./scripts/finalize_iso.sh
```

---

## Testowanie i weryfikacja

### Dane domyślne sesji Live:
- **Użytkownik:** `foxos`
- **Hasło:** `live`
- **Sudo:** bez hasła (`NOPASSWD`)

### Test w VirtualBox / KVM / QEMU:
1. Utwórz maszynę wirtualną (typ: Linux / Debian 64-bit), min. 2048 MB RAM, 2 rdzenie CPU.
2. Podłącz obraz `foxoos-0.1.0-alpha-amd64.iso`.
3. Po uruchomieniu w menu GRUB wybierz **Uruchom FoxoOS Live**.
4. Sprawdzenie stanu systemu:
   ```bash
   cat /proc/1/comm              # Powinno zwrócić: init
   rc-status default             # Status usług OpenRC (NetworkManager, dbus, rsyslog)
   dpkg -l | grep systemd-sysv   # Powinno zwrócić brak pakietu
   ```
5. Uruchomienie instalatora z ikony na pulpicie („Zainstaluj FoxoOS”) lub terminala:
   ```bash
   calamares-install-foxoos
   ```

---

## Struktura projektu

```text
├── auto/                     # Konfiguracja live-build (auto/config)
├── config/
│   ├── bootloaders/grub-pc/  # Konfiguracja i motyw bootloadera GRUB
│   ├── hooks/normal/         # Hooki chroot i binary (branding, user, usługi)
│   ├── includes.chroot/      # Pliki wstrzykiwane bezpośrednio do systemu Live
│   └── package-lists/        # Listy pakietów APT dla instalacji bazowej
├── system/                   # Pliki konfiguracyjne instalowanego systemu FoxoOS
├── scripts/                  # Skrypty budowania, instalacji i testów QEMU
├── notes/                    # Notatki z migracji i audytu
├── Makefile                  # Cele kompilacji i testów
├── README.md                 # Niniejsza dokumentacja
└── CONTRIBUTING.md           # Zasady współtworzenia projektu
```

---

## Status testów i znane ograniczenia (v0.1.0-alpha)

- **Sesja Live:** W pełni przetestowana i stabilna. LXQt uruchamia się prawidłowo, NetworkManager zarządza siecią, OpenRC poprawnie zarządza usługami, brak błędów D-Bus / polkit.
- **Instalator Calamares:** Wdrożono poprawki wyszukiwania dysków (`kpmcore` / polkit), obsługi reguł haseł (`cracklib`), wrapper `systemd-machine-id-setup` dla OpenRC oraz oczyszczania pakietów specyficznych dla sesji Live (`packages.conf`).
- **Testowanie instalatora:** Najnowsze poprawki brandingu i motywu GRUB dla systemu zainstalowanego są przygotowane do weryfikacji manualnej przez społeczność na maszynach wirtualnych. Wszelkie napotkane błędy prosimy zgłaszać w repozytorium GitHub!

---

## Licencja i współtworzenie

Informacje o zasadach zgłaszania błędów i przesyłania poprawek znajdują się w pliku [CONTRIBUTING.md](CONTRIBUTING.md).
FoxoOS korzysta z komponentów Debiana na licencjach otwartych (GPL, BSD, MIT i kompatybilnych).
