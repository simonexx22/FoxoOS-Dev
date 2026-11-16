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
    "-display", "none",
    "-monitor", f"unix:{MON_SOCK},server,nowait",
    "-serial", f"unix:{SERIAL_SOCK},server,nowait",
    "-no-reboot"
]

print("Launching QEMU for installation...")
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

time.sleep(2)
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

# Fix X11 access permissions so drive_calamares.py can access DISPLAY=:0
ser.sendall(b"DISPLAY=:0 XAUTHORITY=/home/foxos/.Xauthority xhost + 2>/dev/null || DISPLAY=:0 sudo xhost + 2>/dev/null || true\n")
time.sleep(1)

print("Writing driver script in guest...")
guest_script = '''cat << 'SCRIPT_EOF' > /tmp/drive_calamares.py
import ctypes
import time
import os
import sys

x11 = ctypes.CDLL("libX11.so.6")
xtst = ctypes.CDLL("libXtst.so.6")

# Find XAUTHORITY if needed
if "XAUTHORITY" not in os.environ and os.path.exists("/home/foxos/.Xauthority"):
    os.environ["XAUTHORITY"] = "/home/foxos/.Xauthority"

dpy = x11.XOpenDisplay(b":0")
if not dpy:
    print("Could not open display :0")
    sys.exit(1)

print("Successfully connected to X11 display :0!")

def click(x, y):
    print(f"Clicking at ({x}, {y})")
    xtst.XTestFakeMotionEvent(dpy, 0, int(x), int(y), 0)
    x11.XFlush(dpy)
    time.sleep(0.1)
    xtst.XTestFakeButtonEvent(dpy, 1, 1, 0)
    x11.XFlush(dpy)
    time.sleep(0.1)
    xtst.XTestFakeButtonEvent(dpy, 1, 0, 0)
    x11.XFlush(dpy)
    time.sleep(0.5)

def key(keysym_name):
    sym = x11.XStringToKeysym(keysym_name.encode())
    kc = x11.XKeysymToKeycode(dpy, sym)
    xtst.XTestFakeKeyEvent(dpy, kc, 1, 0)
    x11.XFlush(dpy)
    time.sleep(0.05)
    xtst.XTestFakeKeyEvent(dpy, kc, 0, 0)
    x11.XFlush(dpy)
    time.sleep(0.05)

def type_text(text):
    for ch in text:
        if ch.isupper() or ch in "!@#$%^&*()_+{}|:\\"<>?":
            shift_sym = x11.XStringToKeysym(b"Shift_L")
            shift_kc = x11.XKeysymToKeycode(dpy, shift_sym)
            xtst.XTestFakeKeyEvent(dpy, shift_kc, 1, 0)
            x11.XFlush(dpy)

            sym = x11.XStringToKeysym(ch.encode())
            kc = x11.XKeysymToKeycode(dpy, sym)
            xtst.XTestFakeKeyEvent(dpy, kc, 1, 0)
            x11.XFlush(dpy)
            xtst.XTestFakeKeyEvent(dpy, kc, 0, 0)
            x11.XFlush(dpy)

            xtst.XTestFakeKeyEvent(dpy, shift_kc, 0, 0)
            x11.XFlush(dpy)
        else:
            sym = x11.XStringToKeysym(ch.encode())
            kc = x11.XKeysymToKeycode(dpy, sym)
            xtst.XTestFakeKeyEvent(dpy, kc, 1, 0)
            x11.XFlush(dpy)
            xtst.XTestFakeKeyEvent(dpy, kc, 0, 0)
            x11.XFlush(dpy)
        time.sleep(0.05)

# Wait 2 seconds for focus
time.sleep(2)

# Next button is at (1008, 640)
print("1. Welcome page -> Next")
click(1008, 640)
time.sleep(2)

print("2. Locale page -> Next")
click(1008, 640)
time.sleep(2)

print("3. Keyboard page -> Next")
click(1008, 640)
time.sleep(2)

print("4. Partition page -> Next (Erase disk is default)")
click(1008, 640)
time.sleep(2)

print("5. Users page -> Fill fields")
# Click first input field (Name) around (550, 240)
click(550, 240)
time.sleep(0.5)
type_text("Foxo User")
time.sleep(0.2)
key("Tab")
time.sleep(0.2)
# username auto-populates or tab past it
key("Tab")
time.sleep(0.2)
# hostname
key("Tab")
time.sleep(0.2)
# password
type_text("FoxoOS!2026#Sec")
time.sleep(0.2)
key("Tab")
time.sleep(0.2)
# confirm password
type_text("FoxoOS!2026#Sec")
time.sleep(0.5)

print("Advancing past Users -> Summary")
click(1008, 640)
time.sleep(3)

print("6. Summary page -> Click Install")
click(1008, 640)
time.sleep(2)

# If confirmation dialog appears, press Enter
key("Return")
print("Installation triggered successfully!")
SCRIPT_EOF
'''

ser.sendall(guest_script.encode())
time.sleep(2)

print("Starting Calamares in guest...")
ser.sendall(b"DISPLAY=:0 XAUTHORITY=/home/foxos/.Xauthority sudo -E /usr/bin/calamares -d > /tmp/calamares.log 2>&1 &\n")

print("Waiting for requirements check...")
start = time.time()
while time.time() - start < 60:
    ser.sendall(b"grep -q 'All requirements have been checked' /tmp/calamares.log && echo CALAM_READY\n")
    time.sleep(2)
    buf = ""
    try:
        while True:
            chunk = ser.recv(1024).decode(errors='replace')
            if not chunk: break
            buf += chunk
            if "CALAM_READY" in buf:
                break
    except:
        pass
    if "CALAM_READY" in buf:
        break

print("Calamares ready! Running driver script...")
ser.sendall(b"DISPLAY=:0 XAUTHORITY=/home/foxos/.Xauthority python3 /tmp/drive_calamares.py\n")

print("Monitoring installation progress in /tmp/calamares.log...")
start = time.time()
finished = False
while time.time() - start < 600:
    ser.sendall(b"tail -n 15 /tmp/calamares.log\n")
    time.sleep(5)
    buf = ""
    try:
        while True:
            chunk = ser.recv(4096).decode(errors='replace')
            if not chunk: break
            buf += chunk
    except:
        pass
    sys.stdout.write(buf)
    sys.stdout.flush()
    if "Installation failed" in buf:
        print("\nERROR: Calamares installation failed!")
        break
    if "Installation finished" in buf or "Installation complete" in buf or "FinishedViewStep" in buf or "finish done" in buf:
        print("\nSUCCESS: Calamares installation finished!")
        finished = True
        break

if finished:
    print("Cleanly shutting down live VM...")
    ser.sendall(b"sudo poweroff -f\n")
    proc.wait(30)
    print("Ready to boot from installed disk!")
else:
    print("Installation did not finish in time or failed.")
    ser.sendall(b"sudo poweroff -f\n")
    proc.wait(30)
    sys.exit(1)
