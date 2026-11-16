#!/bin/bash
# FoxoOS: boot the built ISO in QEMU (TCG) and verify the text console,
# sysvinit/OpenRC, network/DNS, absence of the systemd manager, and poweroff.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
ISO="${1:-${HERE}/foxoos-1.0-amd64.iso}"

[ -f "${ISO}" ] || { echo "ERROR: ISO not found: ${ISO}" >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "ERROR: install qemu-system-x86" >&2; exit 1; }
command -v expect >/dev/null || { echo "ERROR: install expect" >&2; exit 1; }

mkdir -p "${HERE}/tests"
LOG="${HERE}/tests/qemu-$(date +%Y%m%d-%H%M%S).log"
ln -sfn "$(basename "${LOG}")" "${HERE}/tests/qemu-latest.log"

set +e
expect -f "${HERE}/scripts/qemu-login.expect" "${ISO}" 2>&1 | tee "${LOG}"
STATUS=${PIPESTATUS[0]}
set -e
pkill -9 -f "FoxoOS-test" 2>/dev/null || true

fail=0
check() {
    local pattern="$1"
    local label="$2"
    if grep -aEq "${pattern}" "${LOG}"; then
        echo "PASS: ${label}"
    else
        echo "FAIL: ${label} (pattern: ${pattern})" >&2
        fail=1
    fi
}

check 'PID1_COMM=init' 'PID 1 is init (sysvinit-core)'
check 'PID1_EXE=/usr/sbin/init' '/proc/1/exe is /usr/sbin/init'
check 'NAME="FoxoOS"' 'os-release identifies FoxoOS'
check 'ID=debian' 'os-release keeps Debian base ID'
check 'FOXOS_VERSION="1.0"' 'FOXOS_VERSION present'
check 'NO_SYSTEMD_MANAGER' 'no systemd/systemd-sysv manager packages'
check 'is running|status: started' 'services started by OpenRC'
check '10\.0\.2\.15' 'DHCP address from QEMU user network'
check 'deb\.debian\.org' 'DNS resolves deb.debian.org'
check '1 received|0% packet loss' 'ping 1.1.1.1 succeeds'
check 'WRITE_HOME_OK' 'user foxos can write to home directory (no Permission denied)'
check 'WRITE_TMP_OK' '/tmp is writable by user (no Permission denied)'
check 'XORG_BIN_OK' 'Xorg binary is present and executable'
check 'LIGHTDM_BIN_OK' 'LightDM display manager binary is present'
check 'LXQT_BIN_OK' 'LXQt session binary is present'
check 'CALAMARES_BIN_OK' 'Calamares installer binary is present and executable'
check 'CALAMARES_CONF_OK' 'Calamares configuration is present'
check 'CALAMARES_BRANDING_OK' 'FoxoOS branding for Calamares is present'
check 'CALAMARES_DESKTOP_OK' 'FoxoOS installer desktop shortcut is present'
check 'CALAMARES_LAUNCHER_OK' 'Calamares launcher script is present and executable'
check 'PARTITION_CONF_OK' 'Calamares partition module configuration is present'
check 'GVFS_METADATA_OK' 'GVFS metadata daemon is present'
check 'DESKTOP_TRUST_OK' 'Desktop launcher metadata::trust is set to true'
check 'CALAMARES_VERSION_OK' 'Calamares runs successfully via sudo without password'
check 'FOXOS_DIAG_END' 'diagnostics completed'

if grep -a "find: cannot delete" "${LOG}"; then
    echo "FAIL: bootclean find cannot delete flood detected!" >&2
    fail=1
else
    echo "PASS: no find cannot delete flood (bootclean cleanly skipped live mounts)"
fi

if grep -a "Permission denied" "${LOG}"; then
    echo "FAIL: Permission denied error detected in log!" >&2
    fail=1
else
    echo "PASS: no Permission denied errors during session execution"
fi

if grep -a -i "cycle" "${LOG}" | grep -a -i "dependency"; then
    echo "FAIL: OpenRC dependency loop detected in log!" >&2
    fail=1
else
    echo "PASS: no OpenRC dependency loops detected"
fi

echo
echo "log: ${LOG}"
if [ "${STATUS}" -ne 0 ] || [ "${fail}" -ne 0 ]; then
    echo "QEMU smoke test FAILED (expect status ${STATUS})" >&2
    exit 1
fi
echo "QEMU smoke test PASSED"
