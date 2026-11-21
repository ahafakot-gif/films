#requires -version 5.1
<#
  Запись флешек — אליעזר הפקות
  Форматирует флешки в NTFS с названием работы, записывает выбранные файлы
  и закрывает флешки от записи и удаления (только чтение).

  Запуск из меню правой кнопки (после установки):
    -Kind drive  -Path "E:\"        — флешка
    -Kind folder -Path "D:\Работы\..." — папка работы
    -Kind file   -Path "D:\...\клип.mp4" — файл(ы)
#>
param(
    [string]$Kind,
    [string]$Path,
    [string]$SessionFile
)

$ErrorActionPreference = 'Stop'
$AppTitle    = 'Запись флешек — אליעזר הפקות'
$AppDir      = Join-Path $env:LOCALAPPDATA 'FlashWriter'
$SettingsFile = Join-Path $AppDir 'settings.json'
$LogFile     = Join-Path $AppDir 'log.txt'
if (-not (Test-Path -LiteralPath $AppDir)) { New-Item -ItemType Directory -Path $AppDir | Out-Null }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Show-Msg([string]$text, [string]$icon = 'Information', [string]$buttons = 'OK') {
    return [System.Windows.Forms.MessageBox]::Show($text, $AppTitle,
        [System.Windows.Forms.MessageBoxButtons]::$buttons,
        [System.Windows.Forms.MessageBoxIcon]::$icon)
}

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------------------
# 1. Сбор того, на что нажали правой кнопкой.
#    Explorer запускает отдельную копию программы на каждый выбранный объект
#    (две флешки = две копии). Все копии пишут в общую очередь, первая ждёт
#    остальных, собирает всё и открывает ОДНО окно.
# ---------------------------------------------------------------------------
$items = @()
if ($SessionFile -and (Test-Path -LiteralPath $SessionFile)) {
    $items = @(Get-Content -LiteralPath $SessionFile -Encoding UTF8 | Where-Object { $_ -match '\|' })
    Remove-Item -LiteralPath $SessionFile -Force -ErrorAction SilentlyContinue
}
elseif ($Kind -and $Path) {
    $queue = Join-Path $env:TEMP 'FlashWriter-queue.txt'
    if ((Test-Path -LiteralPath $queue) -and ((Get-Item -LiteralPath $queue).LastWriteTime -lt (Get-Date).AddSeconds(-30))) {
        Remove-Item -LiteralPath $queue -Force -ErrorAction SilentlyContinue
    }
    for ($i = 0; $i -lt 40; $i++) {
        try { [IO.File]::AppendAllText($queue, "$Kind|$Path`r`n", [Text.Encoding]::UTF8); break }
        catch { Start-Sleep -Milliseconds 50 }
    }
    $mutex = New-Object Threading.Mutex($false, 'Local\FlashWriterCollector')
    $leader = $false
    try { $leader = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $leader = $true }
    if (-not $leader) { exit }
    $last = -1; $stable = 0
    while ($stable -lt 4) {
        Start-Sleep -Milliseconds 300
        $len = if (Test-Path -LiteralPath $queue) { (Get-Item -LiteralPath $queue).Length } else { 0 }
        if ($len -eq $last) { $stable++ } else { $stable = 0; $last = $len }
    }
    if (Test-Path -LiteralPath $queue) {
        $items = @(Get-Content -LiteralPath $queue -Encoding UTF8 | Where-Object { $_ -match '\|' } | Select-Object -Unique)
        Remove-Item -LiteralPath $queue -Force -ErrorAction SilentlyContinue
    }
    $mutex.ReleaseMutex()
}

# ---------------------------------------------------------------------------
# 2. Права администратора (нужны для форматирования). Один запрос UAC.
# ---------------------------------------------------------------------------
if (-not (Test-Admin)) {
    $tmp = Join-Path $env:TEMP ('FlashWriter-' + [guid]::NewGuid().ToString('N') + '.txt')
    [IO.File]::WriteAllLines($tmp, [string[]]$items, (New-Object Text.UTF8Encoding($true)))
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-WindowStyle', 'Hidden',
            '-File', "`"$PSCommandPath`"", '-SessionFile', "`"$tmp`"")
    }
    catch {
        Show-Msg 'Для форматирования флешек нужны права администратора. Нажмите «Да» в окне Windows.' 'Warning' | Out-Null
    }
    exit
}

$preDrives = @(); $preFolder = $null; $preFiles = @()
foreach ($line in $items) {
    $k, $p = $line -split '\|', 2
    switch ($k) {
        'drive'  { if ($p) { $preDrives += $p.Substring(0, 1).ToUpper() } }
        'folder' { if (-not $preFolder -and $p) { $preFolder = $p.TrimEnd('"') } }
        'file'   { if ($p) { $preFiles += $p } }
    }
}
if ($preFiles.Count -gt 0 -and -not $preFolder) { $preFolder = Split-Path -Parent $preFiles[0] }

# ---------------------------------------------------------------------------
# Вспомогательные функции
# ---------------------------------------------------------------------------
function Format-Size([double]$b) {
    if ($b -ge 1TB) { return '{0:N1} ТБ' -f ($b / 1TB) }
    if ($b -ge 1GB) { return '{0:N1} ГБ' -f ($b / 1GB) }
    if ($b -ge 1MB) { return '{0:N0} МБ' -f ($b / 1MB) }
    return '{0:N0} КБ' -f ($b / 1KB)
}

function Get-Settings {
    try { return (Get-Content -LiteralPath $SettingsFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return [pscustomobject]@{ LastFolder = '' } }
}
function Save-Settings($s) {
    try { [IO.File]::WriteAllText($SettingsFile, ($s | ConvertTo-Json), (New-Object Text.UTF8Encoding($true))) } catch {}
}

function Get-CleanLabel([string]$name) {
    $l = ($name -replace '[\\/:*?"<>|\t]', ' ').Trim()
    $l = ($l -replace '\s{2,}', ' ')
    if ($l.Length -gt 32) { $l = $l.Substring(0, 32).Trim() }
    return $l
}

# Только USB-флешки (и SD-карты): не системный, не загрузочный диск, шина USB.
function Get-UsbDrives([bool]$includeFixed) {
    $list = @()
    foreach ($v in @(Get-Volume | Where-Object { $_.DriveLetter })) {
        try {
            $part = Get-Partition -DriveLetter $v.DriveLetter -ErrorAction Stop
            $disk = Get-Disk -Number $part.DiskNumber -ErrorAction Stop
        } catch { continue }
        if ($disk.IsSystem -or $disk.IsBoot) { continue }
        $bus = "$($disk.BusType)"
        if ($bus -ne 'USB' -and $bus -ne '7') { continue }
        $removable = ("$($v.DriveType)" -eq 'Removable')
        if (-not $removable -and -not $includeFixed) { continue }
        $list += [pscustomobject]@{
            Letter    = "$($v.DriveLetter)".ToUpper()
            Label     = $v.FileSystemLabel
            Size      = [double]$disk.Size
            Model     = ("$($disk.FriendlyName)").Trim()
            Removable = $removable
            DiskNumber = $disk.Number
        }
    }
    return $list | Sort-Object Letter
}

# ---------------------------------------------------------------------------
# Работа с одной флешкой — выполняется в отдельном потоке (флешки параллельно)
# ---------------------------------------------------------------------------
$Worker = {
    param($Letter, $Label, $Files, $Dirs, $Lock, $Verify, $State, $Log)
    $ErrorActionPreference = 'Stop'
    function L([string]$m) { [void]$Log.Add(('{0}  {1}:  {2}' -f (Get-Date -Format 'HH:mm:ss'), $Letter, $m)) }
    try {
        Import-Module Storage -ErrorAction SilentlyContinue
        $root = "$($Letter):\"

        # --- проверка, что это действительно USB-флешка
        $State.Stage = 'Подготовка'
        $part = Get-Partition -DriveLetter $Letter
        $disk = Get-Disk -Number $part.DiskNumber
        $diskNo = $disk.Number
        if ($disk.IsSystem -or $disk.IsBoot) { throw 'Это системный диск — отказ.' }
        if ("$($disk.BusType)" -ne 'USB' -and "$($disk.BusType)" -ne '7') { throw "Это не USB-диск ($($disk.BusType)) — отказ." }
        if ($disk.IsReadOnly) { try { Set-Disk -Number $diskNo -IsReadOnly $false } catch {} }

        # --- форматирование NTFS
        $State.Stage = 'Форматирование NTFS'
        L "форматирование NTFS, название «$Label»"
        $formatted = $false
        if (@(Get-Partition -DiskNumber $diskNo).Count -eq 1) {
            try {
                Format-Volume -DriveLetter $Letter -FileSystem NTFS -NewFileSystemLabel $Label -Confirm:$false -Force | Out-Null
                $formatted = $true
            } catch { L "обычное форматирование не прошло ($($_.Exception.Message)) — очищаю флешку полностью" }
        }
        if (-not $formatted) {
            $m = New-Object Threading.Mutex($false, 'Local\FlashWriterDiskpart')
            [void]$m.WaitOne()
            try {
                $dp = Join-Path $env:TEMP ("FlashWriter-dp-$Letter.txt")
                $dpLines = @(
                    "select disk $diskNo",
                    'attributes disk clear readonly noerr',
                    'clean',
                    'create partition primary',
                    'format fs=ntfs quick label=FLASH',
                    "assign letter=$Letter"
                )
                [IO.File]::WriteAllLines($dp, $dpLines, [Text.Encoding]::ASCII)
                $out = & diskpart.exe /s $dp 2>&1 | Out-String
                Remove-Item -LiteralPath $dp -Force -ErrorAction SilentlyContinue
                L ('diskpart: ' + (($out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 2) -join ' / '))
            } finally { $m.ReleaseMutex() }
            for ($i = 0; $i -lt 40 -and -not (Test-Path -LiteralPath $root); $i++) { Start-Sleep -Milliseconds 500 }
            if (-not (Test-Path -LiteralPath $root)) { throw 'После очистки флешка не появилась.' }
            Set-Volume -DriveLetter $Letter -NewFileSystemLabel $Label
        }
        $fs = (Get-Volume -DriveLetter $Letter).FileSystem
        if ("$fs" -ne 'NTFS') { throw "Флешка не в NTFS (сейчас $fs)." }

        # --- запись файлов
        $State.Stage = 'Запись файлов'
        L "запись: $($Files.Count) файл(ов)"
        foreach ($d in $Dirs) { [void][IO.Directory]::CreateDirectory((Join-Path $root $d)) }
        $buf = New-Object byte[] (4MB)
        foreach ($f in $Files) {
            $dst = Join-Path $root $f.Rel
            $State.Current = $f.Rel
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dst))
            $in = New-Object IO.FileStream($f.Src, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read, 1MB)
            try {
                $outS = New-Object IO.FileStream($dst, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None, 1MB)
                try {
                    while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                        $outS.Write($buf, 0, $n)
                        $State.Done += $n
                    }
                } finally { $outS.Dispose() }
            } finally { $in.Dispose() }
            [IO.File]::SetLastWriteTimeUtc($dst, $f.Time)
        }
        $State.Current = ''
        try { Write-VolumeCache -DriveLetter $Letter } catch {}

        # --- проверка
        if ($Verify) {
            $State.Stage = 'Проверка'
            $bad = 0
            foreach ($f in $Files) {
                $p = Join-Path $root $f.Rel
                if (-not (Test-Path -LiteralPath $p) -or ((Get-Item -LiteralPath $p -Force).Length -ne $f.Size)) {
                    $bad++; L "не совпадает: $($f.Rel)"
                }
            }
            if ($bad -gt 0) { throw "Проверка: $bad файл(ов) записались неправильно." }
            L 'проверка: все файлы на месте'
        }

        # --- закрыть от записи: всем только чтение, без права менять и удалять
        if ($Lock) {
            $State.Stage = 'Закрываю от записи'
            & icacls.exe $root /inheritance:r /grant:r '*S-1-1-0:(OI)(CI)(RX)' /Q | Out-Null
            & icacls.exe $root /remove:g '*S-1-5-32-544' '*S-1-5-18' '*S-1-5-11' '*S-1-5-32-545' '*S-1-3-0' /Q | Out-Null
            & icacls.exe "$($Letter):\*" /reset /T /C /Q 2>&1 | Out-Null
            try { Write-VolumeCache -DriveLetter $Letter } catch {}
            # проверка защиты: пробуем записать и удалить
            $t = Join-Path $root ('__test_' + [guid]::NewGuid().ToString('N') + '.tmp')
            $canWrite = $true
            try { [IO.File]::WriteAllText($t, 'x'); Remove-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue } catch { $canWrite = $false }
            if ($canWrite) { throw 'Не получилось закрыть флешку от записи.' }
            # проверка прав: ни у кого нет права писать, удалять или менять права
            $badRights = [Security.AccessControl.FileSystemRights]'Write, Delete, DeleteSubdirectoriesAndFiles, ChangePermissions, TakeOwnership'
            foreach ($ace in (Get-Acl -LiteralPath $root).Access) {
                if ("$($ace.AccessControlType)" -eq 'Allow' -and ([int64]$ace.FileSystemRights -band [int64]$badRights)) {
                    throw "Осталось право записи у «$($ace.IdentityReference)»."
                }
            }
            L 'закрыта: только чтение'
        }

        $State.Stage = 'Готово ✓'
        $State.Ok = $true
        L 'готово'
    }
    catch {
        $State.Stage = 'ОШИБКА'
        $State.Error = $_.Exception.Message
        L ("ОШИБКА: " + $_.Exception.Message)
    }
    finally { $State.Finished = $true }
}

# ---------------------------------------------------------------------------
# Окно программы
# ---------------------------------------------------------------------------
[System.Windows.Forms.Application]::EnableVisualStyles()
$font     = New-Object Drawing.Font('Segoe UI', 10)
$fontBold = New-Object Drawing.Font('Segoe UI', 10, [Drawing.FontStyle]::Bold)
$fontBig  = New-Object Drawing.Font('Segoe UI', 14, [Drawing.FontStyle]::Bold)

$form = New-Object Windows.Forms.Form
$form.Text = $AppTitle
$form.Size = New-Object Drawing.Size(940, 820)
$form.MinimumSize = $form.Size
$form.StartPosition = 'CenterScreen'
$form.Font = $font
$form.BackColor = [Drawing.Color]::FromArgb(250, 248, 243)

function New-Ctl($type, $x, $y, $w, $h, $text = '') {
    $c = New-Object "Windows.Forms.$type"
    $c.Location = New-Object Drawing.Point($x, $y)
    $c.Size = New-Object Drawing.Size($w, $h)
    if ($text) { $c.Text = $text }
    $form.Controls.Add($c)
    return $c
}

# --- 1. Флешки
$lblDrives = New-Ctl Label 16 12 600 24 '1. Флешки (только USB-флешки, жёсткие диски не показываются)'
$lblDrives.Font = $fontBold
$clbDrives = New-Ctl CheckedListBox 16 40 780 110
$clbDrives.CheckOnClick = $true
$btnRefresh = New-Ctl Button 806 40 100 32 'Обновить'
$chkFixed = New-Ctl CheckBox 16 152 700 24 'Показать и USB-диски, которые Windows считает жёсткими (осторожно!)'
$chkFixed.ForeColor = [Drawing.Color]::DarkRed

# --- 2. Папка работы
$lblFolder = New-Ctl Label 16 186 600 24 '2. Папка работы'
$lblFolder.Font = $fontBold
$txtFolder = New-Ctl TextBox 16 214 780 28
$txtFolder.ReadOnly = $true
$btnFolder = New-Ctl Button 806 212 100 32 'Выбрать…'
$lblName = New-Ctl Label 16 252 170 24 'Название флешки:'
$txtLabel = New-Ctl TextBox 186 250 450 28
$txtLabel.MaxLength = 32
$lblNameHint = New-Ctl Label 646 252 270 24 '(до 32 знаков, берётся из папки)'
$lblNameHint.ForeColor = [Drawing.Color]::Gray

# --- 3. Что записать
$lblFiles = New-Ctl Label 16 290 600 24 '3. Что записать на флешки (отметьте галочками)'
$lblFiles.Font = $fontBold
$clbFiles = New-Ctl CheckedListBox 16 318 780 200
$clbFiles.CheckOnClick = $true
$btnAll  = New-Ctl Button 806 318 100 32 'Все'
$btnNone = New-Ctl Button 806 356 100 32 'Ни одного'
$lblTotal = New-Ctl Label 16 522 890 24 'Выбрано: 0'

# --- Настройки
$chkLock   = New-Ctl CheckBox 16 552 420 24 'Закрыть флешки от записи и удаления'
$chkLock.Checked = $true
$chkVerify = New-Ctl CheckBox 440 552 220 24 'Проверить запись'
$chkVerify.Checked = $true
$chkEject  = New-Ctl CheckBox 660 552 250 24 'Извлечь флешки в конце'
$chkEject.Checked = $true

$btnStart = New-Ctl Button 16 584 890 52 'СТАРТ — форматировать и записать'
$btnStart.Font = $fontBig
$btnStart.BackColor = [Drawing.Color]::FromArgb(214, 173, 85)
$btnStart.FlatStyle = 'Flat'

$pnlProgress = New-Ctl Panel 16 644 890 70
$pnlProgress.AutoScroll = $true
$txtLog = New-Ctl TextBox 16 718 890 54
$txtLog.Multiline = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object Drawing.Font('Consolas', 9)

# --- данные
$script:driveObjs = @()
$script:fileObjs = @()
$script:jobs = @()
$script:busy = $false
$script:logShown = 0
$Log = [Collections.ArrayList]::Synchronized((New-Object Collections.ArrayList))

function Refresh-Drives {
    $checked = @()
    for ($i = 0; $i -lt $clbDrives.Items.Count; $i++) {
        if ($clbDrives.GetItemChecked($i)) { $checked += $script:driveObjs[$i].Letter }
    }
    if ($script:firstLoad) { $checked = $preDrives; $script:firstLoad = $false }
    $clbDrives.Items.Clear()
    $script:driveObjs = @(Get-UsbDrives $chkFixed.Checked)
    foreach ($d in $script:driveObjs) {
        $t = '{0}:     {1}     {2}     {3}' -f $d.Letter, (Format-Size $d.Size), $d.Model, $(if ($d.Label) { "«$($d.Label)»" } else { '' })
        if (-not $d.Removable) { $t += '     [ЖЁСТКИЙ USB-ДИСК]' }
        $idx = $clbDrives.Items.Add($t)
        if ($checked -contains $d.Letter) { $clbDrives.SetItemChecked($idx, $true) }
    }
    if ($script:driveObjs.Count -eq 0) { $lblDrives.Text = '1. Флешки — не найдено ни одной USB-флешки. Вставьте и нажмите «Обновить».' }
    else { $lblDrives.Text = '1. Флешки (только USB-флешки, жёсткие диски не показываются)' }
}

function Load-Folder([string]$folder) {
    $clbFiles.Items.Clear()
    $script:fileObjs = @()
    if (-not $folder -or -not (Test-Path -LiteralPath $folder -PathType Container)) { Update-Total; return }
    $txtFolder.Text = $folder
    $txtLabel.Text = Get-CleanLabel (Split-Path -Leaf $folder)
    $form.Cursor = 'WaitCursor'
    $children = @(Get-ChildItem -LiteralPath $folder -Force | Where-Object {
        -not ($_.Attributes -band [IO.FileAttributes]::System) -and $_.Name -notin @('Thumbs.db', 'desktop.ini')
    } | Sort-Object @{ e = { -not $_.PSIsContainer } }, Name)
    foreach ($c in $children) {
        if ($c.PSIsContainer) {
            $size = (Get-ChildItem -LiteralPath $c.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $text = '[папка]  {0}     ({1})' -f $c.Name, (Format-Size ([double]$size))
        } else {
            $size = $c.Length
            $text = '{0}     ({1})' -f $c.Name, (Format-Size ([double]$size))
        }
        $script:fileObjs += [pscustomobject]@{ Item = $c; Size = [double]$size }
        $idx = $clbFiles.Items.Add($text)
        if ($preFiles -contains $c.FullName) { $clbFiles.SetItemChecked($idx, $true) }
    }
    $form.Cursor = 'Default'
    $s = Get-Settings; $s.LastFolder = $folder; Save-Settings $s
    Update-Total
}

function Get-SelectedBytes {
    $sum = 0.0
    for ($i = 0; $i -lt $clbFiles.Items.Count; $i++) { if ($clbFiles.GetItemChecked($i)) { $sum += $script:fileObjs[$i].Size } }
    return $sum
}

function Update-Total {
    $n = $clbFiles.CheckedIndices.Count
    $lblTotal.Text = 'Выбрано: {0}, всего {1}' -f $n, (Format-Size (Get-SelectedBytes))
}

function Set-Busy([bool]$b) {
    $script:busy = $b
    foreach ($c in @($clbDrives, $btnRefresh, $chkFixed, $btnFolder, $txtLabel, $clbFiles, $btnAll, $btnNone, $chkLock, $chkVerify, $chkEject, $btnStart)) { $c.Enabled = -not $b }
}

function Flush-Log {
    while ($script:logShown -lt $Log.Count) {
        $line = $Log[$script:logShown]; $script:logShown++
        $txtLog.AppendText($line + "`r`n")
        try { [IO.File]::AppendAllText($LogFile, $line + "`r`n", [Text.Encoding]::UTF8) } catch {}
    }
}

# --- события
$btnRefresh.Add_Click({ Refresh-Drives })
$chkFixed.Add_CheckedChanged({ Refresh-Drives })
$btnAll.Add_Click({ for ($i = 0; $i -lt $clbFiles.Items.Count; $i++) { $clbFiles.SetItemChecked($i, $true) }; Update-Total })
$btnNone.Add_Click({ for ($i = 0; $i -lt $clbFiles.Items.Count; $i++) { $clbFiles.SetItemChecked($i, $false) }; Update-Total })
$clbFiles.Add_ItemCheck({ [void]$form.BeginInvoke([Action]{ Update-Total }) })

$btnFolder.Add_Click({
    $dlg = New-Object Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Выберите папку работы (её название станет названием флешки)'
    $start = if ($txtFolder.Text) { $txtFolder.Text } else { (Get-Settings).LastFolder }
    if ($start -and (Test-Path -LiteralPath $start)) { $dlg.SelectedPath = $start }
    if ($dlg.ShowDialog($form) -eq 'OK') { $script:preFiles = @(); Load-Folder $dlg.SelectedPath }
})

$btnStart.Add_Click({
    # --- проверки
    $drives = @()
    for ($i = 0; $i -lt $clbDrives.Items.Count; $i++) { if ($clbDrives.GetItemChecked($i)) { $drives += $script:driveObjs[$i] } }
    if ($drives.Count -eq 0) { Show-Msg 'Отметьте хотя бы одну флешку.' 'Warning' | Out-Null; return }
    $folder = $txtFolder.Text
    if (-not $folder -or -not (Test-Path -LiteralPath $folder)) { Show-Msg 'Выберите папку работы.' 'Warning' | Out-Null; return }
    $sel = @()
    for ($i = 0; $i -lt $clbFiles.Items.Count; $i++) { if ($clbFiles.GetItemChecked($i)) { $sel += $script:fileObjs[$i] } }
    if ($sel.Count -eq 0) { Show-Msg 'Отметьте файлы, которые записать.' 'Warning' | Out-Null; return }
    $label = Get-CleanLabel $txtLabel.Text
    if (-not $label) { Show-Msg 'Напишите название флешки.' 'Warning' | Out-Null; return }
    $srcLetter = $folder.Substring(0, 1).ToUpper()
    if ($drives.Letter -contains $srcLetter) {
        Show-Msg "Папка работы лежит на флешке $($srcLetter): — её нельзя форматировать. Снимите галочку с этой флешки." 'Error' | Out-Null; return
    }
    $need = Get-SelectedBytes
    foreach ($d in $drives) {
        if ($need -gt $d.Size * 0.97) {
            Show-Msg ("Не помещается на флешку {0}: ({1}). Нужно {2}." -f $d.Letter, (Format-Size $d.Size), (Format-Size $need)) 'Error' | Out-Null; return
        }
    }
    $list = ($drives | ForEach-Object { "   {0}:  {1}  {2}" -f $_.Letter, (Format-Size $_.Size), $_.Model }) -join "`r`n"
    $ans = Show-Msg ("ВСЁ, что сейчас лежит на этих флешках, будет УДАЛЕНО:`r`n`r`n$list`r`n`r`nНазвание: «$label»`r`nЗаписать: $($sel.Count) объект(ов), $(Format-Size $need)`r`n`r`nПродолжить?") 'Warning' 'YesNo'
    if ("$ans" -ne 'Yes') { return }

    # --- список файлов
    $files = New-Object Collections.ArrayList
    $dirs = New-Object Collections.ArrayList
    foreach ($s in $sel) {
        $it = $s.Item
        if ($it.PSIsContainer) {
            [void]$dirs.Add($it.Name)
            foreach ($c in @(Get-ChildItem -LiteralPath $it.FullName -Recurse -Force -ErrorAction SilentlyContinue)) {
                $rel = $it.Name + $c.FullName.Substring($it.FullName.Length)
                if ($c.PSIsContainer) { [void]$dirs.Add($rel) }
                else { [void]$files.Add([pscustomobject]@{ Src = $c.FullName; Rel = $rel; Size = [double]$c.Length; Time = $c.LastWriteTimeUtc }) }
            }
        } else {
            [void]$files.Add([pscustomobject]@{ Src = $it.FullName; Rel = $it.Name; Size = [double]$it.Length; Time = $it.LastWriteTimeUtc })
        }
    }
    $total = 0.0; foreach ($f in $files) { $total += $f.Size }

    # --- запуск по флешкам параллельно
    Set-Busy $true
    $pnlProgress.Controls.Clear()
    $script:jobs = @()
    [void]$Log.Add(('{0}  Старт: «{1}» из {2} → {3}' -f (Get-Date -Format 'dd.MM.yyyy HH:mm:ss'), $label, $folder, (($drives.Letter | ForEach-Object { "$($_):" }) -join ', ')))
    $y = 0
    foreach ($d in $drives) {
        $state = [hashtable]::Synchronized(@{ Stage = 'Ожидание'; Done = 0.0; Total = $total; Finished = $false; Ok = $false; Error = $null; Current = '' })
        $lbl = New-Object Windows.Forms.Label
        $lbl.Location = New-Object Drawing.Point(0, $y); $lbl.Size = New-Object Drawing.Size(560, 22)
        $bar = New-Object Windows.Forms.ProgressBar
        $bar.Location = New-Object Drawing.Point(565, $y); $bar.Size = New-Object Drawing.Size(300, 20)
        $pnlProgress.Controls.Add($lbl); $pnlProgress.Controls.Add($bar)
        $y += 26
        $rs = [runspacefactory]::CreateRunspace(); $rs.Open()
        $ps = [powershell]::Create(); $ps.Runspace = $rs
        [void]$ps.AddScript($Worker).AddArgument($d.Letter).AddArgument($label).AddArgument($files.ToArray()).AddArgument($dirs.ToArray()).AddArgument($chkLock.Checked).AddArgument($chkVerify.Checked).AddArgument($state).AddArgument($Log)
        $h = $ps.BeginInvoke()
        $script:jobs += [pscustomobject]@{ Letter = $d.Letter; State = $state; Label = $lbl; Bar = $bar; PS = $ps; RS = $rs; Handle = $h }
    }
    $timer.Start()
})

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 400
$timer.Add_Tick({
    $allDone = $true
    foreach ($j in $script:jobs) {
        $s = $j.State
        $pct = if ($s.Total -gt 0) { [int][Math]::Min(100, 100 * $s.Done / $s.Total) } else { 100 }
        if ($s.Ok) { $pct = 100 }
        $j.Bar.Value = $pct
        $txt = '{0}:   {1}   {2}%' -f $j.Letter, $s.Stage, $pct
        if ($s.Error) { $txt = '{0}:   ОШИБКА — {1}' -f $j.Letter, $s.Error; $j.Label.ForeColor = [Drawing.Color]::DarkRed }
        elseif ($s.Ok) { $j.Label.ForeColor = [Drawing.Color]::DarkGreen }
        $j.Label.Text = $txt
        if (-not $s.Finished) { $allDone = $false }
    }
    Flush-Log
    if ($allDone) {
        $timer.Stop()
        foreach ($j in $script:jobs) { try { $j.PS.EndInvoke($j.Handle) } catch {}; $j.PS.Dispose(); $j.RS.Dispose() }
        $ok = @($script:jobs | Where-Object { $_.State.Ok })
        $bad = @($script:jobs | Where-Object { -not $_.State.Ok })
        if ($chkEject.Checked -and $ok.Count -gt 0) {
            $shell = New-Object -ComObject Shell.Application
            foreach ($j in $ok) {
                try { $shell.Namespace(17).ParseName("$($j.Letter):\").InvokeVerb('Eject'); [void]$Log.Add("$($j.Letter):  извлечена") } catch {}
            }
            Flush-Log
        }
        $msg = "Готово: $($ok.Count) флешк(и)."
        if ($ok.Count -gt 0) { $msg += "`r`n" + (($ok | ForEach-Object { "   $($_.Letter):  ✓" }) -join "`r`n") }
        if ($bad.Count -gt 0) {
            $msg += "`r`n`r`nНЕ ПОЛУЧИЛОСЬ: $($bad.Count)`r`n" + (($bad | ForEach-Object { "   $($_.Letter):  $($_.State.Error)" }) -join "`r`n")
            Show-Msg $msg 'Error' | Out-Null
        } else { Show-Msg $msg 'Information' | Out-Null }
        Set-Busy $false
        Refresh-Drives
    }
})

$form.Add_FormClosing({
    param($sender, $e)
    if ($script:busy) {
        Show-Msg 'Идёт запись на флешки — дождитесь окончания. Не вынимайте флешки!' 'Warning' | Out-Null
        $e.Cancel = $true
    }
})

$form.Add_Shown({
    $form.Activate()
    $script:firstLoad = $true
    Refresh-Drives
    foreach ($l in $preDrives) {
        if (-not ($script:driveObjs.Letter -contains $l)) {
            Show-Msg "$($l): — это не USB-флешка. Программа работает только с флешками, этот диск не трогаю." 'Warning' | Out-Null
        }
    }
    if ($preFolder) { Load-Folder $preFolder }
    elseif ($preDrives.Count -gt 0) { $btnFolder.PerformClick() }
})

[void]$form.ShowDialog()
