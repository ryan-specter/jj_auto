# JJ Launcher ROM for Innioasis Y1

Flashable firmware images that boot directly into [JJ Launcher (MO-ON)](https://github.com/ismileblue/y1_launcher) on the Innioasis Y1 — no Rockbox, no stock `com.innioasis.y1` launcher, and no post-flash ADB steps.

## Downloads

Each [GitHub Release](https://github.com/ryan-specter/jj_auto/releases) matches an upstream JJ Launcher version (`launcher-v0.5`, `launcher-v0.3`, etc.) and includes:

- `rom.zip` — Type A (original Y1 stock firmware lineage)
- `rom_type_b.zip` — Type B (Y1 devices that shipped with stock firmware 3.0.7)

Release notes on each ROM build import the changelog from the matching [ismileblue/y1_launcher](https://github.com/ismileblue/y1_launcher/releases) release so you can pick the launcher version you want and read its original notes before flashing.

If unsure which type you need, try Type A first. Use Type B if Type A does not boot correctly on your device.

## What this ROM does

On first boot, an init script:

1. Installs the bundled JJ Launcher APK (`com.themoon.y1`) from `/data/jj_launcher.apk`
2. Disables any remaining stock or Rockbox launcher packages
3. Uses the stock Y1 hardware keymap (`Stock.kl` as `Generic.kl`)

No manual `adb install` or `pm disable` is required after flashing.

**Note:** JJ Launcher's upstream README mentions that full power-off behavior may require Rockbox. This ROM does not include Rockbox.

## Build locally

Requirements: `curl`, `unzip`, `zip`, `sudo` (for loop-mounting ext4 images).

```bash
# Latest upstream launcher
./scripts/build-rom.sh a
./scripts/build-rom.sh b

# Specific launcher release
./scripts/build-rom.sh a --launcher-tag v0.5 dist/v0.5/rom.zip
./scripts/build-rom.sh b --launcher-tag v0.5 dist/v0.5/rom_type_b.zip
```

The build script downloads:

- Stock base firmware from [rockbox-y1/rockbox](https://github.com/rockbox-y1/rockbox/releases) (`type-a-base` / `type-b-base`)
- The matching `app-release*.apk` from [ismileblue/y1_launcher](https://github.com/ismileblue/y1_launcher/releases)

List available launcher releases:

```bash
./scripts/list-launcher-releases.sh | python3 -m json.tool
```

## Installation

### MTKClient

1. Install [MTKClient](https://github.com/bkerler/mtkclient)
2. Open the GitHub Release for the launcher version you want and download `rom.zip` (Type A) or `rom_type_b.zip` (Type B)
3. Unpack the archive:

```bash
mkdir rom && cd rom
unzip ../rom.zip
```

4. Turn off the device and disconnect it from the PC
5. Start the flashing process:

```bash
python ../mtk.py w logo,uboot,bootimg,recovery,android,usrdata \
  logo.bin,lk.bin,boot.img,recovery.img,system.img,userdata.img
```

6. Connect the device via USB
7. Unplug when the process finishes
8. Power on — the device should boot into JJ Launcher

### SP Flash Tool

1. Download the ROM zip from the release for your chosen launcher version
2. Unpack the archive
3. Install SP Flash Tool v5.1904: https://spflashtool.com/download/
4. Follow the [official Innioasis Y1 flashing tutorial](https://support.innioasis.com/download/flashing_tutorial/Flashing_tutorial-Y1_EN%20v2.0.7-20241021.pdf), but use `MT6572_Android_scatter.txt` from the downloaded ROM zip

## CI builds

On each push to `main`/`master`, GitHub Actions:

1. Discovers every `app-release*.apk` release from `ismileblue/y1_launcher`
2. Builds Type A and Type B ROMs for each launcher version
3. Publishes one GitHub Release per launcher version with imported upstream changelog

## Repository layout

```
.github/workflows/build-roms.yml   CI pipeline
scripts/build-rom.sh               ROM repackaging + audit
scripts/list-launcher-releases.sh  Upstream release discovery
scripts/format-release-notes.sh    Release notes formatter
scripts/99Y1LauncherInit.sh        First-boot launcher setup
scripts/install-recovery.sh        Runs /system/etc/init.d at boot
scripts/Stock.kl                   Stock Y1 keymap
```

## License

`Stock.kl` is derived from the Android Open Source Project keylayout files. JJ Launcher is maintained separately at [ismileblue/y1_launcher](https://github.com/ismileblue/y1_launcher).
