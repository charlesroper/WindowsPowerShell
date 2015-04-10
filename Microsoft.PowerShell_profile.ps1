﻿# Load Scripts
$env:Path += ";$(Split-Path $profile)\Scripts"

function Get-Path {
  param ($cmd)
  Get-Command $cmd | Select Path
}
Set-Alias which Get-Path

# Load PSReadline
# https://rkeithhill.wordpress.com/2013/10/18/psreadline-a-better-line-editing-experience-for-the-powershell-console/
If($host.Name -eq 'ConsoleHost') {import-module PSReadline}

# cd -
# Alias for going back to previous directory
# http://windows-powershell-scripts.blogspot.co.uk/2009/07/cd-change-to-previous-working-directory.html
function cddash {

    if ($args[0] -eq '-') {
        $pwd=$OLDPWD;
    } else {
        $pwd=$args[0];
    }

    $tmp=pwd;

    if ($pwd) {
        Set-Location $pwd;
    }

    Set-Variable -Name OLDPWD -Value $tmp -Scope global;
}

set-alias -Name cd -value cddash -Option AllScope

# Coloured directory listings
# http://avinmathew.com/coloured-directory-listings-in-powershell/
New-CommandWrapper Out-Default -Process {
  $regex_opts = ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $compressed = New-Object System.Text.RegularExpressions.Regex(
    '\.(zip|tar|gz|rar|jar|war)$', $regex_opts)
  $executable = New-Object System.Text.RegularExpressions.Regex(
    '\.(exe|bat|cmd|msi|ps1|psm1|vbs|reg)$', $regex_opts)

  if(($_ -is [System.IO.DirectoryInfo]) -or ($_ -is [System.IO.FileInfo]))
  {
    if(-not ($notfirst))
    {
      Write-Host "`n    Directory: " -noNewLine
      Write-Host "$(pwd)`n" -foregroundcolor "Cyan"
      Write-Host "Mode        Last Write Time       Length   Name"
      Write-Host "----        ---------------       ------   ----"
      $notfirst=$true
    }

    if ($_ -is [System.IO.DirectoryInfo])
    {
      Write-Host ("{0}   {1}                {2}" -f $_.mode, ([String]::Format("{0,10} {1,8}", $_.LastWriteTime.ToString("d"), $_.LastWriteTime.ToString("t"))), $_.name) -ForegroundColor "Cyan"
    }
    else
    {
      if ($compressed.IsMatch($_.Name))
      {
        $color = "DarkGreen"
      }
      elseif ($executable.IsMatch($_.Name))
      {
        $color =  "Red"
      }
      else
      {
        $color = "White"
      }
      Write-Host ("{0}   {1}   {2,10}   {3}" -f $_.mode, ([String]::Format("{0,10} {1,8}", $_.LastWriteTime.ToString("d"), $_.LastWriteTime.ToString("t"))), $_.length, $_.name) -ForegroundColor $color
    }

    $_ = $null
  }
} -end {
  Write-Host
}

function Get-DirSize
{
  param ($dir)
  $bytes = 0
  $count = 0

  Get-Childitem $dir | Foreach-Object {
    if ($_ -is [System.IO.FileInfo])
    {
      $bytes += $_.Length
      $count++
    }
  }

  Write-Host "`n    " -NoNewline

  if ($bytes -ge 1KB -and $bytes -lt 1MB)
  {
    Write-Host ("" + [Math]::Round(($bytes / 1KB), 2) + " KB") -ForegroundColor "White" -NoNewLine
  }
  elseif ($bytes -ge 1MB -and $bytes -lt 1GB)
  {
    Write-Host ("" + [Math]::Round(($bytes / 1MB), 2) + " MB") -ForegroundColor "White" -NoNewLine
  }
  elseif ($bytes -ge 1GB)
  {
    Write-Host ("" + [Math]::Round(($bytes / 1GB), 2) + " GB") -ForegroundColor "White" -NoNewLine
  }
  else
  {
    Write-Host ("" + $bytes + " bytes") -ForegroundColor "White" -NoNewLine
  }
  Write-Host " in " -NoNewline
  Write-Host $count -ForegroundColor "White" -NoNewline
  Write-Host " files"

}

function Get-DirWithSize
{
  param ($dir)
  Get-Childitem $dir
  Get-DirSize $dir
}

Remove-Item alias:dir
Remove-Item alias:ls
Set-Alias dir Get-DirWithSize
Set-Alias ls Get-DirWithSize

# Load posh-git custom profile
. 'C:\Users\Charles\Documents\WindowsPowerShell\poshgit.custom.ps1'

