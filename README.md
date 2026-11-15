# FoxoOS

Dystrybucja oparta na Debian GNU/Linux 13 (Trixie), z **sysvinit-core jako PID 1**
i **OpenRC** do uslug. Repozytoria i pakiety pozostaja oficjalnie Debiana
(bez Devuan). Docelowo: text login -> KDE Plasma -> ISO live-build.

## Stan prac

- [x] Audyt VM i warstwy terminala (realna VM VirtualBox, nie sandbox)
- [x] Symulacja etapu 1 i etapu 2 (bez zmian w systemie)
- [ ] Snapshot VirtualBox (po stronie uzytkownika)
- [ ] Etap 1: sysvinit-core + openrc, usuniecie systemd-sysv, reboot
- [ ] Weryfikacja: PID 1, rc-status, login, siec, DNS
- [ ] Etap 2: usuniecie pakietu systemd + pin APT + drugi reboot/shutdown
- [ ] Branding FoxoOS (os-release, issue, motd, GRUB)
- [ ] ISO live-build + test bootu w osobnej VM
- [ ] KDE Plasma (pozniej)

## Struktura

    notes/migration-log.md       dziennik: audyt, symulacje, decyzje, wyniki
    notes/rollback.md            jak cofnac zmiany
    packages/README.md           wybrane pakiety, wyjatki (libsystemd0, udev...)
    services/README.md           mapowanie runleveli, uslugi krytyczne
    system/etc/init.d/network-manager      usluga OpenRC dla NM
    system/usr/local/sbin/foxoos-sysvinit-links  reboot/poweroff/telinit
    system/etc/apt/preferences.d/99-foxoos-no-systemd  pin
    system/etc/os-release, issue, motd, default/grub.d/99-foxoos.cfg
    scripts/10-stage1-init-swap.sh   transakcja init (wymaga snapshotu)
    scripts/20-preflight.sh          kontrole przed rebootem
    scripts/30-stage2-remove-systemd.sh  symulacja/--apply usuniecia systemd
    scripts/40-post-boot-check.sh    raport po reboocie
    scripts/50-apply-branding.sh     branding systemu
    scripts/90-net-fallback.sh       awaryjne przywrocenie sieci (VBox NAT)

## Uruchamianie

Etap 1 (po snapshocie):

    sudo bash scripts/10-stage1-init-swap.sh --snapshot-ok

Reboot rob recznie, po przeczytaniu kontroli. Po powrocie:

    sudo bash scripts/40-post-boot-check.sh | tee /root/foxoos-boot-report.txt

Etap 2 (najpierw symulacja, potem apply):

    sudo bash scripts/30-stage2-remove-systemd.sh
    sudo bash scripts/30-stage2-remove-systemd.sh --apply

Branding:

    sudo bash scripts/50-apply-branding.sh

## Zasady

- Zero repozytoriow Devuan; tylko deb.debian.org + security.
- Nie usuwamy jadra, GRUB-a, apt/dpkg, NetworkManagera, dbus, udev.
- `libsystemd0`, `libsystemd-shared`, `udev`, `systemd-standalone-sysusers`
  zostaja (uzasadnienie w packages/README.md).
- `--allow-remove-essential` tylko dla reviewed wymiany init, po snapshocie.
- Snapshot przed kazda nieodwracalna zmiana; wyniki testow w notes/.
