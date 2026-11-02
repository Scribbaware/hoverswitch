# HoverSwitch

One-click toggle for Windows' "Activate a window by hovering over it with the mouse", with your own hover delay.

- **ON**: hover-activate on + your hover delay (default 50 ms)
- **OFF**: hover-activate off + your normal delay restored

Handy when you play several game clients side by side (multiboxing): just move the mouse over a window to switch to it, then turn it off again for normal desktop use.

## Download

**[⬇ Download HoverSwitch.zip (latest release)](https://github.com/Scribbaware/hoverswitch/releases/latest/download/HoverSwitch.zip)**

All versions are on the [Releases page](https://github.com/Scribbaware/hoverswitch/releases). Windows 11 (recent Windows 10 builds work too), nothing to install.

## Install
1. [Download HoverSwitch.zip](https://github.com/Scribbaware/hoverswitch/releases/latest/download/HoverSwitch.zip), right-click it > Properties > tick **Unblock** > OK (do this before extracting, so Windows trusts the files).
2. Extract to a folder you keep, e.g. `Documents\HoverSwitch`.
3. Double-click `Start HoverSwitch.cmd`. A round mouse-pointer icon appears in the system tray (you may need to drag it out of the ^ overflow).

## Use
- **Left-click** the tray icon: switch ON/OFF (green = ON, grey = OFF).
- **Ctrl+Alt+H**: same toggle from anywhere, also in game.
- **Right-click**: pick a hover delay (0/25/50/100/200/500 ms), toggle **Bring hovered window to front** (on by default, like the Windows setting), Settings, Start with Windows, Exit.
- **Double-click** or Settings...: set any delay, the "normal" delay for OFF, the hotkey, and whether the hovered window also jumps to the front.
- "Turn OFF and exit" restores normal behaviour; "Exit (leave as is)" keeps the current state.

Settings are stored in `%APPDATA%\HoverSwitch\settings.json`. On first run the current Windows delay is saved as your "normal" delay.

## How it works
HoverSwitch changes the same settings as the Windows checkbox (Settings > Accessibility > Mouse pointer and touch / Ease of Access), through the `SystemParametersInfo` API:
`SPI_SETACTIVEWINDOWTRACKING` (hover to activate), `SPI_SETACTIVEWNDTRKTIMEOUT` (the delay, which Windows has no slider for) and `SPI_SETACTIVEWNDTRKZORDER` (bring to front).

It is a plain PowerShell script instead of an .exe, so you can read exactly what it does, and Windows Smart App Control does not block it as an unsigned program.

## License
MIT, see [LICENSE](LICENSE).
