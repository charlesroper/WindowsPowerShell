# Load Scripts
$env:Path += ";$(Split-Path $profile)\Scripts"

# Setup a Which alias
function Get-Path {
  param ($cmd)
  Get-Command -Name $cmd | Select-Object Path
}
Set-Alias which Get-Path

# Load PSReadline
# https://rkeithhill.wordpress.com/2013/10/18/psreadline-a-better-line-editing-experience-for-the-powershell-console/
If ($host.Name -eq 'ConsoleHost') { Import-Module -Name PSReadline }
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# cd -
# Alias for going back to previous directory
# http://windows-powershell-scripts.blogspot.co.uk/2009/07/cd-change-to-previous-working-directory.html
function cddash {

  if ($args[0] -eq '-') {
    $pwd = $OLDPWD;
  }
  else {
    $pwd = $args[0];
  }

  $tmp = Get-Location;

  if ($pwd) {
    Set-Location $pwd;
  }

  Set-Variable -Name OLDPWD -Value $tmp -Scope global;
}

Set-Alias -Name cd -Value cddash -Option AllScope

# Coloured directory listings
# http://avinmathew.com/coloured-directory-listings-in-powershell/
New-CommandWrapper Out-Default -Process {
  $regex_opts = ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $compressed = New-Object System.Text.RegularExpressions.Regex(
    '\.(zip|tar|gz|rar|jar|war)$', $regex_opts)
  $executable = New-Object System.Text.RegularExpressions.Regex(
    '\.(exe|bat|cmd|msi|ps1|psm1|vbs|reg)$', $regex_opts)

  if (($_ -is [System.IO.DirectoryInfo]) -or ($_ -is [System.IO.FileInfo])) {
    if (-not ($notfirst)) {
      Write-Host "`n    Directory: " -noNewLine
      Write-Host "$(Get-Location)`n" -foregroundcolor "Cyan"
      Write-Host "Mode     Last Write     Time       Length   Name"
      Write-Host "------   -------------------       ------   ----"
      $notfirst = $true
    }

    if ($_ -is [System.IO.DirectoryInfo]) {
      Write-Host ("{0}   {1}                {2}" -f $_.mode, ([String]::Format("{0,10} {1,8}", $_.LastWriteTime.ToString("d"), $_.LastWriteTime.ToString("t"))), $_.name) -ForegroundColor "Cyan"
    }
    else {
      if ($compressed.IsMatch($_.Name)) {
        $color = "DarkGreen"
      }
      elseif ($executable.IsMatch($_.Name)) {
        $color = "Red"
      }
      else {
        $color = "White"
      }
      Write-Host ("{0}   {1}   {2,10}   {3}" -f $_.mode, ([String]::Format("{0,10} {1,8}", $_.LastWriteTime.ToString("d"), $_.LastWriteTime.ToString("t"))), $_.length, $_.name) -ForegroundColor $color
    }

    $_ = $null
  }
} -end {
  Write-Host
}

function Get-DirSize {
  param ($dir)
  $bytes = 0
  $count = 0

  Get-Childitem $dir | Foreach-Object {
    if ($_ -is [System.IO.FileInfo]) {
      $bytes += $_.Length
      $count++
    }
  }

  Write-Host "`n    " -NoNewline

  if ($bytes -ge 1KB -and $bytes -lt 1MB) {
    Write-Host ("" + [Math]::Round(($bytes / 1KB), 2) + " KB") -ForegroundColor "White" -NoNewLine
  }
  elseif ($bytes -ge 1MB -and $bytes -lt 1GB) {
    Write-Host ("" + [Math]::Round(($bytes / 1MB), 2) + " MB") -ForegroundColor "White" -NoNewLine
  }
  elseif ($bytes -ge 1GB) {
    Write-Host ("" + [Math]::Round(($bytes / 1GB), 2) + " GB") -ForegroundColor "White" -NoNewLine
  }
  else {
    Write-Host ("" + $bytes + " bytes") -ForegroundColor "White" -NoNewLine
  }
  Write-Host " in " -NoNewline
  Write-Host $count -ForegroundColor "White" -NoNewline
  Write-Host " files"

}

function Get-DirWithSize {
  param ($dir)
  Get-Childitem $dir
  Get-DirSize $dir
}

Remove-Item alias:dir
Remove-Item alias:ls
Set-Alias dir Get-DirWithSize
Set-Alias ls Get-DirWithSize

Remove-Item alias:cat 
Set-Alias cat bat
Set-Alias find fd

# Load posh-sshell
Import-Module posh-sshell

# Load posh-git custom profile
$docs = [System.Environment]::GetFolderPath("mydocuments")
. (Join-Path -Path $docs -ChildPath 'WindowsPowerShell\poshgit.custom.ps1')
#. 'C:\Users\charlesr\Documents\WindowsPowerShell\poshgit.custom.ps1'

# Load oh-my-posh
$DefaultUser = 'Charles'
Import-Module oh-my-posh
Set-Theme Avit2
# $ThemeSettings.GitSymbols.BranchAheadStatusSymbol = [char]::ConvertFromUtf32(0xf47e)
# $ThemeSettings.GitSymbols.BranchBehindStatusSymbol = [char]::ConvertFromUtf32(0xf44b)
# $ThemeSettings.GitSymbols.BranchUntrackedSymbol = [char]::ConvertFromUtf32(0xf421)
# $ThemeSettings.GitSymbols.BranchIdenticalStatusToSymbol = [char]::ConvertFromUtf32(0xf44e)
# $ThemeSettings.GitSymbols.BranchSymbol = [char]::ConvertFromUtf32(0xf418)
$ThemeSettings.GitSymbols.BranchSymbol = [char]::ConvertFromUtf32(0x03BB)
$ThemeSettings.GitSymbols.BranchIdenticalStatusToSymbol = [char]::ConvertFromUtf32(0x2261)
$ThemeSettings.PromptSymbols.PromptIndicator = 'PS>'
$ThemeSettings.PromptSymbols.FailedCommandSymbol = '×'

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}

# Get External IP function
function Get-ExternalIP {
  (Invoke-WebRequest api.ipify.org).Content
}

