# Load my default PowerShell profile into the integrated VSCode terminal
$docs = [System.Environment]::GetFolderPath("mydocuments")
. (Join-Path -Path $docs -ChildPath 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')