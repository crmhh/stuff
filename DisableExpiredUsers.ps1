<#
 
Author: Christopher Brumm
Version: 1.0
Version History: N/A
 
Purpose:  Get expired AD accounts that are not disabled and disable them
 
          .\DisableExpiredUsers –Verbose
 
#>

Param(
    [switch]$verbose,
    [switch]$dryrun = $false
)

if($verbose){
    $oldverbose = $VerbosePreference
    $VerbosePReference = "continue"
    }

# Import Active Directory module
Import-Module ActiveDirectory -Verbose:$false
 
#region: Define variables
#Get expired AD accounts that are not disabled
Write-Verbose 'Searching for accounts that are enabled but expired...' 
$ExpiredAccountsNotDisabled = Search-ADAccount -AccountExpired | Where-Object { $_.Enabled -eq $true }
Write-Verbose "Found $(@($ExpiredAccountsNotDisabled).count) users that meet criteria"

#Get current date
$Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Description = "$DAte - auto disabled expired user"
$Logfile = "c:\temp\log.txt"

#endregion

#region: init
"$Date : Starting Job. Found $(@($ExpiredAccountsNotDisabled).count) users that meet criteria" | out-file $Logfile -Append
if($dryrun) { "$Date : This is a dryrun!"| out-file $Logfile -Append }
#endregion

#Loop through Expired Users
ForEach($User in $ExpiredAccountsNotDisabled) {   
    try{
        # Write Description & Disable Account
        Write-Verbose "Setting Description of $User to: $Description"
        if(!$dryrun)
        {
            Set-ADUser -Identity $User.SamAccountName -Description $Description -Enabled $false
        }
            "$Date : $($User.UserPrincipalName) is disabled with Description: $Description" | out-file $Logfile -Append
    }
        catch{
        Write-Error "Something went wrong processing `'$($User.UserPrincipalName)`'"
    }
}

#region:finish
Write-Verbose "Finished Job."
"$Date : Finished Job." | out-file $Logfile -Append
$VerbosePreference = $oldverbose
#endregion
