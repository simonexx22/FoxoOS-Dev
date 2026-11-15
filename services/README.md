# FoxoOS — uslugi pod OpenRC

## Mechanizm w Debian 13

- PID 1: `sysvinit-core` czyta `/etc/inittab`.
- `si::sysinit:/etc/init.d/rcS` -> `openrc sysinit`
- `l2:2:wait:/etc/init.d/rc 2` -> `openrc default`
- `l0`/`l6` -> `openrc off`, `openrc shutdown`, `/etc/init.d/halt`
- Skrypty uslug pozostaja w `/etc/init.d` (format LSB/OpenRC).
- `update-rc.d` w Trixie jest swiadomy OpenRC: wywoluje `rc-update add`
  i mapuje runlevel S->sysinit, 2-5->default, 0/6->off.
  Dzieki temu nowo instalowane pakiety same trafiaja do runleveli.

## Reczny odpowiednik

    rc-update add <usluga> default
    rc-update del <usluga> default
    rc-service <usluga> start|stop|restart|status
    rc-status -a
    rc-status --crashed

## Uslugi krytyczne dla pierwszego bootu

| Usluga | Runlevel | Rola |
|---|---|---|
| mountkernfs.sh | sysinit | /proc, /sys, /run |
| hostname.sh | sysinit | /etc/hostname |
| checkroot.sh | sysinit | remount / rw |
| checkfs.sh | sysinit | fsck |
| mountall.sh | sysinit | fstab, swap |
| bootmisc.sh | sysinit | /tmp, /var/run, czyszczenie |
| udev | sysinit | /dev, coldplug |
| networking | sysinit | ifup -a (tylko lo) |
| dbus | default | szyna systemowa |
| network-manager | default | enp0s3, DHCP, DNS (skrypt FoxoOS) |
| elogind | default | sesje/seaty (etap 2) |

## Skrypt FoxoOS dla NetworkManager

`/etc/init.d/network-manager` (z `system/etc/init.d/network-manager`):

    supervisor=supervise-daemon
    command=/usr/sbin/NetworkManager
    command_args=--no-daemon
    depend: need dbus, provide net, after networking

Powod: Debian 13 nie dostarcza juz skryptu sysvinit dla NetworkManagera,
a bez niego system po przejsciu na sysvinit nie ma sieci.
