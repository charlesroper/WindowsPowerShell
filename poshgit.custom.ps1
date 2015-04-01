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

    # Improved prompt
    # http://ss64.com/ps/syntax-prompt.html
    # Write-Host('PS ' + ($pwd -split '\\')[0]+' '+$(($pwd -split '\\')[-1] -join '\')) -NoNewline

    write-host ([net.dns]::GetHostName()) -NoNewline -ForegroundColor Green
    write-host (' ' + $pwd.Path.Replace($env:Home, '~')) -NoNewline -ForegroundColor DarkCyan
    Write-VcsStatus

    $global:LASTEXITCODE = $realLASTEXITCODE
    Write-Host ("`nPS") -NoNewline -ForegroundColor Cyan
    return " > "
    
}

Enable-GitColors

Pop-Location

Start-SshAgent -Quiet