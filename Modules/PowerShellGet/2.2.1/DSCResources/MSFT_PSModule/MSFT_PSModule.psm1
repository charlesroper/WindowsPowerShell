#
# Copyright (c) Microsoft Corporation.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

$resourceModuleRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent

# Import localization helper functions.
$helperName = 'PowerShellGet.LocalizationHelper'
$dscResourcesFolderFilePath = Join-Path -Path $resourceModuleRoot -ChildPath "Modules\$helperName\$helperName.psm1"
Import-Module -Name $dscResourcesFolderFilePath

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_PSModule' -ScriptRoot $PSScriptRoot

# Import resource helper functions.
$helperName = 'PowerShellGet.ResourceHelper'
$dscResourcesFolderFilePath = Join-Path -Path $resourceModuleRoot -ChildPath "Modules\$helperName\$helperName.psm1"
Import-Module -Name $dscResourcesFolderFilePath

<#
    .SYNOPSIS
        This DSC resource provides a mechanism to download PowerShell modules from the PowerShell
        Gallery and install it on your computer.

        Get-TargetResource returns the current state of the resource.

    .PARAMETER Name
        Specifies the name of the PowerShell module to be installed or uninstalled.

    .PARAMETER Repository
        Specifies the name of the module source repository where the module can be found.

    .PARAMETER RequiredVersion
        Provides the version of the module you want to install or uninstall.

    .PARAMETER MaximumVersion
        Provides the maximum version of the module you want to install or uninstall.

    .PARAMETER MinimumVersion
        Provides the minimum version of the module you want to install or uninstall.

    .PARAMETER Force
        Forces the installation of modules. If a module of the same name and version already exists on the computer,
        this parameter overwrites the existing module with one of the same name that was found by the command.

    .PARAMETER AllowClobber
        Allows the installation of modules regardless of if other existing module on the computer have cmdlets
        of the same name.

    .PARAMETER SkipPublisherCheck
        Allows the installation of modules that have not been catalog signed.
#>
function Get-TargetResource {
    <#
        These suppressions are added because this repository have other Visual Studio Code workspace
        settings than those in DscResource.Tests DSC test framework.
        Only those suppression that contradict this repository guideline is added here.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ForEachStatement', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-FunctionBlockBraces', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-IfStatement', '')]
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $Repository = 'PSGallery',

        [Parameter()]
        [System.String]
        $RequiredVersion,

        [Parameter()]
        [System.String]
        $MaximumVersion,

        [Parameter()]
        [System.String]
        $MinimumVersion,

        [Parameter()]
        [System.Boolean]
        $Force,

        [Parameter()]
        [System.Boolean]
        $AllowClobber,

        [Parameter()]
        [System.Boolean]
        $SkipPublisherCheck
    )

    $returnValue = @{
        Ensure             = 'Absent'
        Name               = $Name
        Repository         = $Repository
        Description        = $null
        Guid               = $null
        ModuleBase         = $null
        ModuleType         = $null
        Author             = $null
        InstalledVersion   = $null
        RequiredVersion    = $RequiredVersion
        MinimumVersion     = $MinimumVersion
        MaximumVersion     = $MaximumVersion
        Force              = $Force
        AllowClobber       = $AllowClobber
        SkipPublisherCheck = $SkipPublisherCheck
        InstallationPolicy = $null
    }

    Write-Verbose -Message ($localizedData.GetTargetResourceMessage -f $Name)

    $extractedArguments = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters `
        -ArgumentNames ('Name', 'Repository', 'MinimumVersion', 'MaximumVersion', 'RequiredVersion')

    # Get the module with the right version and repository properties.
    $modules = Get-RightModule @extractedArguments -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    # If the module is found, the count > 0
    if ($modules.Count -gt 0) {
        Write-Verbose -Message ($localizedData.ModuleFound -f $Name)

        # Find a module with the latest version and return its properties.
        $latestModule = $modules[0]

        foreach ($module in $modules) {
            if ($module.Version -gt $latestModule.Version) {
                $latestModule = $module
            }
        }

        # Check if the repository matches.
        $repositoryName = Get-ModuleRepositoryName -Module $latestModule -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        if ($repositoryName) {
            $installationPolicy = Get-InstallationPolicy -RepositoryName $repositoryName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        }

        if ($installationPolicy) {
            $installationPolicyReturnValue = 'Trusted'
        }
        else {
            $installationPolicyReturnValue = 'Untrusted'
        }

        $returnValue.Ensure = 'Present'
        $returnValue.Repository = $repositoryName
        $returnValue.Description = $latestModule.Description
        $returnValue.Guid = $latestModule.Guid
        $returnValue.ModuleBase = $latestModule.ModuleBase
        $returnValue.ModuleType = $latestModule.ModuleType
        $returnValue.Author = $latestModule.Author
        $returnValue.InstalledVersion = $latestModule.Version
        $returnValue.InstallationPolicy = $installationPolicyReturnValue
    }
    else {
        Write-Verbose -Message ($localizedData.ModuleNotFound -f $Name)
    }

    return $returnValue
}

<#
    .SYNOPSIS
        This DSC resource provides a mechanism to download PowerShell modules from the PowerShell
        Gallery and install it on your computer.

        Test-TargetResource validates whether the resource is currently in the desired state.

    .PARAMETER Ensure
        Determines whether the module to be installed or uninstalled.

    .PARAMETER Name
        Specifies the name of the PowerShell module to be installed or uninstalled.

    .PARAMETER Repository
        Specifies the name of the module source repository where the module can be found.

    .PARAMETER InstallationPolicy
        Determines whether you trust the source repository where the module resides.

    .PARAMETER RequiredVersion
        Provides the version of the module you want to install or uninstall.

    .PARAMETER MaximumVersion
        Provides the maximum version of the module you want to install or uninstall.

    .PARAMETER MinimumVersion
        Provides the minimum version of the module you want to install or uninstall.

    .PARAMETER Force
        Forces the installation of modules. If a module of the same name and version already exists on the computer,
        this parameter overwrites the existing module with one of the same name that was found by the command.

    .PARAMETER AllowClobber
        Allows the installation of modules regardless of if other existing module on the computer have cmdlets
        of the same name.

    .PARAMETER SkipPublisherCheck
        Allows the installation of modules that have not been catalog signed.
#>
function Test-TargetResource {
    <#
        These suppressions are added because this repository have other Visual Studio Code workspace
        settings than those in DscResource.Tests DSC test framework.
        Only those suppression that contradict this repository guideline is added here.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-FunctionBlockBraces', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-IfStatement', '')]
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $Repository = 'PSGallery',

        [Parameter()]
        [ValidateSet('Trusted', 'Untrusted')]
        [System.String]
        $InstallationPolicy = 'Untrusted',

        [Parameter()]
        [System.String]
        $RequiredVersion,

        [Parameter()]
        [System.String]
        $MaximumVersion,

        [Parameter()]
        [System.String]
        $MinimumVersion,

        [Parameter()]
        [System.Boolean]
        $Force,

        [Parameter()]
        [System.Boolean]
        $AllowClobber,

        [Parameter()]
        [System.Boolean]
        $SkipPublisherCheck
    )

    Write-Verbose -Message ($localizedData.TestTargetResourceMessage -f $Name)

    $extractedArguments = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters `
        -ArgumentNames ('Name', 'Repository', 'MinimumVersion', 'MaximumVersion', 'RequiredVersion')

    $status = Get-TargetResource @extractedArguments

    # The ensure returned from Get-TargetResource is not equal to the desired $Ensure.
    if ($status.Ensure -ieq $Ensure) {
        Write-Verbose -Message ($localizedData.InDesiredState -f $Name)
        return $true
    }
    else {
        Write-Verbose -Message ($localizedData.NotInDesiredState -f $Name)
        return $false
    }
}

<#
    .SYNOPSIS
        This DSC resource provides a mechanism to download PowerShell modules from the PowerShell
        Gallery and install it on your computer.

        Set-TargetResource sets the resource to the desired state. "Make it so".

    .PARAMETER Ensure
        Determines whether the module to be installed or uninstalled.

    .PARAMETER Name
        Specifies the name of the PowerShell module to be installed or uninstalled.

    .PARAMETER Repository
        Specifies the name of the module source repository where the module can be found.

    .PARAMETER InstallationPolicy
        Determines whether you trust the source repository where the module resides.

    .PARAMETER RequiredVersion
        Provides the version of the module you want to install or uninstall.

    .PARAMETER MaximumVersion
        Provides the maximum version of the module you want to install or uninstall.

    .PARAMETER MinimumVersion
        Provides the minimum version of the module you want to install or uninstall.

    .PARAMETER Force
        Forces the installation of modules. If a module of the same name and version already exists on the computer,
        this parameter overwrites the existing module with one of the same name that was found by the command.

    .PARAMETER AllowClobber
        Allows the installation of modules regardless of if other existing module on the computer have cmdlets
        of the same name.

    .PARAMETER SkipPublisherCheck
        Allows the installation of modules that have not been catalog signed.
#>
function Set-TargetResource {
    <#
        These suppressions are added because this repository have other Visual Studio Code workspace
        settings than those in DscResource.Tests DSC test framework.
        Only those suppression that contradict this repository guideline is added here.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ForEachStatement', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-FunctionBlockBraces', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-IfStatement', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-TryStatement', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-CatchClause', '')]
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $Repository = 'PSGallery',

        [Parameter()]
        [ValidateSet('Trusted', 'Untrusted')]
        [System.String]
        $InstallationPolicy = 'Untrusted',

        [Parameter()]
        [System.String]
        $RequiredVersion,

        [Parameter()]
        [System.String]
        $MaximumVersion,

        [Parameter()]
        [System.String]
        $MinimumVersion,

        [Parameter()]
        [System.Boolean]
        $Force,

        [Parameter()]
        [System.Boolean]
        $AllowClobber,

        [Parameter()]
        [System.Boolean]
        $SkipPublisherCheck
    )

    # Validate the repository argument
    if ($PSBoundParameters.ContainsKey('Repository')) {
        Test-ParameterValue -Value $Repository -Type 'PackageSource' -ProviderName 'PowerShellGet' -Verbose
    }

    if ($Ensure -ieq 'Present') {
        # Version check
        $extractedArguments = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters `
            -ArgumentNames ('MinimumVersion', 'MaximumVersion', 'RequiredVersion')

        $null = Test-VersionParameter @extractedArguments

        try {
            $extractedArguments = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters `
                -ArgumentNames ('Name', 'Repository', 'MinimumVersion', 'MaximumVersion', 'RequiredVersion')

            Write-Verbose -Message ($localizedData.StartFindModule -f $Name)

            $modules = Find-Module @extractedArguments -ErrorVariable ev
        }
        catch {
            $errorMessage = $script:localizedData.ModuleNotFoundInRepository -f $Name
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }

        $trusted = $null
        $moduleFound = $null

        foreach ($m in $modules) {
            # Check for the installation policy.
            $trusted = Get-InstallationPolicy -RepositoryName $m.Repository -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

            # Stop the loop if found a trusted repository.
            if ($trusted) {
                $moduleFound = $m
                break;
            }
        }

        try {
            # The repository is trusted, so we install it.
            if ($trusted) {
                Write-Verbose -Message ($localizedData.StartInstallModule -f $Name, $moduleFound.Version.toString(), $moduleFound.Repository)

                # Extract the installation options.
                $extractedSwitches = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters -ArgumentNames ('Force', 'AllowClobber', 'SkipPublisherCheck')

                $moduleFound | Install-Module @extractedSwitches 2>&1 | out-string | Write-Verbose
            }
            # The repository is untrusted but user's installation policy is trusted, so we install it with a warning.
            elseif ($InstallationPolicy -ieq 'Trusted') {
                Write-Warning -Message ($localizedData.InstallationPolicyWarning -f $Name, $modules[0].Repository, $InstallationPolicy)

                # Extract installation options (Force implied by InstallationPolicy).
                $extractedSwitches = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters -ArgumentNames ('AllowClobber', 'SkipPublisherCheck')

                # If all the repositories are untrusted, we choose the first one.
                $modules[0] | Install-Module @extractedSwitches -Force 2>&1 | out-string | Write-Verbose
            }
            # Both user and repository is untrusted
            else {
                $errorMessage = $script:localizedData.InstallationPolicyFailed -f $InstallationPolicy, 'Untrusted'
                New-InvalidOperationException -Message $errorMessage
            }

            Write-Verbose -Message ($localizedData.InstalledSuccess -f $Name)
        }
        catch {
            $errorMessage = $script:localizedData.FailToInstall -f $Name
            New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
        }
    }
    # Ensure=Absent
    else {

        $extractedArguments = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters `
            -ArgumentNames ('Name', 'Repository', 'MinimumVersion', 'MaximumVersion', 'RequiredVersion')

        # Get the module with the right version and repository properties.
        $modules = Get-RightModule @extractedArguments

        if (-not $modules) {
            $errorMessage = $script:localizedData.ModuleWithRightPropertyNotFound -f $Name
            New-InvalidOperationException -Message $errorMessage
        }

        foreach ($module in $modules) {
            # Get the path where the module is installed.
            $path = $module.ModuleBase

            Write-Verbose -Message ($localizedData.StartUnInstallModule -f $Name)

            try {
                <#
                    There is no Uninstall-Module cmdlet for Windows PowerShell 4.0,
                    so we will remove the ModuleBase folder as an uninstall operation.
                #>
                Microsoft.PowerShell.Management\Remove-Item -Path $path -Force -Recurse

                Write-Verbose -Message ($localizedData.UnInstalledSuccess -f $module.Name)
            }
            catch {
                $errorMessage = $script:localizedData.FailToUninstall -f $module.Name
                New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
            }
        } # foreach
    } # Ensure=Absent
}

<#
    .SYNOPSIS
        This is a helper function. It returns the modules that meet the specified versions and the repository requirements.

    .PARAMETER Name
        Specifies the name of the PowerShell module.

    .PARAMETER RequiredVersion
        Provides the version of the module you want to install or uninstall.

    .PARAMETER MaximumVersion
        Provides the maximum version of the module you want to install or uninstall.

    .PARAMETER MinimumVersion
        Provides the minimum version of the module you want to install or uninstall.

    .PARAMETER Repository
        Specifies the name of the module source repository where the module can be found.
#>
function Get-RightModule {
    <#
        These suppressions are added because this repository have other Visual Studio Code workspace
        settings than those in DscResource.Tests DSC test framework.
        Only those suppression that contradict this repository guideline is added here.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-ForEachStatement', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-FunctionBlockBraces', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-IfStatement', '')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $RequiredVersion,

        [Parameter()]
        [System.String]
        $MinimumVersion,

        [Parameter()]
        [System.String]
        $MaximumVersion,

        [Parameter()]
        [System.String]
        $Repository
    )

    Write-Verbose -Message ($localizedData.StartGetModule -f $($Name))

    $modules = Microsoft.PowerShell.Core\Get-Module -Name $Name -ListAvailable -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    if (-not $modules) {
        return $null
    }

    <#
        As Get-Module does not take RequiredVersion, MinimumVersion, MaximumVersion, or Repository,
        below we need to check whether the modules are containing the right version and repository
        location.
    #>

    $extractedArguments = New-SplatParameterHashTable -FunctionBoundParameters $PSBoundParameters `
        -ArgumentNames ('MaximumVersion', 'MinimumVersion', 'RequiredVersion')
    $returnVal = @()

    foreach ($m in $modules) {
        $versionMatch = $false
        $installedVersion = $m.Version

        # Case 1 - a user provides none of RequiredVersion, MinimumVersion, MaximumVersion
        if ($extractedArguments.Count -eq 0) {
            $versionMatch = $true
        }

        # Case 2 - a user provides RequiredVersion
        elseif ($extractedArguments.ContainsKey('RequiredVersion')) {
            # Check if it matches with the installed version
            $versionMatch = ($installedVersion -eq [System.Version] $RequiredVersion)
        }
        else {

            # Case 3 - a user provides MinimumVersion
            if ($extractedArguments.ContainsKey('MinimumVersion')) {
                $versionMatch = ($installedVersion -ge [System.Version] $extractedArguments['MinimumVersion'])
            }

            # Case 4 - a user provides MaximumVersion
            if ($extractedArguments.ContainsKey('MaximumVersion')) {
                $isLessThanMax = ($installedVersion -le [System.Version] $extractedArguments['MaximumVersion'])

                if ($extractedArguments.ContainsKey('MinimumVersion')) {
                    $versionMatch = $versionMatch -and $isLessThanMax
                }
                else {
                    $versionMatch = $isLessThanMax
                }
            }

            # Case 5 - Both MinimumVersion and MaximumVersion are provided. It's covered by the above.
            # Do not return $false yet to allow the foreach to continue
            if (-not $versionMatch) {
                Write-Verbose -Message ($localizedData.VersionMismatch -f $Name, $installedVersion)
                $versionMatch = $false
            }
        }

        # Case 6 - Version matches but need to check if the module is from the right repository.
        if ($versionMatch) {
            # A user does not provide Repository, we are good
            if (-not $PSBoundParameters.ContainsKey('Repository')) {
                Write-Verbose -Message ($localizedData.ModuleFound -f "$Name $installedVersion")
                $returnVal += $m
            }
            else {
                # Check if the Repository matches
                $sourceName = Get-ModuleRepositoryName -Module $m

                if ($Repository -ieq $sourceName) {
                    Write-Verbose -Message ($localizedData.ModuleFound -f "$Name $installedVersion")
                    $returnVal += $m
                }
                else {
                    Write-Verbose -Message ($localizedData.RepositoryMismatch -f $($Name), $($sourceName))
                }
            }
        }
    } # foreach

    return $returnVal
}

<#
    .SYNOPSIS
        This is a helper function that returns the module's repository name.

    .PARAMETER Module
        Specifies the name of the PowerShell module.
#>
function Get-ModuleRepositoryName {
    <#
        These suppressions are added because this repository have other Visual Studio Code workspace
        settings than those in DscResource.Tests DSC test framework.
        Only those suppression that contradict this repository guideline is added here.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-FunctionBlockBraces', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('DscResource.AnalyzerRules\Measure-IfStatement', '')]
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Object]
        $Module
    )

    <#
        RepositorySourceLocation property is supported in PS V5 only. To work with the earlier
        PowerShell version, we need to do a different way. PSGetModuleInfo.xml exists for any
        PowerShell modules downloaded through PSModule provider.
    #>
    $psGetModuleInfoFileName = 'PSGetModuleInfo.xml'
    $psGetModuleInfoPath = Microsoft.PowerShell.Management\Join-Path -Path $Module.ModuleBase -ChildPath $psGetModuleInfoFileName

    Write-Verbose -Message ($localizedData.FoundModulePath -f $psGetModuleInfoPath)

    if (Microsoft.PowerShell.Management\Test-path -Path $psGetModuleInfoPath) {
        $psGetModuleInfo = Microsoft.PowerShell.Utility\Import-Clixml -Path $psGetModuleInfoPath

        return $psGetModuleInfo.Repository
    }
}

# SIG # Begin signature block
# MIIkWwYJKoZIhvcNAQcCoIIkTDCCJEgCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCig4H1kVMWxA7U
# uX1JaRBJmDsHSZHmuBUTkDBwWHafCqCCDYEwggX/MIID56ADAgECAhMzAAABUZ6N
# j0Bxow5BAAAAAAFRMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTkwNTAyMjEzNzQ2WhcNMjAwNTAyMjEzNzQ2WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCVWsaGaUcdNB7xVcNmdfZiVBhYFGcn8KMqxgNIvOZWNH9JYQLuhHhmJ5RWISy1
# oey3zTuxqLbkHAdmbeU8NFMo49Pv71MgIS9IG/EtqwOH7upan+lIq6NOcw5fO6Os
# +12R0Q28MzGn+3y7F2mKDnopVu0sEufy453gxz16M8bAw4+QXuv7+fR9WzRJ2CpU
# 62wQKYiFQMfew6Vh5fuPoXloN3k6+Qlz7zgcT4YRmxzx7jMVpP/uvK6sZcBxQ3Wg
# B/WkyXHgxaY19IAzLq2QiPiX2YryiR5EsYBq35BP7U15DlZtpSs2wIYTkkDBxhPJ
# IDJgowZu5GyhHdqrst3OjkSRAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUV4Iarkq57esagu6FUBb270Zijc8w
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDU0MTM1MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAWg+A
# rS4Anq7KrogslIQnoMHSXUPr/RqOIhJX+32ObuY3MFvdlRElbSsSJxrRy/OCCZdS
# se+f2AqQ+F/2aYwBDmUQbeMB8n0pYLZnOPifqe78RBH2fVZsvXxyfizbHubWWoUf
# NW/FJlZlLXwJmF3BoL8E2p09K3hagwz/otcKtQ1+Q4+DaOYXWleqJrJUsnHs9UiL
# crVF0leL/Q1V5bshob2OTlZq0qzSdrMDLWdhyrUOxnZ+ojZ7UdTY4VnCuogbZ9Zs
# 9syJbg7ZUS9SVgYkowRsWv5jV4lbqTD+tG4FzhOwcRQwdb6A8zp2Nnd+s7VdCuYF
# sGgI41ucD8oxVfcAMjF9YX5N2s4mltkqnUe3/htVrnxKKDAwSYliaux2L7gKw+bD
# 1kEZ/5ozLRnJ3jjDkomTrPctokY/KaZ1qub0NUnmOKH+3xUK/plWJK8BOQYuU7gK
# YH7Yy9WSKNlP7pKj6i417+3Na/frInjnBkKRCJ/eYTvBH+s5guezpfQWtU4bNo/j
# 8Qw2vpTQ9w7flhH78Rmwd319+YTmhv7TcxDbWlyteaj4RK2wk3pY1oSz2JPE5PNu
# Nmd9Gmf6oePZgy7Ii9JLLq8SnULV7b+IP0UXRY9q+GdRjM2AEX6msZvvPCIoG0aY
# HQu9wZsKEK2jqvWi8/xdeeeSI9FN6K1w4oVQM4Mwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIWMDCCFiwCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAVGejY9AcaMOQQAAAAABUTAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg2t+ikpO2
# 0WdDEf/JRKsEEOWFz2O6CEnKmWwPbrvPFuIwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQAW5qGVR8bMFXZ8+cstci+iQl+XsRRdMgLpm6L8knT9
# dQ452Fnd1GbQsq//gRs5VAA8d+iP6Sr8yXfdMPgBzw+pEG5JeQWv5laOSNOP7HdR
# yxc1WqeacTF48a6xraUehhUNX1MfEajRscr5OtS1KH8r5sN0RSHzbDotp8EzEnnM
# 3WE9T9aOfxLrMzDKUY1qVDQzPkGOnQpXPP7WCKV8GUyH9XPNlqyxputgl3hjw2Hm
# Wj9IkuhvSoRoYMWWB2sHb9wd+1KtZXlwNh+6N4no22JzvGi/3Zyw8VKMc0BjhgJa
# j/wGYm/87IKMDn4zfy3ZXvrXIjO65bF6wOxilbY/NXpboYITujCCE7YGCisGAQQB
# gjcDAwExghOmMIITogYJKoZIhvcNAQcCoIITkzCCE48CAQMxDzANBglghkgBZQME
# AgEFADCCAVgGCyqGSIb3DQEJEAEEoIIBRwSCAUMwggE/AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIMiT/6yhJUk4MRyBsEm/bOH5i15s87EIxK88LmCD
# vmyhAgZdPzJ9/7wYEzIwMTkwODE2MjM0MzIzLjIzNFowBwIBAYACAfSggdSkgdEw
# gc4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsT
# IE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFs
# ZXMgVFNTIEVTTjpCOEVDLTMwQTQtNzE0NDElMCMGA1UEAxMcTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgU2VydmljZaCCDyIwggZxMIIEWaADAgECAgphCYEqAAAAAAACMA0G
# CSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3Jp
# dHkgMjAxMDAeFw0xMDA3MDEyMTM2NTVaFw0yNTA3MDEyMTQ2NTVaMHwxCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29m
# dCBUaW1lLVN0YW1wIFBDQSAyMDEwMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIB
# CgKCAQEAqR0NvHcRijog7PwTl/X6f2mUa3RUENWlCgCChfvtfGhLLF/Fw+Vhwna3
# PmYrW/AVUycEMR9BGxqVHc4JE458YTBZsTBED/FgiIRUQwzXTbg4CLNC3ZOs1nMw
# VyaCo0UN0Or1R4HNvyRgMlhgRvJYR4YyhB50YWeRX4FUsc+TTJLBxKZd0WETbijG
# GvmGgLvfYfxGwScdJGcSchohiq9LZIlQYrFd/XcfPfBXday9ikJNQFHRD5wGPmd/
# 9WbAA5ZEfu/QS/1u5ZrKsajyeioKMfDaTgaRtogINeh4HLDpmc085y9Euqf03GS9
# pAHBIAmTeM38vMDJRF1eFpwBBU8iTQIDAQABo4IB5jCCAeIwEAYJKwYBBAGCNxUB
# BAMCAQAwHQYDVR0OBBYEFNVjOlyKMZDzQ3t8RhvFM2hahW1VMBkGCSsGAQQBgjcU
# AgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8G
# A1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1UdHwRPME0wS6BJoEeG
# RWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jv
# b0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQROMEwwSgYIKwYBBQUH
# MAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljUm9vQ2Vy
# QXV0XzIwMTAtMDYtMjMuY3J0MIGgBgNVHSABAf8EgZUwgZIwgY8GCSsGAQQBgjcu
# AzCBgTA9BggrBgEFBQcCARYxaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL1BLSS9k
# b2NzL0NQUy9kZWZhdWx0Lmh0bTBABggrBgEFBQcCAjA0HjIgHQBMAGUAZwBhAGwA
# XwBQAG8AbABpAGMAeQBfAFMAdABhAHQAZQBtAGUAbgB0AC4gHTANBgkqhkiG9w0B
# AQsFAAOCAgEAB+aIUQ3ixuCYP4FxAz2do6Ehb7Prpsz1Mb7PBeKp/vpXbRkws8LF
# Zslq3/Xn8Hi9x6ieJeP5vO1rVFcIK1GCRBL7uVOMzPRgEop2zEBAQZvcXBf/XPle
# FzWYJFZLdO9CEMivv3/Gf/I3fVo/HPKZeUqRUgCvOA8X9S95gWXZqbVr5MfO9sp6
# AG9LMEQkIjzP7QOllo9ZKby2/QThcJ8ySif9Va8v/rbljjO7Yl+a21dA6fHOmWaQ
# jP9qYn/dxUoLkSbiOewZSnFjnXshbcOco6I8+n99lmqQeKZt0uGc+R38ONiU9Mal
# CpaGpL2eGq4EQoO4tYCbIjggtSXlZOz39L9+Y1klD3ouOVd2onGqBooPiRa6YacR
# y5rYDkeagMXQzafQ732D8OE7cQnfXXSYIghh2rBQHm+98eEA3+cxB6STOvdlR3jo
# +KhIq/fecn5ha293qYHLpwmsObvsxsvYgrRyzR30uIUBHoD7G4kqVDmyW9rIDVWZ
# eodzOwjmmC3qjeAzLhIp9cAvVCch98isTtoouLGp25ayp0Kiyc8ZQU3ghvkqmqMR
# ZjDTu3QyS99je/WZii8bxyGvWbWu3EQ8l1Bx16HSxVXjad5XwdHeMMD9zOZN+w2/
# XU/pnR4ZOC+8z1gFLu8NoFA12u8JJxzVs341Hgi62jbb01+P3nSISRIwggT1MIID
# 3aADAgECAhMzAAAAzDq9O3I4EQW6AAAAAADMMA0GCSqGSIb3DQEBCwUAMHwxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jv
# c29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMB4XDTE4MDgyMzIwMjYyNVoXDTE5MTEy
# MzIwMjYyNVowgc4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# KTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYD
# VQQLEx1UaGFsZXMgVFNTIEVTTjpCOEVDLTMwQTQtNzE0NDElMCMGA1UEAxMcTWlj
# cm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCASIwDQYJKoZIhvcNAQEBBQADggEP
# ADCCAQoCggEBAMfQVaWKJhVrFd3wd5i7tfnMU0sGcTEnEmTqPS8j+nlRKLVotbrf
# HVvTuguDClWIc1+lnsw6gnz+mgJT5Y6VzIGpwaRYTMe3cJ9X//XOZBa7xuXu9A46
# HiO2T5roJBkJ9lIt268voSvXmjGQA913N1nWhsc6UE4VuOsP56iHutiHStJ2AgMY
# rDrpJEBI2KUVk/XCEbpiIaZyEn59sh7iMBIk1OJp3ISjQXt+AYjxgSoWaqzSvN/o
# j1RWu+v0gFeLRBldrFihFO9PvZ3HqSJ6s7ctmOZkYnfmNjOwheVmdHj3QnuebbeY
# 0hODFtVXYlvQU7Dw2SBQ6XEcnl6xYHLlIosCAwEAAaOCARswggEXMB0GA1UdDgQW
# BBStqU2mSsJlEE/X63seIZoxM0jrqTAfBgNVHSMEGDAWgBTVYzpcijGQ80N7fEYb
# xTNoWoVtVTBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8vY3JsLm1pY3Jvc29mdC5j
# b20vcGtpL2NybC9wcm9kdWN0cy9NaWNUaW1TdGFQQ0FfMjAxMC0wNy0wMS5jcmww
# WgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRwOi8vd3d3Lm1pY3Jvc29m
# dC5jb20vcGtpL2NlcnRzL01pY1RpbVN0YVBDQV8yMDEwLTA3LTAxLmNydDAMBgNV
# HRMBAf8EAjAAMBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEBCwUAA4IB
# AQA9XV1qguniZVE1UsPJHL/gEWBWEKeYcuZDunghCMGzq3Ap20k8qsRjKEwmLpwj
# QK4ErHhgZLujYCCRkxpAcHcqUrzfBQl6hMbLqJwJNRmFu/7H4MJAckl+4lImOUsJ
# RAjiheHl67fq5V+i8LMBg8LYNPKy4kCoTUvS/qgUhOrVnQCqtENJTDMxjmOeezO9
# kvqPtvIx76DSdKtg+PXoE/UgXc3xL6RBeNix76MdU8lLOqg4S1Gs9B5KyxZv8Ttf
# f1yTU/E2kMwOf8QnzWnq5NfaDZ18TUzlyacL47GHW3K53TWdWyt+xfhYGrk0KVcH
# ipz1p92Ae1Be5X7pSiJrLtjfoYIDsDCCApgCAQEwgf6hgdSkgdEwgc4xCzAJBgNV
# BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4w
# HAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKTAnBgNVBAsTIE1pY3Jvc29m
# dCBPcGVyYXRpb25zIFB1ZXJ0byBSaWNvMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVT
# TjpCOEVDLTMwQTQtNzE0NDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAg
# U2VydmljZaIlCgEBMAkGBSsOAwIaBQADFQBz2ocx/S77PGis5+hGlHNEh7+WTaCB
# 3jCB26SB2DCB1TELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
# BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEp
# MCcGA1UECxMgTWljcm9zb2Z0IE9wZXJhdGlvbnMgUHVlcnRvIFJpY28xJzAlBgNV
# BAsTHm5DaXBoZXIgTlRTIEVTTjo1N0Y2LUMxRTAtNTU0QzErMCkGA1UEAxMiTWlj
# cm9zb2Z0IFRpbWUgU291cmNlIE1hc3RlciBDbG9jazANBgkqhkiG9w0BAQUFAAIF
# AOEBHsQwIhgPMjAxOTA4MTYxMjIzMzJaGA8yMDE5MDgxNzEyMjMzMlowdzA9Bgor
# BgEEAYRZCgQBMS8wLTAKAgUA4QEexAIBADAKAgEAAgIfswIB/zAHAgEAAgIafjAK
# AgUA4QJwRAIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMBoAowCAIB
# AAIDFuNgoQowCAIBAAIDB6EgMA0GCSqGSIb3DQEBBQUAA4IBAQBpSOfG+yMj9l7z
# fZueBIYnpIrnTETSn/8Toq9TG7euFmDRjDe2KGzZQIQONoxlLRrhdLVf5EhjfwRA
# R8giZxg50Lkhon9vsChV7QEOf9/F7/yRedkQYIEt2GYcA+9knvPtk6MoivoZ609S
# BxH2b1dlYw7FReXwhZQpUcuay/v6iLxRddP+zlKGeeLzszfl0Heec+iU7+3faeMh
# /L4sP12Ysxr3amQpIBbILHcQFCXwdEJZuifQd2t7ZmvGge/xgJsVz1ATatWx1QGg
# vjgAa9LUo79H4LoCX5s0nJAdXAl59vfaecYi+y+9KoJtZmlWHLHRfDaUpMVbGXwI
# 8AJCJlrMMYIC9TCCAvECAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAADMOr07cjgRBboAAAAAAMwwDQYJYIZIAWUDBAIBBQCgggEyMBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgiSTvcCR/QYw7
# lCXxi+UIuCcouQsHFaVA/ENflzh4XkYwgeIGCyqGSIb3DQEJEAIMMYHSMIHPMIHM
# MIGxBBRz2ocx/S77PGis5+hGlHNEh7+WTTCBmDCBgKR+MHwxCzAJBgNVBAYTAlVT
# MRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQK
# ExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1l
# LVN0YW1wIFBDQSAyMDEwAhMzAAAAzDq9O3I4EQW6AAAAAADMMBYEFCYRBNChL2UZ
# H/FfV67PlMTAUZmsMA0GCSqGSIb3DQEBCwUABIIBADj95Jih/cULIaT092Zv6j8J
# 9rA4tC0e01nTiUFPPwxS/3ZoX3qwACZeH8Bukkgjc54eIQ29SyortAhJ5735KMhp
# H9XUJLzUTBZ+outaPAnOmtQmn0stisW3/3EGFdBhJ0FubQNhcUfdvZM/c+rYykb7
# 8zpcDAbOJxfTRSoOS9jqV+Voy7wRdcnXUAkHMJDP873P6TxaLcrMs2wIbHMegwpj
# 44P6ScYOn4Zm2DbwNY8RWoyWdmpGwlGW9A3ZSCpqVceMa64gKTPjRAXNxyjmHYT0
# yu8mktXp6Wdh6sK5dQjg3izJ+719QpiaI5eqS3qSv/A5L2QyT46e7Q2aGsSsWNI=
# SIG # End signature block
