# Współtworzenie FoxoOS (Contributing Guide)

Dziękujemy za zainteresowanie projektem **FoxoOS**! FoxoOS to lekka dystrybucja bazująca na **Debianie 13 (Trixie)** z **sysvinit-core (PID 1)** oraz **OpenRC** jako menedżerem usług, przeznaczona dla użytkowników ceniących tradycyjną architekturę uniksową i niezależność od monolitycznego menedżera systemd.

Niniejszy dokument opisuje zasady zgłaszania błędów, proponowania zmian oraz tworzenia Pull Requestów.

---

## 1. Kluczowe zasady architektoniczne

Każdy wkład do projektu musi być zgodny z fundamentalnymi założeniami FoxoOS:
1. **Brak menedżera systemd:** PID 1 to wyłącznie `sysvinit-core` (`/sbin/init`). Usługami zarządza **OpenRC** (`rc-service`, `rc-status`, `rc-update`). Polecenie `systemctl` nie może istnieć w systemie.
2. **Czysta baza Debiana:** Korzystamy wyłącznie z oficjalnych repozytoriów Debiana (`deb.debian.org`). Nie wprowadzamy repozytoriów Devuan ani nieoficjalnych forków pakietów.
3. **Dozwolone biblioteki zgodności:** Komponenty takie jak `libsystemd0`, `libsystemd-shared`, `udev`, `systemd-standalone-sysusers` oraz `systemd-standalone-tmpfiles` są dozwolone i wymagane przez nowoczesne pakiety Debiana, o ile nie pociągają za sobą menedżera systemd (`systemd-sysv`).
4. **Blokada pakietów (APT pinning):** Wszelkie próby instalacji `systemd`, `systemd-sysv` czy `libpam-systemd` muszą być blokowane przez reguły w `/etc/apt/preferences.d/`.
5. **Instalator Calamares:** Wszelkie skrypty i moduły instalatora muszą być w pełni kompatybilne z SysVinit/OpenRC (np. generowanie machine-ID przez D-Bus bez odwołań do `systemd-machine-id-setup`).

---

## 2. Zgłaszanie błędów (Bug Reports)

Przed zgłoszeniem problemu upewnij się, że nie został on już opisany w zakładce **Issues** na GitHubie.

### Co powinno zawierać zgłoszenie błędu:
- **Środowisko:** Wersja FoxoOS (np. `v0.1.0-alpha`), platforma testowa (VirtualBox, QEMU, KVM, czy fizyczny sprzęt) oraz parametry maszyny (RAM, CPU, typ kontrolera dysku: SATA/NVMe).
- **Kroki do odtworzenia:** Dokładny opis krok po kroku, co doprowadziło do błędu.
- **Oczekiwane vs. rzeczywiste zachowanie.**
- **Logi:**
  - W przypadku błędu instalatora: załącz `/var/log/calamares.log` lub wyjście terminala `calamares -d`.
  - W przypadku błędu rozruchu lub usług: wyjście `rc-status --all`, `dmesg` oraz `/var/log/boot`.

---

## 3. Zgłaszanie zmian (Pull Requests)

1. **Fork repozytorium:** Sforkuj oficjalne repozytorium FoxoOS do swojego konta i sklonuj je lokalnie:
   ```bash
   git clone https://github.com/<twoj-login>/FoxoOS.git
   cd FoxoOS
   ```
2. **Utwórz gałąź tematyczną:**
   ```bash
   git checkout -b fix/nazwa-poprawki
   # lub
   git checkout -b feature/nowa-funkcja
   ```
3. **Wprowadź i przetestuj zmiany:**
   - Jeśli modyfikujesz konfigurację obrazu Live, upewnij się, że zmiany są spójne w `config/includes.chroot/` oraz `system/`.
   - Zbuduj testowy obraz ISO lub uruchom skrypty weryfikacyjne w `scripts/`.
4. **Zatwierdź zmiany (Commits):**
   - Stosuj czytelne i zwięzłe opisy commitów (np. `fix(installer): correct machine-id generation under OpenRC`).
   - Nie dodawaj do commita plików binarnych ISO, obrazów dysków wirtualnych (`*.qcow2`, `*.vdi`), plików logów ani kluczy prywatnych.
5. **Otwórz Pull Request:**
   - Opisz cel zmian i powiąż go z odpowiednim numerem zgłoszenia (np. `Closes #12`).
   - Podaj informację, w jaki sposób zmiana została przetestowana.

---

## 4. Budowanie i środowisko deweloperskie

Szczegółowe instrukcje dotyczące instalacji narzędzi i kompilacji obrazu ISO znajdują się w pliku [README.md](README.md).
