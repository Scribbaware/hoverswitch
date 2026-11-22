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

## Auto-click (WoW only)
Made for creating a character on a full realm, where **Finish** keeps failing on the population limit. Hover the mouse over the Finish button and let HoverSwitch retry it for you.

- **F8** (or right-click > **Auto-click**): start/stop. It clicks once right away, then every 2 minutes.
- It only clicks while a WoW window (`WowClassic.exe`, `Wow.exe`, ...) is in the foreground. If a click is due while you are in another window, it waits and clicks as soon as WoW is in front again.
- It clicks wherever the mouse is at that moment, so leave the mouse on the button.
- 3 seconds after each click it presses **Enter**, which closes the "This faction is currently unavailable ... population imbalance" dialog so the next try can start. Set the delay (or 0 to turn it off) in Settings.
- **Stops by itself on success.** Before pressing Enter it checks the middle of the WoW window for the red **Okay** button of the error dialog. Dialog there: the try failed, so it presses Enter. No dialog: the character was created, so it does **not** press Enter; it stops, plays a sound and shows a balloon. This works in windowed and borderless (windowed fullscreen) mode; if the screen can't be read it just presses Enter. You can turn this check off in Settings.
- While it runs, the tray icon gets an **orange dot**, and the tooltip / menu show "next in 1:23" or "waiting for WoW". You get a balloon when it starts and stops.
- Settings: the interval (seconds), the Enter delay, the stop-on-change check and the hotkey (`F8`, `Ctrl+F8`, `None`, ...). Note that HoverSwitch takes the hotkey for itself, so F8 no longer reaches WoW or other apps while HoverSwitch runs. Pick another key if you use F8.

Heads-up: Blizzard's rules forbid automating input in the game, so use this at your own risk.

Settings are stored in `%APPDATA%\HoverSwitch\settings.json`. On first run the current Windows delay is saved as your "normal" delay.

## How it works
HoverSwitch changes the same settings as the Windows checkbox (Settings > Accessibility > Mouse pointer and touch / Ease of Access), through the `SystemParametersInfo` API:
`SPI_SETACTIVEWINDOWTRACKING` (hover to activate), `SPI_SETACTIVEWNDTRKTIMEOUT` (the delay, which Windows has no slider for) and `SPI_SETACTIVEWNDTRKZORDER` (bring to front).

It is a plain PowerShell script instead of an .exe, so you can read exactly what it does, and Windows Smart App Control does not block it as an unsigned program.

## License
MIT, see [LICENSE](LICENSE).
