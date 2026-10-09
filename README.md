# PS5 MT7921 Wi-Fi for ps5-linux

Enables the internal Wi-Fi on PS5 consoles that ship with a **MediaTek MT7921**
chip (`14c3:7961`) when running [ps5-linux](https://github.com/ps5-linux).

The existing [ps5-linux-mwifiex](https://github.com/ps5-linux/ps5-linux-mwifiex)
driver only supports consoles with the NXP IW620 chip. On MT7921 consoles it
loads but finds no device.

## Is this your console?

```
lspci -nn | grep -i network
```

If the output contains `MEDIATEK Corp. MT7921 ... [14c3:7961]`, this is for you.

## What it does

No driver source is modified. The mainline `mt7921e` driver already supports
this chip; the ps5-linux kernel config just leaves `CONFIG_MT7921E` switched
off (everything it depends on is already built as modules, and the firmware is
already in `linux-firmware`).

`install.sh` builds that single missing module against your running kernel:

1. Clones the matching Linux stable tag and the matching `ps5-linux-patches` tag.
2. Applies the PS5 patch and your running kernel's config, with `CONFIG_MT7921E=m`.
3. Reuses the installed `Module.symvers` so symbol versions match.
4. Builds only `drivers/net/wireless/mediatek/mt76/mt7921`.
5. Installs `mt7921e.ko`, runs `depmod`, and loads it.

## Install

```
git clone https://github.com/mastersword64/ps5-linux-mt7921e
cd ps5-linux-mt7921e
./install.sh
```

Then connect:

```
nmcli device wifi list
sudo nmcli device wifi connect "NETWORK_NAME" --ask
```

If you previously installed the NXP driver, remove it first
(`sudo ./install.sh uninstall` in the `ps5-linux-mwifiex` folder).

### Options

| Variable | Purpose | Default |
| --- | --- | --- |
| `WORKDIR` | Where sources are cloned and built | `~/.cache/ps5-mt7921e` |
| `PATCHES_REF` | Tag or commit of `ps5-linux-patches` | newest `kernel-<version>-*` tag |

## Uninstall

```
./install.sh uninstall
```

## Tested on

| Console model | PS5 firmware | Distro | Kernel | Result |
| --- | --- | --- | --- | --- |
| CFI-1215a (fill in) | 6.02 (fill in) | Ubuntu 26.04.1 | 7.1.7 | fill in |

Driver output on the tested console:

```
mt7921e 0000:40:00.7: ASIC revision: 79610010
mt7921e 0000:40:00.7: HW/SW Version: 0x8a108a10, Build Time: 20260224110909a
```

## Known limitations

- The module must be rebuilt after every kernel update (re-run `install.sh`).
- Bluetooth is not covered.
- Not tested with other kernel versions or distros. Reports welcome.

## The proper fix

This repo is a stopgap. The real fix is one line in the ps5-linux kernel
config (`CONFIG_MT7921E=m`), after which no separate build is needed.

## Credits

- [ps5-linux](https://github.com/ps5-linux) for the loader, kernel patches and image builder.
- The Linux `mt76` driver authors.

## License

The script in this repository is released under GPL-2.0. It downloads and
builds unmodified Linux kernel source, which is under its own license.
