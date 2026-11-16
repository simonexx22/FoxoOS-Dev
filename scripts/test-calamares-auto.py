import socket
import time
import subprocess
import os
import sys
import struct
import zlib

MON_SOCK = "/tmp/qemu-mon.sock"
SERIAL_SOCK = "/tmp/qemu-serial.sock"
ISO_PATH = "/home/foxos/foxoos/foxoos-1.0-amd64.iso"
DISK_PATH = "/tmp/test_sata.raw"

for s in [MON_SOCK, SERIAL_SOCK]:
    if os.path.exists(s):
        try: os.remove(s)
        except: pass

print("Truncating test disk to 20G...")
with open(DISK_PATH, "wb") as f:
    f.truncate(20 * 1024 * 1024 * 1024)

cmd = [
    "qemu-system-x86_64",
    "-name", "FoxoOS-installer",
    "-machine", "pc,accel=tcg",
    "-m", "2048", "-smp", "2",
    "-cdrom", ISO_PATH,
    "-device", "ahci,id=ahci",
    "-drive", f"file={DISK_PATH},format=raw,id=satadisk,if=none",
    "-device", "ide-hd,drive=satadisk,bus=ahci.0",
    "-boot", "d",
    "-nic", "user,model=e1000",
    "-display", "vnc=:93",
    "-monitor", f"unix:{MON_SOCK},server,nowait",
    "-serial", f"unix:{SERIAL_SOCK},server,nowait",
    "-no-reboot"
]

print("Launching QEMU with VNC :93...")
proc = subprocess.Popen(cmd)

def wait_for_sock(path, timeout=30):
    start = time.time()
    while time.time() - start < timeout:
        if os.path.exists(path):
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(path)
                return s
            except:
                pass
        time.sleep(0.5)
    raise TimeoutError(f"Socket {path} not ready")

def mon_cmd(sock, c):
    sock.sendall((c + "\n").encode())
    time.sleep(0.3)
    resp = b""
    while True:
        try:
            sock.settimeout(0.5)
            chunk = sock.recv(4096)
            if not chunk: break
            resp += chunk
            if b"(qemu)" in chunk: break
        except:
            break
    return resp.decode(errors='replace')

def ppm_to_png(ppm_path, png_path):
    if not os.path.exists(ppm_path): return
    with open(ppm_path, "rb") as f:
        magic = f.readline().strip()
        line = f.readline().strip()
        while line.startswith(b"#"):
            line = f.readline().strip()
        width, height = map(int, line.split())
        maxval = int(f.readline().strip())
        raw_data = f.read()

    raw_rows = []
    row_bytes = width * 3
    for y in range(height):
        raw_rows.append(b"\x00" + raw_data[y*row_bytes:(y+1)*row_bytes])
    compressed = zlib.compress(b"".join(raw_rows))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", compressed)
    png += chunk(b"IEND", b"")

    with open(png_path, "wb") as f:
        f.write(png)

time.sleep(2)
mon = wait_for_sock(MON_SOCK, 30)
mon_cmd(mon, "") # banner
ser = wait_for_sock(SERIAL_SOCK, 30)

print("Waiting for login prompt...")
buf = ""
ser.settimeout(1.0)
start = time.time()
while time.time() - start < 180:
    try:
        data = ser.recv(1024).decode(errors='replace')
        if data:
            buf += data
            if "foxoos login:" in buf:
                break
    except socket.timeout:
        pass

print("Logging in...")
ser.sendall(b"foxos\n")
buf = ""
start = time.time()
while time.time() - start < 15:
    try:
        data = ser.recv(1024).decode(errors='replace')
        if data:
            buf += data
            if "Password:" in buf:
                break
    except socket.timeout:
        pass

ser.sendall(b"live\n")
time.sleep(3)

print("Waiting for X0...")
ser.sendall(b"while ! test -e /tmp/.X11-unix/X0; do sleep 1; done; echo X0_READY\n")
buf = ""
start = time.time()
while time.time() - start < 30:
    try:
        data = ser.recv(1024).decode(errors='replace')
        if data:
            buf += data
            if "X0_READY" in buf:
                break
    except socket.timeout:
        pass

print("Launching Calamares...")
ser.sendall(b"DISPLAY=:0 sudo -E /usr/bin/calamares -d > /tmp/calamares.log 2>&1 &\n")
time.sleep(12)

print("Calamares started. Capturing Welcome screen...")
mon_cmd(mon, "screendump /tmp/calamares_welcome.ppm")
ppm_to_png("/tmp/calamares_welcome.ppm", "/tmp/calamares_welcome.png")

ser.sendall(b"sudo poweroff -f\n")
proc.wait(30)
print("Finished!")
