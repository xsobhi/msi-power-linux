# msi-power-linux

MSI Center–style power modes for MSI laptops on Linux, with **automatic switching**:

- **On the charger:** MSI *Comfort* (balanced) + Linux `balanced` profile
- **On battery:** MSI *Eco* + *Super Battery* + Linux `power-saver` profile
- Plus a small **Power Mode** window (like MSI Center's "User Scenario") for manual presets,
  **graphics mode** (NVIDIA / Hybrid / Intel, applied after a restart), **fans** and **battery calibration**.

It's a thin automation layer on top of the [**msi-ec**](https://github.com/BeardOverflow/msi-ec) kernel driver
(not included, GPL-2.0, by BeardOverflow and contributors), which exposes the laptop's embedded-controller
settings. This repo does not touch the EC directly — it only writes msi-ec's sysfs files and calls
`powerprofilesctl`.

Tested on an **MSI Katana 15 B13VFK** (EC firmware `1585EMS1.115`), Linux Mint 22.3 (Cinnamon), kernel 7.0.

## Presets

| Preset | MSI shift mode | Super Battery | Fans | Cooler Boost | Linux profile |
|---|---|---|---|---|---|
| Extreme Performance | turbo | off | auto | off | performance |
| Extreme + Cooler Boost | turbo | off | auto | **on** (max fans, loud) | performance |
| Balanced | comfort | off | auto | off | balanced |
| Silent | eco | off | silent | off | balanced |
| Super Battery | eco | on | auto | off | power-saver |
| **Automatic** (default) | comfort / eco | off / on | auto | off | balanced / power-saver |

When the charger is plugged in or unplugged you get a desktop notification saying which mode it switched to
(or that your manual mode was kept).

A manual preset sticks until you pick **Automatic** or reboot — plugging/unplugging the charger won't
override it. After a reboot it always starts in Automatic, so you can't get stuck in a loud/hot mode.

On our Katana, Cooler Boost ran the fans at ~6,600 / 5,900 RPM vs ~4,000–4,500 RPM on the auto curve
while gaming (CPU at 94 °C), and raised average CPU clocks by ~8 %.

## Battery calibration

Click **Battery calibration…** in Power Mode to drain the battery fully so its charge gauge re-learns its capacity.
It turns off everything that would otherwise sleep/hibernate the laptop before the battery is empty:

- Cinnamon's critical-battery action, idle sleep on battery and lid-close sleep on battery (saved and restored)
- UPower, whose own `CriticalPowerAction` (e.g. HybridSleep at 2 %) can't be disabled — it is stopped and
  runtime-masked, so it comes back by itself on the next boot

Steps: charge to 100 % (leave it plugged in ~1 hour more), start calibration, unplug and use the laptop until it
shuts off, leave it off a few hours, then charge to 100 % without interrupting. At the next login your settings
are restored automatically and a notification tells you to charge. To cancel early, pick **Stop battery calibration**.
The battery icon is blank while calibrating. Calibration fixes the percentage reading, not battery wear.

The calibration page shows live charge, power draw and battery health, ticks off the steps, and has options:
don't sleep when idle / when the lid is closed (on by default), keep the screen on, and drain faster
(switches to Extreme Performance; your previous mode comes back afterwards).

## Fans

**Fans…** in Power Mode shows live CPU/GPU temperature and fan RPM and lets you set:

- **Fan mode** — Auto, Silent, or Advanced (the custom curve stored in the EC by MSI Center on Windows; without
  one it acts like Auto)
- **Cooler Boost** — fans at maximum
- **Auto Cooler Boost** — `msi-fan-autoboost.service` turns Cooler Boost on when the CPU or GPU reaches a
  temperature you pick (default 90 °C) and off again below another (default 80 °C). It only switches off a boost
  it turned on itself, so a manual boost or *Extreme + Cooler Boost* is left alone. Off by default.

Picking a preset (or a charger switch in Automatic) sets fan mode and Cooler Boost back to the preset's values.
Custom fan curves aren't offered: msi-ec has no curve interface for these firmwares, and with Secure Boot the
kernel blocks raw EC writes anyway.

## Graphics mode

The three buttons under the presets switch the PRIME GPU mode with `prime-select` (needs `nvidia-prime`):
**NVIDIA** (everything on the dGPU), **Hybrid** (`on-demand`) or **Intel** (dGPU off). It takes effect after a
restart; until then the window says which mode is running and offers **Restart now**. It never switches by itself.

## Requirements

1. **msi-ec** with support for your EC firmware. The version shipped in the kernel may be too old — check:
   ```sh
   sudo modprobe msi_ec; sudo dmesg | grep msi_ec     # "Firmware version is not supported" = too old
   ls /sys/devices/platform/msi-ec                      # should list shift_mode, super_battery, ...
   ```
   If unsupported, install the upstream version (DKMS): see the [msi-ec README](https://github.com/BeardOverflow/msi-ec).
   With **Secure Boot** on, DKMS signs the module with your local MOK key — enroll it once
   (`sudo mokutil --import /var/lib/shim-signed/mok/MOK.der`, reboot, "Enroll MOK").
2. `power-profiles-daemon` (`powerprofilesctl`), `python3-gi` + `gir1.2-gtk-3.0` and `libnotify-bin` (`notify-send`).
   Optional: `nvidia-prime` (`prime-select`) for the Graphics buttons.

## Install

```sh
git clone https://github.com/xsobhi/msi-power-linux.git
cd msi-power-linux
sudo ./install.sh              # add --lid-rule to also install the lid rule (below)
```

Then open **Power Mode** from the app menu (or run `power-mode`). To put it on the desktop:
`cp /usr/share/applications/power-mode*.desktop ~/Desktop/` and mark them trusted.

Command line: `sudo msi-power-set extreme|extremeboost|balanced|silent|superbattery|auto`
(`gpu nvidia|on-demand|intel` switches the GPU mode; `fan auto|silent|advanced`, `boost on|off` and
`autoboost ON OFF|off` control the fans; `calibrate` / `calibrate-off` only stop/start UPower — use the window for calibration, it also handles the Cinnamon settings)

## How it works

| File | Role |
|---|---|
| `/usr/local/bin/msi-power-auto` | applies the charger/battery mode (skipped while a manual preset is active) |
| `/usr/local/bin/msi-power-set` | applies a named preset; only accepts the fixed names above |
| `/usr/local/bin/power-mode` | GTK window: presets, graphics mode, battery calibration; notifications |
| `/etc/xdg/autostart/battery-calibration-restore.desktop` | at login, restores low-battery settings after a calibration run |
| `/etc/udev/rules.d/99-msi-power-auto.rules` | re-applies on charger plug/unplug (any `Mains` power supply) and notifies logged-in desktop sessions |
| `msi-power-auto.service` | applies at boot |
| `msi-fan-autoboost.service` + `/usr/local/bin/msi-fan-autoboost` | *optional* Auto Cooler Boost (settings in `/etc/msi-power/autoboost.conf`) |
| `/usr/lib/systemd/system-sleep/msi-power-auto` | re-applies after resume |
| `/etc/sudoers.d/msi-power` | lets *your* user run `msi-power-set` (and nothing else) without a password |
| `/etc/polkit-1/rules.d/60-lid-close-always-suspend.rules` | *optional* (`--lid-rule`): closing the lid always suspends, even if a background process holds a sleep inhibitor |

Logs: `journalctl -t msi-power-auto`

The **lid rule** exists because a root-owned sleep inhibitor once kept our laptop awake — and hot — in a
bag for an hour: Cinnamon tried to force-suspend on lid close but polkit denied `suspend-ignore-inhibit`.

## Uninstall

```sh
sudo ./uninstall.sh
```

## Notes

- Battery charge thresholds are intentionally not managed (msi-ec exposes them if you want a limit).
- Not affiliated with MSI. Writing EC settings is done only through msi-ec's supported sysfs interface for
  your firmware — if msi-ec doesn't support your model, don't force it.
