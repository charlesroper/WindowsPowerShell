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
# This PS DSC resource enables register or unregister a package source through DSC Get, Set and Test operations on DSC managed nodes.

Import-LocalizedData -BindingVariable LocalizedData -filename MSFT_PackageManagementSource.strings.psd1

Import-Module -Name "$PSScriptRoot\..\PackageManagementDscUtilities.psm1"

function Get-TargetResource
{
    <#
    .SYNOPSIS

    This DSC resource provides a mechanism to register/unregister a package source on your computer. 

    Get-TargetResource returns the current state of the resource.

    .PARAMETER Name
    Specifies the name of the package source to be registered or unregistered on your system.

    .PARAMETER ProviderName
    Specifies the name of the PackageManagement provider through which you can interop with the package source.

    .PARAMETER SourceLocation
    Specifies the Uri of the package source.
    #>

    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $ProviderName,

        [parameter(Mandatory = $true)]
        [System.String]
        $SourceLocation
    )

    #initialize a local var
    $ensure = "Absent"

    #Set the installation policy by default, untrusted. 
    $installationPolicy ="Untrusted"

    $PSBoundParameters.Add("Location", $SourceLocation)
    $PSBoundParameters.Remove("SourceLocation")

    #Validate Uri and add Location because PackageManagement uses Location not SourceLocation. 
    #ValidateArgument  -Argument $PSBoundParameters['Location'] -Type 'PackageSource' -ProviderName $ProviderName

    Write-Verbose -Message ($localizedData.StartGetPackageSource -f $($Name))

    #check if the package source already registered on the computer
    # Note: Assume Get-PackageSource returns the first source if multiple are found
    $source = PackageManagement\Get-PackageSource @PSBoundParameters -ForceBootstrap -ErrorAction SilentlyContinue -WarningAction SilentlyContinue  
        

    if (($source.count -gt 0) -and ($source.IsRegistered))
    {
        Write-Verbose -Message ($localizedData.PackageSourceFound -f $($Name))
        $ensure = "Present"
    }
    else
    {
        Write-Verbose -Message ($localizedData.PackageSourceNotFound -f $($Name))
    }

    Write-Debug -Message "Source $($Name) is $($ensure)"
                         
    
    if ($ensure -eq 'Absent')
    {
        return @{
            Ensure       = $ensure
            Name         = $Name
            ProviderName = $ProviderName
        }
    }
    else
    {
        if ($source.IsTrusted)
        {
            $installationPolicy = "Trusted"
        }

        return @{
            Ensure             = $ensure
            Name               = $Name
            ProviderName       = $ProviderName
            SourceLocation          = $source.Location
            InstallationPolicy = $installationPolicy
        }
    } 
}

function Test-TargetResource
{
    <#
    .SYNOPSIS

    This DSC resource provides a mechanism to register/unregister a package source on your computer. 

    Test-TargetResource validates whether the resource is currently in the desired state.

    .PARAMETER Name
    Specifies the name of the package source to be registered or unregistered on your system.

    .PARAMETER ProviderName
    Specifies the name of the PackageManagement provider through which you can interop with the package source.

    .PARAMETER SourceLocation
    Specifies the Uri of the package source.

    .PARAMETER Ensure
    Determines whether the package source to be registered or unregistered.

    .PARAMETER SourceCredential
    Provides access to the package on a remote source. 

    .PARAMETER InstallationPolicy
    Determines whether you trust the package’s source.
    #>

    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $ProviderName,

        [parameter(Mandatory = $true)]
        [System.String]
        $SourceLocation,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure="Present",

        [System.Management.Automation.PSCredential]
        $SourceCredential,

        [ValidateSet("Trusted","Untrusted")]
        [System.String]
        $InstallationPolicy="Untrusted"
    )

    #Get the current status of the package source 
    Write-Debug -Message  "Calling Get-TargetResource"

    $status = Get-TargetResource -Name $Name -ProviderName $ProviderName -SourceLocation $SourceLocation
 
    if($status.Ensure -eq $Ensure)
    {
        
        if ($status.Ensure -eq "Present") 
        {
            #Check if the source location matches. As get-package takes location (SourceLocation) parameter, the result from Get-package should 
            #belong to the particular source location. But currently it does not. Below is the workaround.
            #
            if ($status.SourceLocation -ine $SourceLocation) 
            {
                Write-Verbose -Message ($localizedData.NotInDesiredStateDuetoLocationMismatch -f $($Name), $($SourceLocation), $($status.SourceLocation))
                return $false 
            }  

            #Check if the installationPolicy matches. Sometimes the registered source and desired source can be the same except for InstallationPolicy
            #
            if ($status.InstallationPolicy -ine $InstallationPolicy)
            {
                Write-Verbose -Message ($localizedData.NotInDesiredStateDuetoPolicyMismatch -f $($Name), $($InstallationPolicy), $($status.InstallationPolicy))
                return $false 
            }           
        }

        Write-Verbose -Message ($localizedData.InDesiredState -f $($Name), $($Ensure), $($status.Ensure))                   
        return $true
    }
    else
    {
        Write-Verbose -Message ($localizedData.NotInDesiredState -f $($Name), $($Ensure), $($status.Ensure))
        return $false
    }
}

function Set-TargetResource
{
    <#
    .SYNOPSIS

    This DSC resource provides a mechanism to register/unregister a package source on your computer. 

    Set-TargetResource sets the resource to the desired state. "Make it so".

    .PARAMETER Name
    Specifies the name of the package source to be registered or unregistered on your system.

    .PARAMETER ProviderName
    Specifies the name of the PackageManagement provider through which you can interop with the package source.

    .PARAMETER SourceLocation
    Specifies the Uri of the package source.

    .PARAMETER Ensure
    Determines whether the package source to be registered or unregistered.

    .PARAMETER SourceCredential
    Provides access to the package on a remote source. 

    .PARAMETER InstallationPolicy
    Determines whether you trust the package’s source.
    #>

    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $Name,

        [parameter(Mandatory = $true)]
        [System.String]
        $ProviderName,

        [parameter(Mandatory = $true)]
        [System.String]
        $SourceLocation,

        [ValidateSet("Present","Absent")]
        [System.String]
        $Ensure="Present",

        [System.Management.Automation.PSCredential]
        $SourceCredential,

        [ValidateSet("Trusted","Untrusted")]
        [System.String]
        $InstallationPolicy="Untrusted"
    )

    #Add Location because PackageManagement uses Location not SourceLocation. 
    $PSBoundParameters.Add("Location", $SourceLocation)

    if ($PSBoundParameters.ContainsKey("SourceCredential"))
    {
        $PSBoundParameters.Add("Credential", $SourceCredential)
    }

    if ($InstallationPolicy -ieq "Trusted")
    {
        $PSBoundParameters.Add("Trusted", $True)
    }
    else
    {
        $PSBoundParameters.Add("Trusted", $False)
    }
    

    if($Ensure -ieq "Present")
    {   
        #
        #Warn a user about the installation policy
        #
        Write-Warning -Message ($localizedData.InstallationPolicyWarning -f $($Name), $($SourceLocation), $($InstallationPolicy))

        $extractedArguments = ExtractArguments -FunctionBoundParameters $PSBoundParameters `
                                               -ArgumentNames ("Name","ProviderName", "Location", "Credential", "Trusted")   
        
        Write-Verbose -Message ($localizedData.StartRegisterPackageSource -f $($Name)) 

        if ($name -eq "psgallery")
        {         
            # In WMF 5.0 RTM, we are not able to register 'psgallery' package source. Thus let's try Set-PSRepository to see if we can
            # update the registration. 
            
            # Before calling the Set-PSRepository cmdlet, we need to make sure the PSGallery already registered.

            $psgallery = PackageManagement\Get-PackageSource -name $name -Location $SourceLocation -ProviderName $ProviderName -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

            if( $psgallery)
            {
                Set-PSRepository -Name $name -SourceLocation $SourceLocation -InstallationPolicy $InstallationPolicy -ErrorVariable ev 
            }
            else
            {
                # The following works if you are running TP5 or later
                $extractedArguments.Remove("Location")
                PackageManagement\Register-PackageSource @extractedArguments -Force -ErrorVariable ev  

            }
        }
        else
        {                                       
            PackageManagement\Register-PackageSource @extractedArguments -Force -ErrorVariable ev  
        }
            
        if($null -ne $ev -and $ev.Count -gt 0)
        {
            ThrowError  -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage ($localizedData.RegisterFailed -f $Name, $ev.Exception)`
                        -ErrorId "RegisterFailed" `
                        -ErrorCategory InvalidOperation                  
        }
        else
        {
            Write-Verbose -Message ($localizedData.RegisteredSuccess -f $($Name))           
        }                      
    }
    #Ensure=Absent
    else 
    {
        $extractedArguments = ExtractArguments -FunctionBoundParameters $PSBoundParameters `
                                               -ArgumentNames $("Name","ProviderName", "Location", "Credential")  
                                                       
        Write-Verbose -Message ($localizedData.StartUnRegisterPackageSource -f $($Name))  
                         
        PackageManagement\Unregister-PackageSource @extractedArguments -Force -ErrorVariable ev 
        
        if($null -ne $ev -and $ev.Count -gt 0)
        {
            ThrowError  -ExceptionName "System.InvalidOperationException" `
                        -ExceptionMessage ($localizedData.UnRegisterFailed -f $Name, $ev.Exception)`
                        -ErrorId "UnRegisterFailed" `
                        -ErrorCategory InvalidOperation       
        }
        else
        {
            Write-Verbose -Message ($localizedData.UnRegisteredSuccess -f $($Name))            
        }                    
    }  
 }

Export-ModuleMember -function Get-TargetResource, Set-TargetResource, Test-TargetResource


# SIG # Begin signature block
# MIIjgwYJKoZIhvcNAQcCoIIjdDCCI3ACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCi6Bt6dCivNyvz
# gw+R+LTaFT5ZDIx8HkDejTMrDqW9yqCCDYEwggX/MIID56ADAgECAhMzAAABUZ6N
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
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIVWDCCFVQCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAVGejY9AcaMOQQAAAAABUTAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgg3k6xwNQ
# o1WoPx/Eum0hOMf6jJDw+B0lq5IkCZ9L86UwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBS/TiZt1ZkgTZiCIRN/Kr8OQTzV3jWOSFKdIudqb9f
# Mc/tYge0qsJX1m2MTzoPRwGJ2i6UjY1AI1l7bk2PllyNXIHQbTihT+gSD/F3qvxB
# 0fBIRonJPZYjBx0OQ4/44dq7JZbpSdpiS8SA6J5UuMBg23/ztzdXFwR5o/Xg9dnf
# RstQbjwG164SU+Zj2EjOPeJVEJm6sCN4iQHgVjRhnA0AZeQrPZ1U3P7A/2vds+fQ
# BE8ihgP4j8vHTMB3onAardcO9eadD7AZysfYUZ4LiZJH4T1jPXP0kIBxDL8SLAZP
# 7xd04eUsL7pPZLA+LswZ3cmSpt1rro4+SAtgHFtqJYd9oYIS4jCCEt4GCisGAQQB
# gjcDAwExghLOMIISygYJKoZIhvcNAQcCoIISuzCCErcCAQMxDzANBglghkgBZQME
# AgEFADCCAVEGCyqGSIb3DQEJEAEEoIIBQASCATwwggE4AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIEs0YKhHEnRE4xuC8BF1IKf3ikAfklMmBaIfjvRV
# +biAAgZdjpRPxtoYEzIwMTkxMDA3MjA0NTE0LjE2OVowBIACAfSggdCkgc0wgcox
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOkFFMkMtRTMyQi0xQUZDMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloIIOOTCCBPEwggPZoAMCAQICEzMAAADt529yvU9VuNIAAAAAAO0w
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MTgxMDI0MjExNDE0WhcNMjAwMTEwMjExNDE0WjCByjELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046QUUyQy1FMzJCLTFB
# RkMxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQD2xEpZbZ/UmTLviEOzqh4fCWcfstmT
# ccMK+HERQ0pAAYg3eCNWTbSZjtj/Tq8EbauxRnb0uU2oUaTs6NhBwJ0GJKGGJf2S
# cQPfX2M3j1ThxUj5bOcUsG0r2E7yOhLCF7IdWlEvjOR9uVJSCQ+E3IFmEOnu+rgA
# NcH/WcyZcmNjhyYZSYLzgie3gMTRpDfH/pxWOCM0ACbDZBtsvee25jtyFJrsrzGo
# 6qJ5DEhC+ZXBZEPIp1CgDazpuroTYIXR1jMyOa4U1LCIB3xN49tcj2JhlhjoQdcP
# YF4B4YV+AMOR33JSthLMiy610yUGfKtkQnEiLu/cBLw4JC68z/BuS7rbAgMBAAGj
# ggEbMIIBFzAdBgNVHQ4EFgQUwvQ7ncfS51XhCPESnwjeP55VfuswHwYDVR0jBBgw
# FoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDov
# L2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljVGltU3RhUENB
# XzIwMTAtMDctMDEuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0
# cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNUaW1TdGFQQ0FfMjAx
# MC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDCDAN
# BgkqhkiG9w0BAQsFAAOCAQEAX5A86yzc9H5ybz61438E1yrEF6AE2t1NM/EpUqnb
# c9r9pCcLelXSWIc0vWcTkW2LotLRckwO+ehgDZM8lSxA294M+Wuqi/qLwU6uZ3Vl
# U/VnngkOr8rS0xKivW0AZ0M58jqI8rlxDZpNB/V2jApEBjd+wXALSuo/oFXant/q
# l2Msa2L+1hcvSik1ei6/L/K2ZiKR3PSYOnHdTx6Wh+Hsk3ewaw/x+vfma8O+cedz
# GkjlHgufyDULsd2bLtPL6+NVZjnhPNnsSbnu7cf7MqWxc9Mm7d+M4sSBSTuTExQo
# sGwx6PC4T/YZrXFAi4U+9SVr1VT3OfM792+gRW51eL1vrDCCBnEwggRZoAMCAQIC
# CmEJgSoAAAAAAAIwDQYJKoZIhvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xMjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRp
# ZmljYXRlIEF1dGhvcml0eSAyMDEwMB4XDTEwMDcwMTIxMzY1NVoXDTI1MDcwMTIx
# NDY1NVowfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQG
# A1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQCpHQ28dxGKOiDs/BOX9fp/aZRrdFQQ1aUKAIKF
# ++18aEssX8XD5WHCdrc+Zitb8BVTJwQxH0EbGpUdzgkTjnxhMFmxMEQP8WCIhFRD
# DNdNuDgIs0Ldk6zWczBXJoKjRQ3Q6vVHgc2/JGAyWGBG8lhHhjKEHnRhZ5FfgVSx
# z5NMksHEpl3RYRNuKMYa+YaAu99h/EbBJx0kZxJyGiGKr0tkiVBisV39dx898Fd1
# rL2KQk1AUdEPnAY+Z3/1ZsADlkR+79BL/W7lmsqxqPJ6Kgox8NpOBpG2iAg16Hgc
# sOmZzTznL0S6p/TcZL2kAcEgCZN4zfy8wMlEXV4WnAEFTyJNAgMBAAGjggHmMIIB
# 4jAQBgkrBgEEAYI3FQEEAwIBADAdBgNVHQ4EFgQU1WM6XIoxkPNDe3xGG8UzaFqF
# bVUwGQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1Ud
# EwEB/wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYD
# VR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwv
# cHJvZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEB
# BE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9j
# ZXJ0cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwgaAGA1UdIAEB/wSBlTCB
# kjCBjwYJKwYBBAGCNy4DMIGBMD0GCCsGAQUFBwIBFjFodHRwOi8vd3d3Lm1pY3Jv
# c29mdC5jb20vUEtJL2RvY3MvQ1BTL2RlZmF1bHQuaHRtMEAGCCsGAQUFBwICMDQe
# MiAdAEwAZQBnAGEAbABfAFAAbwBsAGkAYwB5AF8AUwB0AGEAdABlAG0AZQBuAHQA
# LiAdMA0GCSqGSIb3DQEBCwUAA4ICAQAH5ohRDeLG4Jg/gXEDPZ2joSFvs+umzPUx
# vs8F4qn++ldtGTCzwsVmyWrf9efweL3HqJ4l4/m87WtUVwgrUYJEEvu5U4zM9GAS
# inbMQEBBm9xcF/9c+V4XNZgkVkt070IQyK+/f8Z/8jd9Wj8c8pl5SpFSAK84Dxf1
# L3mBZdmptWvkx872ynoAb0swRCQiPM/tA6WWj1kpvLb9BOFwnzJKJ/1Vry/+tuWO
# M7tiX5rbV0Dp8c6ZZpCM/2pif93FSguRJuI57BlKcWOdeyFtw5yjojz6f32WapB4
# pm3S4Zz5Hfw42JT0xqUKloakvZ4argRCg7i1gJsiOCC1JeVk7Pf0v35jWSUPei45
# V3aicaoGig+JFrphpxHLmtgOR5qAxdDNp9DvfYPw4TtxCd9ddJgiCGHasFAeb73x
# 4QDf5zEHpJM692VHeOj4qEir995yfmFrb3epgcunCaw5u+zGy9iCtHLNHfS4hQEe
# gPsbiSpUObJb2sgNVZl6h3M7COaYLeqN4DMuEin1wC9UJyH3yKxO2ii4sanblrKn
# QqLJzxlBTeCG+SqaoxFmMNO7dDJL32N79ZmKLxvHIa9Zta7cRDyXUHHXodLFVeNp
# 3lfB0d4wwP3M5k37Db9dT+mdHhk4L7zPWAUu7w2gUDXa7wknHNWzfjUeCLraNtvT
# X4/edIhJEqGCAsswggI0AgEBMIH4oYHQpIHNMIHKMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBP
# cGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpBRTJDLUUzMkItMUFG
# QzElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcG
# BSsOAwIaAxUAZieJEGxNFfeZgtCAQELn8/XVOMKggYMwgYCkfjB8MQswCQYDVQQG
# EwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwG
# A1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQg
# VGltZS1TdGFtcCBQQ0EgMjAxMDANBgkqhkiG9w0BAQUFAAIFAOFFmOswIhgPMjAx
# OTEwMDcxODU4NTFaGA8yMDE5MTAwODE4NTg1MVowdDA6BgorBgEEAYRZCgQBMSww
# KjAKAgUA4UWY6wIBADAHAgEAAgIAvTAHAgEAAgIRnzAKAgUA4UbqawIBADA2Bgor
# BgEEAYRZCgQCMSgwJjAMBgorBgEEAYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAID
# AYagMA0GCSqGSIb3DQEBBQUAA4GBAHNkamtEwFmBseMdth3KERJXpREZ+555b3xs
# KK6lW+6LCXXOEVVUkWyO2sQTVdIme0ttQGpQaJmUzb/EqD2gPu7/B7ZwwSXSeDKC
# 8ExEkD6zXLp7zpU63lUyzpk+esq63VJzikoyUav9qOsE8lT8e/s9Lja637PGxbUr
# PfNs4jOcMYIDDTCCAwkCAQEwgZMwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldh
# c2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBD
# b3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIw
# MTACEzMAAADt529yvU9VuNIAAAAAAO0wDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAvBgkqhkiG9w0BCQQxIgQgnvT0NGmuc2ad
# Fqw/k6fFBnN5LNf5/LH0XuPaL+SI1GMwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHk
# MIG9BCDRwej5cp3T8ozdHM1yAhkysHb0A5sZXQyaJHdRnjCkvTCBmDCBgKR+MHwx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1p
# Y3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAA7edvcr1PVbjSAAAAAADt
# MCIEINgRZJb86bpI/v/zaRMaOFI7fBmgJZhASwBj5ar+l106MA0GCSqGSIb3DQEB
# CwUABIIBAI6SF7nhljR3H8PqjWLg9TVkh9B98wFzsRmmsQxyIJbrpCkk7DFC/Uy2
# B1QvpQsGbfN1pQV6l/C5EiQ4SRxs+LGY6VCMjgLDLgNLZGewx2hdsD5A+miVAYSb
# /mTzjLxBdfwUtaYe/tmHQHI2IE9Zv9fmpk4qsBtHm2WJwRIE5u+z6xAQVSByYv7P
# i1U9tu876XYgSJ1y+G27AyGK/4sQQGbX4GLhKq3zPZchXwfQzdZQi2gJU++6JFaP
# eRQ5sRO06wVBcA/xesWK03ESMMhnelcaD3p3NVWWZ4HdUaJ2jmohKfoLWScVAL5h
# s8xowvx1rWhYXPrEPBIOPIcFrN/deAY=
# SIG # End signature block
