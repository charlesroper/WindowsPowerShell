Push-Location (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent)

# Load posh-git module from current directory
# Import-Module .\posh-git

# If module is installed in a default location ($env:PSModulePath),
# use this instead (see about_Modules for more information):
Import-Module posh-git


# Set up a prompt, adding the git prompt parts inside git repos
function global:prompt {
    $realLASTEXITCODE = $LASTEXITCODE

    # Reset color, which can be messed up by Enable-GitColors
    $Host.UI.RawUI.ForegroundColor = $GitPromptSettings.DefaultForegroundColor

    write-host ([Environment]::UserName + '@' + [Environment]::MachineName) -NoNewline -ForegroundColor Green
    write-host (' ' + $pwd.Path.Replace($env:Home, '~')) -NoNewline -ForegroundColor DarkCyan
    Write-VcsStatus

    $global:LASTEXITCODE = $realLASTEXITCODE
    Write-Host ("`nPS") -NoNewline -ForegroundColor Cyan
    return " > "

}

Pop-Location

Start-SshAgent -Quiet
