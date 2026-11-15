# FoxoOS — pakiety: wybor i wyjatki

## Etap 1 — instalowane

    sysvinit-core      # PID 1 (/usr/sbin/init), inittab, getty
    openrc             # runlevel, rc-update/rc-service/rc-status, /etc/init.d/rc*

## Etap 1 — usuwane

    systemd-sysv-      # cel migracji (Essential/Protected: wymaga --allow-remove-essential)
    plymouth plymouth-label libplymouth5   # splash systemd, zbedny do text login

Skutek uboczny (wynik zaleznosci, nie osobna decyzja): GDM3 i stos GNOME,
packagekit, polkitd, pkexec, libpam-systemd, ModemManager, nm-connection-editor.

## Etap 2 — instalowane

    elogind                      # logind API bez systemd (sesje, seaty; potrzebne pod KDE)
    libpam-elogind               # pam_elogind w PAM
    systemd-standalone-sysusers  # zaspokaja udev: Depends: systemd | systemd-standalone-sysusers

## Etap 2 — usuwane

    systemd- systemd-sysv-  (oraz systemd-timesyncd, libnss-systemd)

## Co zostaje ze skladnikow systemd i dlaczego

| Pakiet | Dlaczego zostaje |
|---|---|
| libsystemd0 | biblioteka ABI uzywana przez NetworkManager, dbus i inne; to nie manager |
| libsystemd-shared | wewnetrzna biblioteka wspoldzielona udev i systemd-standalone-* |
| udev | obsluga /dev i hotplug; dziala samodzielnie (systemd-udevd), w Debianie 13 nie wymaga pakietu systemd |
| systemd-standalone-sysusers | dostarcza `systemd-sysusers` dla postinst pakietow, bez managera |
| libnss-myhostname | rozwiazywanie lokalnego hostname bez systemd-resolved (opcjonalne) |
| dbus | systemowa szyna D-Bus, wymagana przez NetworkManager |

## Pin APT

`/etc/apt/preferences.d/99-foxoos-no-systemd` blokuje powrot:
systemd, systemd-sysv, systemd-timesyncd, libpam-systemd, libnss-systemd
(Pin-Priority: -1). Biblioteki i udev NIE sa pinowane.

## Pakiety tylko do budowy ISO (chroot)

Live-build sprawdza w chroot narzędzia potrzebne w etapie `binary`. Przy
`--apt-indices false` listy APT są usuwane po etapie `chroot`, więc narzędzia
muszą być już zainstalowane:

    squashfs-tools     # mksquashfs w chroot
    xorriso            # budowa ISO
    isolinux           # /usr/lib/ISOLINUX/isohdpfx.bin (hybrydowy MBR)
    grub-common        # grub-mkimage
    grub-pc-bin        # boot_hybrid.img, moduły i386-pc
    librsvg2-bin       # rsvg-convert dla splash.svg
    fonts-dejavu-core  # font do splash.svg

Nie trafiają do działającego systemu jako usługi — to narzędzia obrazu.

## systemd-standalone-tmpfiles

W dev VM dodany, bo `udev`/pakiety używają `systemd-tmpfiles` do tworzenia
`/run` i katalogów tymczasowych. W ISO również jest w liście pakietów.
Nie jest to menedżer systemd.
