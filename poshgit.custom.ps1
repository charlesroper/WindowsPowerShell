Push-Location (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent)

# Set up a prompt, adding the git prompt parts inside git repos
function prompt {
    $originalLastExitCode = $LASTEXITCODE

    write-host ([Environment]::UserName + '@' + [Environment]::MachineName) -NoNewline -ForegroundColor Green
    $maxPathLength = 40
    $curPath = $ExecutionContext.SessionState.Path.CurrentLocation.Path.Replace($env:Home, '~')
    if ($curPath.Length -gt $maxPathLength) {
        $curPath = '...' + $curPath.SubString($curPath.Length - $maxPathLength + 3)
    }
    Write-Host (' ' + $curPath) -NoNewline -ForegroundColor DarkCyan
    Write-VcsStatus

    $global:LASTEXITCODE = $originalLastExitCode

    Write-Host ("`nPS") -NoNewline -ForegroundColor Cyan
    return " > "
}

# Look for modules on $env:PSModulePath)
Import-Module posh-git

Pop-Location