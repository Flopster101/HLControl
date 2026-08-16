# Build Scripts

This directory contains build automation scripts for HLControl across Linux, Android, and Windows.

---

## Building Windows on Linux (Headless KVM / Vagrant)

Windows builds can be created directly on Linux without a separate Windows machine using a minimal headless Windows Server Core VM managed by Vagrant and KVM/libvirt.

### 1. Host Prerequisites

Install Vagrant, QEMU, OVMF firmware, and the libvirt provider plugin:

#### Arch / CachyOS / Manjaro:
```bash
sudo pacman -S vagrant qemu-desktop qemu-system-x86 edk2-ovmf dnsmasq openbsd-netcat
vagrant plugin install vagrant-libvirt
```

#### Ubuntu / Debian:
```bash
sudo apt install vagrant qemu-kvm libvirt-daemon-system ovmf dnsmasq netcat-openbsd
vagrant plugin install vagrant-libvirt
```

### 2. User & Service Setup

1. Add your user to the `libvirt` and `kvm` groups and enable `libvirtd`:
   ```bash
   sudo usermod -aG libvirt,kvm $USER
   sudo systemctl enable --now libvirtd
   ```

2. (Optional) To avoid GUI password prompts from Polkit during builds, add a Polkit rule:
   ```bash
   sudo tee /etc/polkit-1/rules.d/49-libvirt.rules << 'EOF'
   polkit.addRule(function(action, subject) {
       if (action.id == "org.libvirt.unix.manage" && subject.isInGroup("libvirt")) {
           return polkit.Result.YES;
       }
   });
   EOF
   ```

3. (Optional) If your root filesystem is on a faster drive (e.g. SSD) and `/home` is on HDD, you can point Vagrant's storage directory to the SSD:
   ```bash
   export VAGRANT_HOME="/var/lib/vagrant.d"
   ```

---

## Usage

### Windows Build

From the repository root:

```bash
# Build dev release with git hash in filename (default)
./scripts/build_windows.sh

# Build clean release
./scripts/build_windows.sh --release

# Re-run VM provisioning (Chocolatey / Flutter / VS Build Tools)
./scripts/build_windows.sh --provision

# Clean and destroy existing VM before building
./scripts/build_windows.sh --clean
```

On native Windows machines, you can run `.\scripts\build_windows.ps1` directly in PowerShell.

---

### Other Targets

- **Linux**: `./scripts/build_linux.sh` (or `--appimage`, `--arch`, `--all`)
- **Android**: `./scripts/build_android.sh` (or `--release`, `--bundle`, `--universal`)
