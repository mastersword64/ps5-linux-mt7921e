#!/usr/bin/env bash
# Build and install the mainline mt7921e (MediaTek MT7921 PCIe) Wi-Fi module
# for a running PS5 Linux kernel that was built without CONFIG_MT7921E.
#
# Usage:
#   ./install.sh              build, install and load the module
#   ./install.sh uninstall    remove the installed module
#
# Optional environment variables:
#   WORKDIR      where sources are cloned and built (default: ~/.cache/ps5-mt7921e)
#   PATCHES_REF  tag or commit of ps5-linux-patches to use
#                (default: newest tag named kernel-<running version>-*)
set -euo pipefail

KVER="$(uname -r)"
WORKDIR="${WORKDIR:-$HOME/.cache/ps5-mt7921e}"
MODDIR="/lib/modules/$KVER/kernel/drivers/net/wireless/mediatek/mt76/mt7921"
SRCSUB="drivers/net/wireless/mediatek/mt76/mt7921"
KERNEL_GIT="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
PATCHES_GIT="https://github.com/ps5-linux/ps5-linux-patches"

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

if [ "${1:-}" = "uninstall" ]; then
    say "Removing mt7921e"
    sudo modprobe -r mt7921e 2>/dev/null || true
    sudo rm -f "$MODDIR/mt7921e.ko"
    sudo depmod -a
    echo "Done."
    exit 0
fi

[ "$(id -u)" -ne 0 ] || die "Run as a normal user; the script calls sudo when it needs to."
[ -f "/boot/config-$KVER" ] || die "/boot/config-$KVER not found."

if grep -q '^CONFIG_MT7921E=[ym]' "/boot/config-$KVER"; then
    echo "This kernel already has CONFIG_MT7921E. Try: sudo modprobe mt7921e"
    exit 0
fi
for opt in CONFIG_MT7921_COMMON CONFIG_MT792x_LIB CONFIG_MT76_CONNAC_LIB CONFIG_MAC80211; do
    grep -q "^$opt=[ym]" "/boot/config-$KVER" \
        || die "$opt is not enabled in this kernel; a full kernel rebuild is needed."
done

if ! lspci -nn 2>/dev/null | grep -qi '14c3:7961'; then
    echo "WARNING: no MT7921 (14c3:7961) found in lspci. Continuing anyway."
fi

if command -v apt-get >/dev/null; then
    say "Installing build dependencies"
    sudo apt-get install -y build-essential bc bison flex libssl-dev libelf-dev \
        libdw-dev dwarves git
fi

mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [ ! -d linux ]; then
    say "Cloning Linux v$KVER"
    git clone --depth 1 --branch "v$KVER" "$KERNEL_GIT" linux
fi
if [ ! -d ps5-linux-patches ]; then
    say "Cloning ps5-linux-patches"
    git clone "$PATCHES_GIT" ps5-linux-patches
fi

cd "$WORKDIR/ps5-linux-patches"
git fetch --tags --quiet || true
if [ -z "${PATCHES_REF:-}" ]; then
    PATCHES_REF="$(git tag --sort=-creatordate --list "kernel-$KVER-*" | head -n1)"
fi
[ -n "$PATCHES_REF" ] || die "No ps5-linux-patches tag for kernel $KVER. Set PATCHES_REF manually."
say "Using ps5-linux-patches at $PATCHES_REF"
git checkout --quiet "$PATCHES_REF"

cd "$WORKDIR/linux"
say "Preparing kernel source"
git checkout --quiet -- .
git clean -fdq
git apply ../ps5-linux-patches/linux.patch
cp "/boot/config-$KVER" .config
scripts/config --module MT7921E
make olddefconfig >/dev/null
touch .scmversion

BUILT_VER="$(make -s kernelrelease)"
[ "$BUILT_VER" = "$KVER" ] || die "Source reports '$BUILT_VER' but the running kernel is '$KVER'."

if [ -f "/lib/modules/$KVER/build/Module.symvers" ]; then
    cp "/lib/modules/$KVER/build/Module.symvers" .
elif grep -q '^CONFIG_MODVERSIONS=y' .config; then
    die "Kernel uses MODVERSIONS but /lib/modules/$KVER/build/Module.symvers is missing. Install the kernel headers package, or build the full tree with 'make -j\$(nproc)' in $WORKDIR/linux and re-run."
fi

say "Building mt7921e"
make -j"$(nproc)" modules_prepare
make -j"$(nproc)" M="$SRCSUB" modules
[ -f "$SRCSUB/mt7921e.ko" ] || die "Build finished but mt7921e.ko was not produced."

say "Installing"
sudo install -D -m 644 "$SRCSUB/mt7921e.ko" "$MODDIR/mt7921e.ko"
sudo depmod -a
sudo modprobe mt7921e

sleep 5
say "Driver messages"
sudo dmesg | grep -iE 'mt7921e' | tail -n 10 || true
say "Network devices"
command -v nmcli >/dev/null && nmcli device || ip link

echo
echo "Installed. The module loads automatically on boot."
echo "Re-run this script after every kernel update."
