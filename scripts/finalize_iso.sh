#!/bin/bash
set -euo pipefail

HERE="/home/foxos/foxoos"
ISO="${HERE}/foxoos-0.1.0-alpha-amd64.iso"
ISO_LEGACY="${HERE}/foxoos-1.0-amd64.iso"
HYBRID="${HERE}/foxoos-0.1.0-alpha-amd64.hybrid.iso"

echo "=== 1. Copying squashfs to iso_root ==="
cp -f /tmp/filesystem.squashfs "${HERE}/iso_root/live/filesystem.squashfs"

echo "=== 2. Updating sha256sum.txt in iso_root ==="
cd "${HERE}/iso_root"
find . -type f ! -name sha256sum.txt ! -name sha256sum.README | sort | xargs sha256sum > sha256sum.txt

echo "=== 3. Assembling hybrid ISO with xorriso ==="
cd "${HERE}"
rm -f "${ISO}" "${HYBRID}" "${ISO_LEGACY}"
xorriso -as mkisofs \
    -R -r -J -joliet-long -l -iso-level 3 \
    --grub2-boot-info --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -A "FoxoOS 0.1.0-alpha" -p "FoxoOS build" -publisher "FoxoOS" -V "FOXOOS" \
    --modification-date=2026111519314200 \
    -c boot.catalog \
    -b boot/grub/grub_eltorito \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot -isohybrid-gpt-basdat \
    -o "${ISO}" \
    iso_root

cp -f "${ISO}" "${HYBRID}"
cp -f "${ISO}" "${ISO_LEGACY}"
sha256sum "${ISO}" | tee "${ISO}.sha256"
sha256sum "${ISO_LEGACY}" | tee "${ISO_LEGACY}.sha256"
echo "=== ISO built successfully: $(ls -lh "${ISO}") ==="
