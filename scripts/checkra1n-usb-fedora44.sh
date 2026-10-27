#!/usr/bin/env bash
# Fedora 44 preparation for bootra1n 0.10.1 (checkra1n 0.10.1 beta).
# Never flash, format, partition, mount, or modify an attached USB drive.
set -euo pipefail

readonly ISO_NAME="bootra1n-x86_64-0.10.1-20200408.iso"
readonly ISO_URL="https://github.com/foxlet/bootra1n/releases/download/0.10.1/${ISO_NAME}"
readonly ISO_DIR="${HOME}/Downloads/checkra1n-usb"
readonly ISO="${ISO_DIR}/${ISO_NAME}"

usage() {
  cat <<'HELP'
Usage: bash scripts/checkra1n-usb-fedora44.sh [--check | --install | --download | --verify-usb /dev/sdX]
  --check               List host tools and USB disks (read-only; default)
  --install             Install Fedora ISO-writing / USB-inspection tools
  --download            Download ONLY the pinned bootra1n 0.10.1 ISO
  --verify-usb /dev/sdX Read-only comparison of unmounted USB disk with ISO
  --help                Show this help

The script NEVER flashes a disk or installs checkra1n on Fedora.
Writing with KDE ISO Image Writer ERases the ENTIRE selected USB stick.
HELP
}

check() {
  printf '%s\n' '== Fedora host USB preflight (read-only) =='
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    printf 'Operating system: %s\n' "${PRETTY_NAME:-unknown}"
  fi
  printf 'Architecture: %s\n' "$(uname -m)"
  [[ "$(uname -m)" == x86_64 ]] || printf '%s\n' 'WARNING: this ISO is for x86_64 hardware.'
  if [[ -d /sys/firmware/efi ]]; then
    printf '%s\n' 'Boot: UEFI. Check firmware support for this older ISO.'
  else
    printf '%s\n' 'Boot: BIOS/legacy or UEFI status unavailable.'
  fi
  for cmd in isoimagewriter lsblk lsusb curl sha256sum cmp; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '%-16s OK\n' "$cmd"
    else
      printf '%-16s missing\n' "$cmd"
    fi
  done
  if command -v lsblk >/dev/null 2>&1; then
    printf '\n%s\n' 'All disks. Identify your USB by MODEL, SIZE and TRAN:'
    lsblk -d -o NAME,SIZE,TRAN,RM,RO,MODEL
  fi
  if command -v lsusb >/dev/null 2>&1; then
    printf '\n%s\n' 'USB bus devices:'
    lsusb
  fi
  if [[ -f "$ISO" ]]; then
    printf '\nDownloaded image:\n'
    sha256sum -- "$ISO"
    printf '%s\n' 'This hash alone does NOT authenticate the download.'
  else
    printf '\nISO not downloaded: %s\n' "$ISO"
  fi
}

install_tools() {
  [[ -f /etc/fedora-release ]] || { printf '%s\n' 'Fedora host required.' >&2; exit 1; }
  sudo dnf install -y isoimagewriter usbutils udisks2 curl coreutils util-linux
  printf '%s\n' 'Fedora host tools installed. checkra1n was NOT installed here.'
}

download_iso() {
  command -v curl >/dev/null 2>&1 || { printf '%s\n' 'Install curl first.' >&2; exit 1; }
  mkdir -p -- "$ISO_DIR"
  if [[ -f "$ISO" ]]; then
    printf 'ISO already exists: %s\n' "$ISO"
    sha256sum -- "$ISO"
    return
  fi
  local tmp
  tmp=$(mktemp "${ISO_DIR}/.bootra1n.XXXXXXXX")
  trap 'rm -f -- "$tmp"' EXIT
  curl --fail --location --retry 3 --proto '=https' --tlsv1.2 --output "$tmp" "$ISO_URL"
  if (( $(stat -c %s -- "$tmp") < 100000000 )); then
    printf '%s\n' 'Download unexpectedly small; refusing it.' >&2
    exit 1
  fi
  mv -- "$tmp" "$ISO"
  trap - EXIT
  sha256sum -- "$ISO"
  printf '%s\n' 'Download complete. Verify provenance and use KDE ISO Image Writer manually.'
}

verify_usb() {
  local disk="${1:-}" kind transport mounted bytes capacity
  [[ -n "$disk" ]] || { usage >&2; exit 2; }
  [[ -f "$ISO" ]] || { printf '%s\n' 'ISO missing: run --download first.' >&2; exit 1; }
  [[ -b "$disk" ]] || { printf 'Not a block device: %s\n' "$disk" >&2; exit 1; }
  kind=$(lsblk -dnro TYPE -- "$disk")
  transport=$(lsblk -dnro TRAN -- "$disk")
  if [[ "$kind" != disk || "$transport" != usb ]]; then
    printf '%s\n' 'Refusing to read: select a WHOLE USB disk (not a partition).' >&2
    exit 1
  fi
  mounted=$(lsblk -nrpo MOUNTPOINTS -- "$disk" | grep -v '^$' || true)
  [[ -z "$mounted" ]] || { printf 'Unmount USB partitions first:\n%s\n' "$mounted" >&2; exit 1; }
  bytes=$(stat -c %s -- "$ISO")
  capacity=$(lsblk -bdnro SIZE -- "$disk")
  (( capacity >= bytes )) || { printf '%s\n' 'USB smaller than ISO.' >&2; exit 1; }
  printf 'Comparing first %s bytes on %s (READ ONLY)...\n' "$bytes" "$disk"
  sudo cmp -n "$bytes" -- "$ISO" "$disk"
  printf '%s\n' 'PASS: USB matches ISO byte-for-byte. A real boot test is still needed.'
}

case "${1:---check}" in
  --check) [[ $# -le 1 ]] || { usage >&2; exit 2; }; check ;;
  --install) [[ $# -eq 1 ]] || { usage >&2; exit 2; }; install_tools ;;
  --download) [[ $# -eq 1 ]] || { usage >&2; exit 2; }; download_iso ;;
  --verify-usb) [[ $# -eq 2 ]] || { usage >&2; exit 2; }; verify_usb "$2" ;;
  --help|-h) usage ;;
  *) usage >&2; exit 2 ;;
esac
