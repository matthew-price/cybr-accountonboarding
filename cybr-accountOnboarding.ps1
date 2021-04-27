## Script to onboard domain accounts onto CYBR Privilege Cloud
## This script is community supported only / not officially supported
## Uses officially supported REST APIs

##########UPDATE ITEMS HERE##########
$global:pvwaAddress = "https://subdomain.privilegecloud.cyberark.com/" # URL for Privilege Cloud Web Portal
$global:accountAddress = "domain" # Address for the account to be onboarded - usually the netBIOS part of the domain (e.g. for DOMAIN\username you would usually enter username)
$global:accountPlatform = "WinDomain" # PlatformID to use for the account
$global:domainName="domain.local" # Domain to search, as entered in Web Portal
$global:managingCpm="" # CPM username for password rotation
$global:managingGroup="ADgroup" # Group with rights to update passwords
######################################


# Variable declaration
$global:pvwaToken = ""


$global:pvwaToken = function Connect-RestAPI{
    $tinaCreds = Get-Credential -Message "Please enter your Privilege Cloud admin credentials"
    $url = $global:pvwaAddress + "PasswordVault/API/auth/Cyberark/Logon"
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tinaCreds.Password)

    $headerPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $body  = @{
    username =$tinacreds.UserName
    password =$headerPass
    }
    $json= $body | ConvertTo-Json
    $global:pvwaToken = Invoke-RestMethod -Method 'Post' -Uri $url -Body $json -ContentType 'application/json'
    #Write-Host $result
    #return $result
}

function Get-AccountToOnboardDetails{
    $global:AccountToOnboardCredentials = Get-Credential -Message "Please enter the credentials for the account to be onboarded"
    $global:AccountToOnboardUsername = $global:AccountToOnboardCredentials.UserName
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($global:AccountToOnboardCredentials.Password)
    $global:AccountToOnboardPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 
    $global:AccountToOnboardUsernameFixed = $global:AccountToOnboardUsername -Replace "\.","-"
}

function New-CybrSafe{
    $global:SafeName = "IND-"+$global:AccountToOnboardUsernameFixed
    $body  = @{
        "safe" = @{
            "SafeName"="$global:SafeName"
            "ManagingCPM"="$global:managingCpm"    
        }
    }
    $url = $global:pvwaAddress + "PasswordVault/WebServices/PIMServices.svc/Safes"
    $json= $body | ConvertTo-Json -Depth 4
    Write-Host $json
    Invoke-RestMethod -Method 'Post' -Uri $url -Body $json -Headers @{ 'Authorization' = $global:pvwaToken } -ContentType 'application/json'
}

function New-CybrAccount{
    $body  = @{
        name ="$global:AccountToOnboardUsername"
        address ="$global:accountAddress"
        userName ="$global:AccountToOnboardUsername"
        safeName ="$global:SafeName"
        secretType ="password"
        secret ="$global:AccountToOnboardPassword"
        platformID ="$global:accountPlatform"
    }
    $url = $global:pvwaAddress + "PasswordVault/api/Accounts"
    $json= $body | ConvertTo-Json
    Invoke-RestMethod -Method 'Post' -Uri $url -Body $json -Headers @{ 'Authorization' = $global:pvwaToken } -ContentType 'application/json'
    
}

function Set-CybrSafePermissions{
    $body  = @{
        "member" = @{
            "MemberName"="$global:AccountToOnboardUsername"
            "SearchIn"="$global:domainName"
            "Permissions" = @{
                "UseAccounts" = "true"
            }
        }
    }

    $url = $global:pvwaAddress + "/PasswordVault/WebServices/PIMServices.svc/Safes/$global:SafeName/Members"
    $json= $body | ConvertTo-Json -Depth 5
    Write-Host $json
    Invoke-RestMethod -Method 'Post' -Uri $url -Body $json -Headers @{ 'Authorization' = $global:pvwaToken } -ContentType 'application/json'
}

function Set-ManagingAccountPermissions{
    $body  = @{
        "member" = @{
            "MemberName"="$global:managingGroup"
            "SearchIn"="$global:domainName"
            "Permissions" = @{
                "UpdateAccountContent" = "true"
                "DeleteAccounts" = "true"
            }
        }
    }

    $url = $global:pvwaAddress + "/PasswordVault/WebServices/PIMServices.svc/Safes/$global:SafeName/Members"
    $json= $body | ConvertTo-Json -Depth 5
    Write-Host $json
    Invoke-RestMethod -Method 'Post' -Uri $url -Body $json -Headers @{ 'Authorization' = $global:pvwaToken } -ContentType 'application/json'
}

function Disconnect-RestApi{
    $url = $global:pvwaAddress + "/PasswordVault/API/Auth/Logoff"
    $body = @{}
    $json= $body | ConvertTo-Json
    Invoke-RestMethod -Method 'Post' -Uri $url -Body $json -Headers @{ 'Authorization' = $global:pvwaToken } -ContentType 'application/json'

}

function Remove-Variables{
    $global:AccountToOnboardPassword = ""
    $global:AccountToOnboardUsername = ""
}

function Set-Tls1point2{
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

Set-Tls1point2
Connect-RestApi
Get-AccountToOnboardDetails
New-CybrSafe
New-CybrAccount
Set-CybrSafePermissions
Set-ManagingAccountPermissions
Disconnect-RestApi
Remove-Variables