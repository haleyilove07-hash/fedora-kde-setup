# Fedora 44: checkra1n 0.10.1 beta on a separate bootable USB

The host is **Fedora 44 KDE**. **Do not install checkra1n on Fedora**. This workflow prepares a USB with the pinned community image **bootra1n 0.10.1**, containing **checkra1n 0.10.1 beta**. Older software may have firmware/USB-compatibility issues on newer computers.

Sources:
- checkra1n 0.10.1 beta official release notes: https://checkra.in/releases/0.10.1-beta
- bootra1n 0.10.1 third-party bootable ISO: https://github.com/foxlet/bootra1n/releases/tag/0.10.1
- KDE ISO Image Writer: https://apps.kde.org/isoimagewriter/

## 1. Prepare Fedora (safe; will not flash any USB)

```bash
sudo dnf upgrade --refresh
bash scripts/checkra1n-usb-fedora44.sh --check
bash scripts/checkra1n-usb-fedora44.sh --install
bash scripts/checkra1n-usb-fedora44.sh --download
```

`--install` installs only Fedora USB/ISO host utilities. `--download` downloads the **exact 0.10.1** ISO into `~/Downloads/checkra1n-usb/`. The script prints SHA-256 for your records. **It does not include an independently published official expected SHA-256, so matching only this locally calculated value does not establish authenticity.**

## 2. Flash with KDE ISO Image Writer

**CAUTION: Writing the image destroys existing files and partitions on the selected USB drive.** Back up the stick. First run:

```bash
lsblk -d -o NAME,SIZE,TRAN,RM,RO,MODEL
```

Double-check the intended USB stick by model and size, and distinguish it from your Fedora system disk. Launch KDE ISO Image Writer (`isoimagewriter`) from KDE's application menu. Select the ISO saved above, choose the **correct USB flash drive**, and write it. The script deliberately does not issue `dd`, format commands, or any automatic flash operation.

## 3. Verify the USB (optional, read-only)

Once writing finishes, safely remove/reinsert the USB and unmount its partitions. With the correct **whole-disk** path already confirmed (example `/dev/sdX`, *never* `/dev/sdX1`):

```bash
bash scripts/checkra1n-usb-fedora44.sh --verify-usb /dev/sdX
```

This checks that the first ISO-sized bytes of the USB match the ISO byte-for-byte without writing to the disk. It refuses a mounted device, a partition, or a drive not detected as USB. **This is not a boot test**. After verification, boot the PC from the USB in the firmware boot menu. The bootra1n instructions document login `anon` with password `voidlinux`, then `sudo checkra1n` for an owned/authorized supported device.

## UnlockTool and SamFw are separate Windows applications

These apps are **not installed by this Fedora script**, do not belong on the bootra1n stick, and are not fully supported natively under Fedora. Their Windows USB drivers, COM-port and low-level flashing workflows cannot be reproduced simply by installing Wine. For reliable full functionality, use a supported real Windows installation rather than relying on a VM's USB passthrough.

SamFw official download/guide: https://samfw.com/blog/SAMFWTOOL

UnlockTool site: https://unlocktool.net/

For ordinary Linux-side USB diagnostics, use Fedora-supported tools and authorized device operations. Do not disable system security controls merely to load untrusted device drivers.
