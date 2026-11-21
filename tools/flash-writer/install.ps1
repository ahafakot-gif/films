# Установка «Запись флешек»: копирует программу и добавляет пункт в меню правой кнопки
$ErrorActionPreference = 'Stop'
$src = Join-Path $PSScriptRoot 'flash-writer.ps1'
$dir = Join-Path $env:LOCALAPPDATA 'FlashWriter'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$dst = Join-Path $dir 'flash-writer.ps1'
Copy-Item -LiteralPath $src -Destination $dst -Force
Unblock-File -LiteralPath $dst -ErrorAction SilentlyContinue

$menu = 'Записать на флешки (работа)'
$ps   = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $dst + '"'
$targets = @(
    @{ Key = 'Software\Classes\Drive\shell\FlashWriter';                Arg = '-Kind drive -Path "%1"';  Icon = 'shell32.dll,7' },
    @{ Key = 'Software\Classes\Directory\shell\FlashWriter';            Arg = '-Kind folder -Path "%1"'; Icon = 'shell32.dll,7' },
    @{ Key = 'Software\Classes\Directory\Background\shell\FlashWriter'; Arg = '-Kind folder -Path "%V"'; Icon = 'shell32.dll,7' },
    @{ Key = 'Software\Classes\*\shell\FlashWriter';                    Arg = '-Kind file -Path "%1"';   Icon = 'shell32.dll,7' }
)
foreach ($t in $targets) {
    $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($t.Key)
    $k.SetValue('MUIVerb', $menu); $k.SetValue('Icon', $t.Icon); $k.Close()
    $c = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($t.Key + '\command')
    $c.SetValue('', $ps + ' ' + $t.Arg); $c.Close()
}

# Ярлык на рабочем столе
$lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Запись флешек.lnk'
$sh = New-Object -ComObject WScript.Shell
$s = $sh.CreateShortcut($lnk)
$s.TargetPath = 'powershell.exe'
$s.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $dst + '"'
$s.IconLocation = 'shell32.dll,7'
$s.Save()

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show("Установлено!`r`n`r`nНажмите правой кнопкой на флешку, папку работы или файлы → «$menu».`r`n(В Windows 11 сначала «Показать дополнительные параметры».)`r`n`r`nНа рабочем столе — ярлык «Запись флешек».", 'Запись флешек') | Out-Null
