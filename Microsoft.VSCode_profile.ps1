# Load my default PowerShell profile into the integrated VSCode terminal
$docs = [System.Environment]::GetFolderPath("mydocuments")
. (Join-Path -Path $docs -ChildPath 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')

$ThemeSettings.GitSymbols.BranchSymbol = [char]::ConvertFromUtf32(0x03BB)
$ThemeSettings.GitSymbols.BranchIdenticalStatusToSymbol = [char]::ConvertFromUtf32(0x2263)