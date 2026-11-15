# Test bootu ISO

## Test automatyczny QEMU (TCG, bez KVM)

Wymagania:

    sudo apt-get install qemu-system-x86 expect

Uruchomienie:

    cd /home/foxos/foxoos
    make test

Skrypt `scripts/test-qemu.sh`:

1. bootuje ISO przez QEMU z `-serial stdio` i `-nic user,model=e1000`
2. czeka na `foxoos login:` na ttyS0
3. loguje `foxos` / `live`
4. sprawdza PID 1, usługi OpenRC, brak systemd, DHCP, DNS, ping
5. robi `sudo poweroff` i czeka na zakończenie QEMU
6. zapisuje log w `tests/qemu-*.log` i link `tests/qemu-latest.log`

Test nie wymaga KVM (działa w VirtualBox gość bez nested virtualization),
ale boot może trwać kilka minut.

## Test ręczny VirtualBox

1. VirtualBox → Nowa → „FoxoOS-test”.
2. Typ: Linux, wersja: Debian (64-bit).
3. RAM: 2048 MB, CPU: 2.
4. Dysk: nie tworzyć (live ISO) albo 8 GB, jeśli chcesz testować instalację.
5. System → Płyta główna → „Enable EFI” **wyłączone** (obraz jest BIOS/GRUB).
6. Napęd optyczny: `foxoos-1.0-amd64.iso`; boot z CD/DVD.
7. Uruchom i wybierz „Live system (amd64)”.

### Czego szukać

Po zalogowaniu (`foxos` / `live`):

    cat /proc/1/comm                 # init
    readlink -f /proc/1/exe          # /usr/sbin/init
    rc-status default                # network-manager, dbus, rsyslog started
    ip -br a                         # adres DHCP (VBox NAT: 10.0.2.15)
    getent hosts deb.debian.org      # DNS
    ping -c1 1.1.1.1                 # sieć
    dpkg -l | grep -E '^ii +(systemd|systemd-sysv) ' || echo "brak systemd"
    cat /etc/os-release              # NAME="FoxoOS", ID=debian

### Czysty shutdown/reboot

    sudo poweroff

VM powinna się wyłączyć bez błędu. Dla rebootu:

    sudo reboot

Po restarcie live system wstaje od nowa (overlay jest w RAM).

## Test serial w VirtualBox (opcjonalny)

Ustawienia VM → Porty szeregowe → Port 1:
- „Enable Port”
- Port mode: Host Pipe
- Path/Address: `/tmp/foxoos-serial`
- „Connect to existing pipe/socket”

W gościu wybierz wpis GRUB i naciśnij `e`, upewnij się, że linia `linux`
zawiera `console=ttyS0,115200 console=tty0` (jest w `auto/config`).
Po boocie:

    socat - UNIX-CONNECT:/tmp/foxoos-serial

## Jeśli boot nie dojdzie do loginu

1. W GRUB naciśnij `e`, usuń `quiet` z linii `linux`, dodaj `debug`.
2. Sprawdź, czy widzisz `Run /init as init process` i czy live-boot montuje
   squashfs.
3. Sprawdź `rc-status -a`; brak `live-config` w `sysinit` oznacza, że hook
   `0300` nie dodał usługi.
4. Sprawdź `dpkg -l | grep systemd` — jeśli jest `systemd-sysv`, obraz został
   zbudowany z błędną konfiguracją (patrz `docs/BUILD.md`).
