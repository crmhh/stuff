﻿<#
.SYNOPSIS
Export Azure AD SignInActivity
.DESCRIPTION
Connect to App registrations and Export Azure AD SignInActivity
.NOTES
Create by Daniel Aldén
https://cloudtech.nu/2020/05/03/export-azure-ad-last-logon-with-powershell-graph-api/
Modified by Chris Brumm to filter on Groups
#>
 
# Application (client) ID, Directory (tenant) ID, and secret
$clientID = "xxx"
$tenantName = "xxx"
$ClientSecret = "xxx"
$groupID = "xxx"
$resource = "https://graph.microsoft.com/"
 
$ReqTokenBody = @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    client_Id     = $clientID
    Client_Secret = $clientSecret
} 
 
$TokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token" -Method POST -Body $ReqTokenBody
 
# Get all users in source tenant
$uri = 'https://graph.microsoft.com/beta/users?$select=displayName,userPrincipalName,signInActivity'

# If the result is more than 999, we need to read the @odata.nextLink to show more than one side of users
$Data = while (-not [string]::IsNullOrEmpty($uri)) {
    # API Call
    $apiCall = try {
        Invoke-RestMethod -Headers @{Authorization = "Bearer $($Tokenresponse.access_token)"} -Uri $uri -Method Get
    }
    catch {
        $errorMessage = $_.ErrorDetails.Message | ConvertFrom-Json
    }
    $uri = $null
    if ($apiCall) {
        # Check if any data is left
        $uri = $apiCall.'@odata.nextLink'
        $apiCall
    }
}

# Set the user result into an variable
$result = ($Data | select-object Value).Value
$Export = $result | select DisplayName,UserPrincipalName,@{n="LastLoginDate";e={$_.signInActivity.lastSignInDateTime}}


# Get all members of a group
$group = "https://graph.microsoft.com/v1.0/groups/" + $($groupID) + "/members"

$GroupData = while (-not [string]::IsNullOrEmpty($group)) {
    # API Call
    $apiCall = try {
        Invoke-RestMethod -Headers @{Authorization = "Bearer $($Tokenresponse.access_token)"} -Uri $group -Method Get
    }
    catch {
        $errorMessage = $_.ErrorDetails.Message | ConvertFrom-Json
    }
    $group = $null
    if ($apiCall) {
        # Check if any data is left
        $group = $apiCall.'@odata.nextLink'
        $apiCall
    }
}

 
# Set the group result into an variable
$groupresult = ($GroupData | select-object Value).Value
$groupExport = $groupresult | select DisplayName,UserPrincipalName


[datetime]::Parse('2020-04-07T16:55:35Z')

# Export data and pipe to Out-GridView for copy to Excel
$Export | Where-Object {$_.UserPrincipalName -in $groupExport.userPrincipalName} | sort -Property { $_.LastLoginDate -as [datetime] } -Descending | Out-GridView
