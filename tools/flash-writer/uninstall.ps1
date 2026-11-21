# Удаление «Запись флешек»
foreach ($k in @('Software\Classes\Drive\shell\FlashWriter','Software\Classes\Directory\shell\FlashWriter','Software\Classes\Directory\Background\shell\FlashWriter','Software\Classes\*\shell\FlashWriter')) {
    try { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($k, $false) } catch {}
}
Remove-Item -LiteralPath (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Запись флешек.lnk') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $env:LOCALAPPDATA 'FlashWriter\flash-writer.ps1') -Force -ErrorAction SilentlyContinue
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show('Программа удалена.', 'Запись флешек') | Out-Null
