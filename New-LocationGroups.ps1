<#
.SYNOPSIS
	Create a structure of Administrative Units in Azure AD from CSV-files incl. permission groups and assignments.
	
.DESCRIPTION
	Specs:
    - Erzeugung (neue) Groups
    CSV Location: LocationCode,ReportGroupforMFA,onPremisesDistinguishedName,AUUserDNAnon,AUUserDNExt
    
.EXAMPLE
	C:\PS> New-LocationGroups -Locations C:\Locations.csv
	
.NOTES
	Author  : Christopher Brumm
	For 	: KB
	Date    : 16-02-2023
	Version	: 0.1
#>

param(
    [Parameter(Mandatory = $true)]
    [string] $Locations,
    
    [Parameter(Mandatory = $true)]
    [string] $GroupOwnerUPN
)


# Check AAD-Connect-Status
try {
    $status = Get-AzureADTenantDetail    
}
catch {
    Write-Host -f Red "Seems like you don't have an active connection to AAD. Please run the Connect-AzureAD cmdlet"
}

Write-Host
Write-Host -f Green "Start location group deployment script"
Write-Host

# Import
try {
    $litentries = import-csv $Locations -delimiter ','
    Write-Host -f Gray "Locations from $Locations imported"    
}
catch {
    Write-Host -f Red "Import of Locations has been failed"
}

ForEach ($litentry in $litentries){
    $LocationCode = $($litentry.LocationCode)
    $ReportGroupforMFA = $($litentry.ReportGroupforMFA)
    $ReportGroupforMFAMail = $($ReportGroupforMFA -replace " ","-")
    $AUUserDN = $($litentry.onPremisesDistinguishedName)
	$AUUserDNAnon = $($litentry.onPremisesDistinguishedNameAnon)
	$AUUserDNExt = $($litentry.onPremisesDistinguishedNameExt)

    Write-Host
    Write-Host -f Green "Processing LIT $LocationCode"
    # Create Group
    try {
        $LITUserRule = '(user.onPremisesDistinguishedName -contains "' + $AUUserDN + '") or (user.onPremisesDistinguishedName -contains "' + $AUUserDNAnon + '") or (user.onPremisesDistinguishedName -contains "' + $AUUserDNExt + '")'
        $LITUsers = New-AzureADMSGroup -DisplayName $ReportGroupforMFA -Description "This group includes all internal, external and anonymous user from $LocationCode " -MailEnabled $false -SecurityEnabled $true -MailNickName $ReportGroupforMFAMail -GroupTypes "DynamicMembership" -MembershipRuleProcessingState "On" -MembershipRule $LitUserRule
        $Owner = Get-AzureADUser -SearchString $GroupOwnerUPN
        Add-AzureADGroupOwner -ObjectId $LITUsers.Id -RefObjectId $Owner.ObjectId
        Write-Host -f Gray "Group $ReportGroupforMFA created"
    }
    catch {
        Write-Host -f Red "Creation of Group $ResponsibleAdmins has been failed"
		Write-Warning $error[0]
        exit
    }
}

Write-Host
Write-Host -f Green "Finished"
Write-Host
