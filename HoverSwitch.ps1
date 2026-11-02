# HoverSwitch - one-click toggle for Windows "Activate a window by hovering over it with the mouse"
# Tray app. Left-click the tray icon (or press the hotkey) to switch hover mode on/off.
#   ON : active window tracking on + your hover delay (default 50 ms)
#   OFF: active window tracking off + your normal delay restored
# Settings are kept in %APPDATA%\HoverSwitch\settings.json

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class HoverNative {
    [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
    static extern bool SpiSet(uint action, uint param, IntPtr value, uint flags);

    [DllImport("user32.dll", EntryPoint = "SystemParametersInfoW", SetLastError = true)]
    static extern bool SpiGet(uint action, uint param, ref int value, uint flags);

    const uint SPI_GETACTIVEWINDOWTRACKING = 0x1000;
    const uint SPI_SETACTIVEWINDOWTRACKING = 0x1001;
    const uint SPI_GETACTIVEWNDTRKZORDER   = 0x100C;
    const uint SPI_SETACTIVEWNDTRKZORDER   = 0x100D;
    const uint SPI_GETACTIVEWNDTRKTIMEOUT  = 0x2002;
    const uint SPI_SETACTIVEWNDTRKTIMEOUT  = 0x2003;
    const uint SAVE_AND_BROADCAST = 3; // SPIF_UPDATEINIFILE | SPIF_SENDCHANGE

    public static bool GetTracking() { int v = 0; SpiGet(SPI_GETACTIVEWINDOWTRACKING, 0, ref v, 0); return v != 0; }
    public static bool SetTracking(bool on) { return SpiSet(SPI_SETACTIVEWINDOWTRACKING, 0, (IntPtr)(on ? 1 : 0), SAVE_AND_BROADCAST); }

    public static bool GetRaise() { int v = 0; SpiGet(SPI_GETACTIVEWNDTRKZORDER, 0, ref v, 0); return v != 0; }
    public static bool SetRaise(bool on) { return SpiSet(SPI_SETACTIVEWNDTRKZORDER, 0, (IntPtr)(on ? 1 : 0), SAVE_AND_BROADCAST); }

    [DllImport("kernel32.dll")] static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hWnd, int cmd);
    public static void HideConsole() { IntPtr h = GetConsoleWindow(); if (h != IntPtr.Zero) ShowWindow(h, 0); }

    public static int GetDelay() { int v = 0; SpiGet(SPI_GETACTIVEWNDTRKTIMEOUT, 0, ref v, 0); return v; }
    public static bool SetDelay(int ms) { return SpiSet(SPI_SETACTIVEWNDTRKTIMEOUT, 0, (IntPtr)ms, SAVE_AND_BROADCAST); }
}

// Hidden window that receives a global hotkey (WM_HOTKEY).
public class HoverHotkey : NativeWindow, IDisposable {
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, uint mods, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    const int WM_HOTKEY = 0x0312;
    const uint MOD_NOREPEAT = 0x4000;
    bool registered;
    public event EventHandler Pressed;

    public HoverHotkey() { CreateHandle(new CreateParams()); }

    public bool Register(uint mods, uint vk) {
        Unregister();
        registered = RegisterHotKey(Handle, 1, mods | MOD_NOREPEAT, vk);
        return registered;
    }
    public void Unregister() { if (registered) { UnregisterHotKey(Handle, 1); registered = false; } }

    protected override void WndProc(ref Message m) {
        if (m.Msg == WM_HOTKEY && Pressed != null) Pressed(this, EventArgs.Empty);
        base.WndProc(ref m);
    }
    public void Dispose() { Unregister(); DestroyHandle(); }
}
'@

# Hide the console window if there is one (fallback; the launcher normally starts us without one)
[HoverNative]::HideConsole()

# ---------- single instance ----------
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\HoverSwitch_SingleInstance', [ref]$createdNew)
if (-not $createdNew) {
    [System.Windows.Forms.MessageBox]::Show('HoverSwitch is already running (look for its icon in the system tray).', 'HoverSwitch') | Out-Null
    return
}

# ---------- settings ----------
$settingsDir  = Join-Path $env:APPDATA 'HoverSwitch'
$settingsFile = Join-Path $settingsDir 'settings.json'
if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir | Out-Null }

$defaults = [ordered]@{
    HoverDelay  = 50      # ms, used when hover mode is ON
    NormalDelay = $null   # ms, restored when hover mode is OFF (captured on first run)
    RaiseWindow = $true   # also bring the hovered window to the front
    Hotkey      = 'Ctrl+Alt+H'
}
$cfg = [ordered]@{}
foreach ($k in $defaults.Keys) { $cfg[$k] = $defaults[$k] }
if (Test-Path $settingsFile) {
    try {
        $loaded = Get-Content $settingsFile -Raw | ConvertFrom-Json
        foreach ($p in $loaded.PSObject.Properties) { if ($cfg.Contains($p.Name)) { $cfg[$p.Name] = $p.Value } }
    } catch { }
}
if ($null -eq $cfg.NormalDelay) {
    # First run: remember what Windows uses now, unless hover mode is already on with a custom delay.
    $cur = [HoverNative]::GetDelay()
    if ([HoverNative]::GetTracking() -and $cur -gt 0) { $cfg.NormalDelay = 0 } else { $cfg.NormalDelay = $cur }
}
function Save-Settings { $cfg | ConvertTo-Json | Set-Content -Path $settingsFile -Encoding UTF8 }
Save-Settings

# ---------- icons ----------
function New-StateIcon([bool]$on) {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $fill = if ($on) { [System.Drawing.Color]::FromArgb(46, 170, 80) } else { [System.Drawing.Color]::FromArgb(130, 130, 130) }
    $g.FillEllipse((New-Object System.Drawing.SolidBrush $fill), 1, 1, 30, 30)
    # simple mouse-pointer arrow
    $pts = [System.Drawing.Point[]]@(
        (New-Object System.Drawing.Point 11, 6),  (New-Object System.Drawing.Point 11, 25),
        (New-Object System.Drawing.Point 16, 20), (New-Object System.Drawing.Point 19, 27),
        (New-Object System.Drawing.Point 22, 25), (New-Object System.Drawing.Point 19, 19),
        (New-Object System.Drawing.Point 25, 19))
    $g.FillPolygon([System.Drawing.Brushes]::White, $pts)
    $g.Dispose()
    [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}
$iconOn  = New-StateIcon $true
$iconOff = New-StateIcon $false

# ---------- core ----------
function Test-HoverOn { [HoverNative]::GetTracking() }

function Set-HoverMode([bool]$on) {
    if ($on) {
        [HoverNative]::SetDelay([int]$cfg.HoverDelay) | Out-Null
        [HoverNative]::SetRaise([bool]$cfg.RaiseWindow) | Out-Null
        [HoverNative]::SetTracking($true) | Out-Null
    } else {
        [HoverNative]::SetTracking($false) | Out-Null
        [HoverNative]::SetRaise($false) | Out-Null
        [HoverNative]::SetDelay([int]$cfg.NormalDelay) | Out-Null
    }
    Update-UI
}

function Switch-Hover { Set-HoverMode (-not (Test-HoverOn)) }

# ---------- hotkey ----------
$hotkey = New-Object HoverHotkey
$hotkey.add_Pressed({ Switch-Hover })

function Register-AppHotkey {
    $hotkey.Unregister()
    if ([string]::IsNullOrWhiteSpace($cfg.Hotkey) -or $cfg.Hotkey -eq 'None') { return $true }
    $mods = 0; $vk = 0
    foreach ($part in ($cfg.Hotkey -split '\+')) {
        switch ($part.Trim().ToLower()) {
            'ctrl'  { $mods = $mods -bor 2 }
            'alt'   { $mods = $mods -bor 1 }
            'shift' { $mods = $mods -bor 4 }
            'win'   { $mods = $mods -bor 8 }
            default {
                try { $vk = [int][Enum]::Parse([System.Windows.Forms.Keys], $part.Trim(), $true) } catch { $vk = 0 }
            }
        }
    }
    if ($vk -eq 0) { return $false }
    return $hotkey.Register([uint32]$mods, [uint32]$vk)
}

# ---------- settings window ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'HoverSwitch'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size 300, 250
$form.Icon = $iconOn
$form.Font = New-Object System.Drawing.Font 'Segoe UI', 9

$btnToggle = New-Object System.Windows.Forms.Button
$btnToggle.SetBounds(15, 15, 270, 50)
$btnToggle.Font = New-Object System.Drawing.Font 'Segoe UI', 12, ([System.Drawing.FontStyle]::Bold)
$btnToggle.FlatStyle = 'Flat'
$btnToggle.ForeColor = [System.Drawing.Color]::White
$btnToggle.add_Click({ Switch-Hover })
$form.Controls.Add($btnToggle)

$lblHover = New-Object System.Windows.Forms.Label
$lblHover.Text = 'Hover delay when ON (ms):'
$lblHover.SetBounds(15, 82, 180, 20)
$form.Controls.Add($lblHover)

$numHover = New-Object System.Windows.Forms.NumericUpDown
$numHover.SetBounds(200, 80, 85, 24)
$numHover.Minimum = 0; $numHover.Maximum = 5000; $numHover.Increment = 10
$numHover.Value = [decimal]$cfg.HoverDelay
$form.Controls.Add($numHover)

$lblNormal = New-Object System.Windows.Forms.Label
$lblNormal.Text = 'Normal delay when OFF (ms):'
$lblNormal.SetBounds(15, 114, 180, 20)
$form.Controls.Add($lblNormal)

$numNormal = New-Object System.Windows.Forms.NumericUpDown
$numNormal.SetBounds(200, 112, 85, 24)
$numNormal.Minimum = 0; $numNormal.Maximum = 5000; $numNormal.Increment = 10
$numNormal.Value = [decimal]$cfg.NormalDelay
$form.Controls.Add($numNormal)

$chkRaise = New-Object System.Windows.Forms.CheckBox
$chkRaise.Text = 'Also bring hovered window to the front'
$chkRaise.SetBounds(15, 144, 270, 22)
$chkRaise.Checked = [bool]$cfg.RaiseWindow
$form.Controls.Add($chkRaise)

$lblKey = New-Object System.Windows.Forms.Label
$lblKey.Text = 'Hotkey (e.g. Ctrl+Alt+H, None):'
$lblKey.SetBounds(15, 176, 180, 20)
$form.Controls.Add($lblKey)

$txtKey = New-Object System.Windows.Forms.TextBox
$txtKey.SetBounds(200, 173, 85, 24)
$txtKey.Text = $cfg.Hotkey
$form.Controls.Add($txtKey)

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = 'Save'
$btnApply.SetBounds(120, 210, 80, 28)
$form.Controls.Add($btnApply)

$btnHide = New-Object System.Windows.Forms.Button
$btnHide.Text = 'Hide'
$btnHide.SetBounds(205, 210, 80, 28)
$btnHide.add_Click({ $form.Hide() })
$form.Controls.Add($btnHide)

$btnApply.add_Click({
    $cfg.HoverDelay  = [int]$numHover.Value
    $cfg.NormalDelay = [int]$numNormal.Value
    $cfg.RaiseWindow = $chkRaise.Checked
    $oldKey = $cfg.Hotkey
    $cfg.Hotkey = $txtKey.Text.Trim()
    if (-not (Register-AppHotkey)) {
        [System.Windows.Forms.MessageBox]::Show("Could not use hotkey '$($cfg.Hotkey)' (invalid or taken by another app). Keeping '$oldKey'.", 'HoverSwitch') | Out-Null
        $cfg.Hotkey = $oldKey; $txtKey.Text = $oldKey
        Register-AppHotkey | Out-Null
    }
    Save-Settings
    # re-apply the current mode so the new delay takes effect right away
    Set-HoverMode (Test-HoverOn)
})

# Closing the window just hides it to the tray
$form.add_FormClosing({
    param($s, $e)
    if ($e.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) { $e.Cancel = $true; $form.Hide() }
})

# ---------- tray ----------
$tray = New-Object System.Windows.Forms.NotifyIcon
$menu = New-Object System.Windows.Forms.ContextMenuStrip

$miToggle = $menu.Items.Add('Turn ON')
$miToggle.Font = New-Object System.Drawing.Font $miToggle.Font, ([System.Drawing.FontStyle]::Bold)
$miToggle.add_Click({ Switch-Hover })

$miDelay = New-Object System.Windows.Forms.ToolStripMenuItem 'Hover delay'
foreach ($ms in 0, 25, 50, 100, 200, 500) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem "$ms ms"
    $item.Tag = $ms
    $item.add_Click({
        param($s, $e)
        $cfg.HoverDelay = [int]$s.Tag
        $numHover.Value = [decimal]$cfg.HoverDelay
        Save-Settings
        if (Test-HoverOn) { [HoverNative]::SetDelay([int]$cfg.HoverDelay) | Out-Null }
        Update-UI
    })
    $miDelay.DropDownItems.Add($item) | Out-Null
}
$menu.Items.Add($miDelay) | Out-Null

$miRaise = New-Object System.Windows.Forms.ToolStripMenuItem 'Bring hovered window to front'
$miRaise.add_Click({
    $cfg.RaiseWindow = -not [bool]$cfg.RaiseWindow
    $chkRaise.Checked = [bool]$cfg.RaiseWindow
    Save-Settings
    if (Test-HoverOn) { [HoverNative]::SetRaise([bool]$cfg.RaiseWindow) | Out-Null }
    Update-UI
})
$menu.Items.Add($miRaise) | Out-Null

$miSettings = $menu.Items.Add('Settings...')
$miSettings.add_Click({ Show-Settings })

$scriptPath = $PSCommandPath
$startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'HoverSwitch.lnk'
$miStartup = New-Object System.Windows.Forms.ToolStripMenuItem 'Start with Windows'
$miStartup.Checked = Test-Path $startupLnk
$miStartup.add_Click({
    if (Test-Path $startupLnk) {
        Remove-Item $startupLnk -Force
    } else {
        $sh = New-Object -ComObject WScript.Shell
        $lnk = $sh.CreateShortcut($startupLnk)
        $lnk.TargetPath = Join-Path $env:SystemRoot 'System32\conhost.exe'
        $lnk.Arguments = "--headless powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
        $lnk.WorkingDirectory = Split-Path $scriptPath
        $lnk.Save()
    }
    $miStartup.Checked = Test-Path $startupLnk
})
$menu.Items.Add($miStartup) | Out-Null

$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$miExitOff = $menu.Items.Add('Turn OFF and exit')
$miExitOff.add_Click({ Set-HoverMode $false; Exit-App })
$miExit = $menu.Items.Add('Exit (leave as is)')
$miExit.add_Click({ Exit-App })

$tray.ContextMenuStrip = $menu
$tray.add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Switch-Hover }
})
$tray.add_DoubleClick({ Show-Settings })

function Show-Settings {
    $numHover.Value  = [decimal]$cfg.HoverDelay
    $numNormal.Value = [decimal]$cfg.NormalDelay
    $chkRaise.Checked = [bool]$cfg.RaiseWindow
    $txtKey.Text = $cfg.Hotkey
    Update-UI
    $form.Show(); $form.WindowState = 'Normal'; $form.Activate()
}

function Update-UI {
    $on = Test-HoverOn
    $delay = [HoverNative]::GetDelay()
    $state = if ($on) { "ON ($delay ms)" } else { 'OFF' }
    $hk = if ($cfg.Hotkey -and $cfg.Hotkey -ne 'None') { " - $($cfg.Hotkey)" } else { '' }
    $tray.Icon = if ($on) { $iconOn } else { $iconOff }
    $tip = "HoverSwitch: $state$hk"
    if ($tip.Length -gt 63) { $tip = $tip.Substring(0, 63) }
    $tray.Text = $tip   # tooltip, max 63 chars
    $miToggle.Text = if ($on) { 'Turn OFF' } else { "Turn ON ($($cfg.HoverDelay) ms)" }
    $miRaise.Checked = [bool]$cfg.RaiseWindow
    foreach ($i in $miDelay.DropDownItems) { $i.Checked = ([int]$i.Tag -eq [int]$cfg.HoverDelay) }
    $btnToggle.Text = if ($on) { "ON - $delay ms   (click to turn off)" } else { 'OFF   (click to turn on)' }
    $btnToggle.BackColor = if ($on) { [System.Drawing.Color]::FromArgb(46, 170, 80) } else { [System.Drawing.Color]::FromArgb(120, 120, 120) }
    $form.Icon = $tray.Icon
}

function Exit-App {
    $tray.Visible = $false
    $hotkey.Dispose()
    $tray.Dispose()
    [System.Windows.Forms.Application]::Exit()
}

# ---------- go ----------
if (-not (Register-AppHotkey)) {
    $tray.Visible = $true
    $tray.ShowBalloonTip(4000, 'HoverSwitch', "Hotkey '$($cfg.Hotkey)' is taken by another app. Change it in Settings.", 'Warning')
}
Update-UI
$tray.Visible = $true
$tray.ShowBalloonTip(2500, 'HoverSwitch', 'Click the tray icon to switch hover mode on/off. Right-click for options.', 'Info')

# Keep the tray icon in sync if the setting is changed elsewhere (e.g. in Windows Settings)
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2000
$timer.add_Tick({ Update-UI })
$timer.Start()

[System.Windows.Forms.Application]::Run()
$timer.Stop()
$mutex.ReleaseMutex()
