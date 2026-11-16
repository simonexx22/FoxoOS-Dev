import socket
import time
import subprocess
import os
import sys

MON_SOCK = "/tmp/qemu-mon.sock"
SERIAL_SOCK = "/tmp/qemu-serial.sock"
ISO_PATH = "/home/foxos/foxoos/foxoos-1.0-amd64.iso"
DISK_PATH = "/tmp/test_sata.raw"

for s in [MON_SOCK, SERIAL_SOCK]:
    if os.path.exists(s):
        try: os.remove(s)
        except: pass

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
    "-display", "none",
    "-monitor", f"unix:{MON_SOCK},server,nowait",
    "-serial", f"unix:{SERIAL_SOCK},server,nowait",
    "-no-reboot"
]

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

time.sleep(2)
mon = wait_for_sock(MON_SOCK, 30)
mon_cmd(mon, "") # clear banner
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

print("Logging in properly...")
ser.sendall(b"foxos\n")
# Wait for Password: prompt
buf = ""
start = time.time()
while time.time() - start < 10:
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
# Read until prompt
try: ser.recv(4096)
except: pass

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

print("Calamares started. Checking log...")
ser.sendall(b"grep -i 'CalamaresWindow created' /tmp/calamares.log\n")
time.sleep(1)
try: print(ser.recv(4096).decode(errors='replace'))
except: pass

mon_cmd(mon, "screendump /tmp/step1.ppm")
print("Saved step1.ppm")

# Try sendkey alt-d to move to next page
print("Sending sendkey alt-d...")
mon_cmd(mon, "sendkey alt-d")
time.sleep(2)
mon_cmd(mon, "screendump /tmp/step2.ppm")
print("Saved step2.ppm")

ser.sendall(b"sudo poweroff -f\n")
proc.wait(30)
print("Test completed!")
