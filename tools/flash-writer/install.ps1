# Установка «Запись флешек»: копирует программу, добавляет пункт в меню правой кнопки и ярлык на рабочий стол
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
function Msg($t, $i = 'Information') { [System.Windows.Forms.MessageBox]::Show($t, 'Запись флешек', 'OK', $i) | Out-Null }

try {
    $src = Join-Path $PSScriptRoot 'flash-writer.ps1'
    if (-not (Test-Path -LiteralPath $src)) {
        throw "Не найден файл flash-writer.ps1 рядом с установщиком.`r`nСначала РАСПАКУЙТЕ архив (правая кнопка → «Извлечь всё»), потом запустите Установить.cmd из распакованной папки."
    }
    $dir = Join-Path $env:LOCALAPPDATA 'FlashWriter'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $dst = Join-Path $dir 'flash-writer.ps1'
    Copy-Item -LiteralPath $src -Destination $dst -Force
    Unblock-File -LiteralPath $dst -ErrorAction SilentlyContinue

    $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $icon  = (Join-Path $env:SystemRoot 'System32\shell32.dll') + ',7'
    $menu  = 'Записать на флешки (работа)'
    $cmd   = '"' + $psExe + '" -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $dst + '"'
    $targets = @(
        @{ Key = 'Software\Classes\Drive\shell\FlashWriter';                Arg = '-Kind drive -Path "%1"' },
        @{ Key = 'Software\Classes\Directory\shell\FlashWriter';            Arg = '-Kind folder -Path "%1"' },
        @{ Key = 'Software\Classes\Directory\Background\shell\FlashWriter'; Arg = '-Kind folder -Path "%V"' },
        @{ Key = 'Software\Classes\*\shell\FlashWriter';                    Arg = '-Kind file -Path "%1"' }
    )
    foreach ($t in $targets) {
        $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($t.Key)
        $k.SetValue('MUIVerb', $menu); $k.SetValue('Icon', $icon); $k.Close()
        $c = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($t.Key + '\command')
        $c.SetValue('', $cmd + ' ' + $t.Arg); $c.Close()
    }

    # Ярлык на рабочем столе и в меню «Пуск»
    $sh = New-Object -ComObject WScript.Shell
    $places = @([Environment]::GetFolderPath('Desktop'), (Join-Path ([Environment]::GetFolderPath('Programs')) ''))
    $made = @()
    foreach ($p in $places) {
        if (-not $p -or -not (Test-Path -LiteralPath $p)) { continue }
        $lnkPath = Join-Path $p 'Запись флешек.lnk'
        $s = $sh.CreateShortcut($lnkPath)
        $s.TargetPath = $psExe
        $s.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $dst + '"'
        $s.WorkingDirectory = $dir
        $s.IconLocation = $icon
        $s.Description = 'Запись флешек — אליעזר הפקות'
        $s.Save()
        if (Test-Path -LiteralPath $lnkPath) { $made += $lnkPath }
    }
    if ($made.Count -eq 0) { throw 'Не удалось создать ярлык на рабочем столе.' }

    Msg ("Установлено!`r`n`r`nЯрлык «Запись флешек» — на рабочем столе и в меню «Пуск».`r`n`r`nПравая кнопка на флешку, папку работы или файлы → «$menu».`r`n(В Windows 11 сначала «Показать дополнительные параметры».)")
}
catch {
    Msg ("Установка не прошла:`r`n`r`n" + $_.Exception.Message) 'Error'
    exit 1
}
