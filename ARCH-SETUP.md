# Arch Linux setup for this Quickshell bar

This guide assumes a fresh Arch Linux install running Hyprland on Wayland. The
bar is the QML configuration in this directory and is normally started with
Quickshell.

## Install the required packages

Install the base compositor, shell, font, launcher, audio, network, Bluetooth,
clipboard, and notification packages:

```bash
sudo pacman -Syu
sudo pacman -S \
  hyprland hyprlock quickshell \
  networkmanager network-manager-applet nm-connection-editor \
  bluez bluez-utils blueman \
  pipewire pipewire-pulse wireplumber pavucontrol \
  rofi \
  cliphist wl-clipboard \
  libnotify \
  ttf-jetbrains-mono-nerd \
  xdg-desktop-portal-hyprland polkit-gnome
```

Package availability can change between Arch repositories. If `quickshell` is
not available in the enabled repositories, install the current Arch package
from the official Arch package sources or build it from the AUR using your
preferred AUR helper. Do not install multiple competing Quickshell builds at
the same time.

### What each group is for

| Package(s) | Used by |
| --- | --- |
| `hyprland` | The Wayland compositor expected by the bar |
| `quickshell` | Runs the QML shell |
| `hyprlock` | Lock action in the power menu |
| `networkmanager`, `network-manager-applet` | `nmcli` status polling and the tray network menu (`nm-applet`) |
| `nm-connection-editor` | Network editor launched from the bar |
| `bluez`, `bluez-utils`, `blueman` | Bluetooth backend, tools, and the Bluetooth manager |
| `pipewire`, `pipewire-pulse`, `wireplumber` | Audio backend used by Quickshell |
| `pavucontrol` | Mixer opened from the volume control |
| `rofi` | Application launcher opened by the top-left button |
| `cliphist`, `wl-clipboard` | Clipboard history and restoring clipboard entries |
| `libnotify` | Provides `notify-send` for testing notifications |
| `ttf-jetbrains-mono-nerd` | The `JetBrainsMono Nerd Font` used for text and glyph icons |
| `xdg-desktop-portal-hyprland` | Desktop integration for Wayland applications |
| `polkit-gnome` | Authentication prompts for privileged desktop actions |

`awk`, `grep`, `head`, `free`, `pgrep`, `sh`, and `systemctl` are provided by
the normal Arch base system and are used by the QML processes.

## Enable the system services

```bash
sudo systemctl enable --now NetworkManager.service
sudo systemctl enable --now bluetooth.service
```

PipeWire and WirePlumber normally start automatically as user services. Check
that they are running after logging into Hyprland:

```bash
systemctl --user status pipewire pipewire-pulse wireplumber
```

Start a polkit agent in the Hyprland session. Add this to your Hyprland
configuration if one is not already started elsewhere:

```ini
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1
```

## Install and start the bar

Keep this directory at `/etc/xdg/quickshell/waybar-qs`, or copy it to a
user-owned directory if you want to edit it without root permissions. Start it
from a terminal to see QML errors:

```bash
qs -p /etc/xdg/quickshell/waybar-qs/shell.qml
```

To start it with Hyprland, add an `exec-once` line to `~/.config/hypr/hyprland.conf`:

```ini
exec-once = qs -p /etc/xdg/quickshell/waybar-qs/shell.qml
```

Restart Hyprland or reload its configuration after adding the line.

## Configure commands in `Theme.qml`

The bar launches these commands from `Theme.qml`:

```qml
launcherCmd: ["rofi", "-show", "drun"]
mixerCmd: ["pavucontrol"]
btManagerCmd: ["blueman-manager"]
netEditorCmd: ["nm-connection-editor"]
```

Those work with the packages above. The settings button is configured as:

```qml
settingsCmd: ["hyprmod"]
```

`hyprmod` is not a standard dependency of this bar. Install the program that
provides it, or change that command to your own settings application, for
example `pavucontrol`, `nm-connection-editor`, or a local script.

The logout action also tries `hyprshutdown` first and falls back to a Hyprland
dispatch command. If `hyprshutdown` is not installed, the fallback is expected.

## Wallpaper setup

The built-in wallpaper picker does not need `swww`, `awww`, or `hyprpaper`: it
renders images itself. Put supported images in:

```text
~/Pictures/Wallpapers/
```

Supported extensions are `.jpg`, `.jpeg`, `.png`, `.webp`, and `.bmp`.

If an external wallpaper daemon is preferred, set `renderBackground: false` in
`Wallpaper.qml` and configure `applyCmd` or `postCmd` there.

## Where the icons come from

Most icons visible in the bar are **not image files**. They are Unicode glyphs
from `JetBrainsMono Nerd Font`, installed by `ttf-jetbrains-mono-nerd`:

- Network, volume, clipboard, and other status symbols are glyph strings in
  `Bar.qml` and related QML files.
- Power-menu symbols are the Font Awesome-compatible glyphs in `PowerMenu.qml`.
- The font family is configured in `Theme.qml` and repeated in the notification
  and wallpaper components.

There are three sources for actual image icons:

1. **System tray icons:** `Bar.qml` reads `trayItem.modelData.icon`. These are
   supplied by running tray applications such as `nm-applet` or Blueman.
2. **Notification icons:** `Notification.qml`, `NotificationList.qml`, and
   `NotificationPopups.qml` call `Quickshell.iconPath(...)`. Quickshell resolves
   the application icon name through the installed desktop icon themes.
3. **Wallpaper images:** `Wallpaper.qml` loads the image files from
   `~/Pictures/Wallpapers/`. The `hyprland.svg` file in this directory is not
   the source of the bar's normal status glyphs.

If glyphs show as empty squares, confirm that the font is installed and restart
Quickshell. If application icons are missing, install an icon theme and set it
in the desktop environment, for example:

```bash
sudo pacman -S papirus-icon-theme
```

The bar itself does not bundle a separate icon pack.

## Quick checks

```bash
nmcli device status
bluetoothctl show
wpctl status
notify-send "Quickshell" "Notifications are working"
printf 'clipboard test\n' | wl-copy
cliphist list
fc-match 'JetBrainsMono Nerd Font'
```

If networking works but its tray menu is absent, check that `nm-applet` is
running and that the system tray is enabled in the session. If Bluetooth works
but no adapter appears, check the adapter and `bluetooth.service` with
`bluetoothctl show` and `systemctl status bluetooth`.