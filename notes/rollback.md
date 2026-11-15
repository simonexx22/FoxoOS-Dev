# FoxoOS — rollback

## Wariant A: snapshot VirtualBox (najpewniejszy)

VirtualBox -> maszyna FoxoOSdev -> Snapshoty -> przywroc snapshot sprzed migracji.

## Wariant B: powrot do systemd bez snapshota (dziala do etapu 2)

Pakiet `systemd` (z binarka `/lib/systemd/systemd`) jest jeszcze zainstalowany
po etapie 1. Jesli system nie wstaje:

1. W menu GRUB zaznacz wpis FoxoOS/Debian, nacisnij `e`.
2. W linii zaczynajacej sie od `linux` dopisz na koncu:
   `init=/lib/systemd/systemd`
3. Ctrl-X / F10, zaloguj sie.
4. Przywroc systemd-sysv:

       sudo apt-get install -y systemd-sysv
       sudo reboot

Po etapie 2 (systemd usuniety) ten wariant nie zadziala — zostaje snapshot
albo reinstalacja z ISO FoxoOS.

## Wariant C: siec nie wstala, ale login dziala

    sudo bash /home/foxos/foxoos/scripts/90-net-fallback.sh

To ustawia statycznie VBox NAT: 10.0.2.15/24, gw 10.0.2.2, DNS 10.0.2.3.
Potem diagnoza:

    rc-service network-manager status
    rc-service dbus status
    cat /var/log/NetworkManager.log 2>/dev/null
    journalctl  # nie istnieje po usunieciu systemd
    dmesg | tail

## Cofniecie brandingu

    sudo rm -f /etc/os-release
    sudo dpkg-divert --local --rename --remove /etc/os-release
    sudo rm -f /etc/issue
    sudo dpkg-divert --local --rename --remove /etc/issue
    sudo rm -f /etc/default/grub.d/99-foxoos.cfg
    sudo update-grub

## Cofniecie uslugi NM

    sudo rc-update del network-manager default
    sudo rm -f /etc/init.d/network-manager
