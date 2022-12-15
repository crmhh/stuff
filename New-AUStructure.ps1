<#
.SYNOPSIS
	Create a structure of Administrative Units in Azure AD from CSV-files incl. permission groups and assignments.
	
.DESCRIPTION
	Specs:
    - Erzeugung (neue) AU User
    - Erzeugung (neue) AU Device 
    - Mapping OnPrem-DN
    - Neue Berechtigungs-Gruppe
    - Berechtigung auf AUs mit Auth-Admin und Bitlocker
    - Ermitteln des Admin Accounts
    - User in die Gruppen aufnehmen 

    CSV Location: LocationCode;ResponsibleAdmins;onPremisesDistinguishedName;AUNameUser;AUNameDevice
    CSV Admins: userPrincipalName;directoryScopeName
    
.EXAMPLE

	C:\PS> New-AUStructure -Admins C:\Admins.csv -Locations C:\Locations.csv
	
.NOTES
	Author  : Christopher Brumm
	For 	: KB
	Date    : 15-12-2022
	Version	: 0.1
#>

param(

    [Parameter(Mandatory = $true)]
    [string[]] $Admins, #"C:\Users\ChristopherBrumm\OneDrive - glueckkanja-gab\Dokumente\scripts\KB\litadmins2.csv"

    [Parameter(Mandatory = $true)]
    [string] $Locations #"C:\Users\ChristopherBrumm\OneDrive - glueckkanja-gab\Dokumente\scripts\KB\lits3.csv"
)


# Login as Global Administrator
#Connect-AzureAD

<# Variables - later XML
$LocationCode  = "ALD"
$AUNameUser = "EUR ALD Users"
$AUNAmeUserNickname = "EUR-ALD-Users"
$AUNameDevice = "EUR ALD Devices"
$AUUserDN = 'OU=ALD_Accounts_Users_internal,OU=EUR_Accounts_Users_internal,OU=internal,OU=Users,OU=Accounts,DC=corp,DC=knorr-bremse,DC=com'
$ResponsibleAdmins = "SG-ALD-ADM-Site Management-A-G"
$LITAdmin = "admin_cookie@gkfelucia.net"
#>
Write-Host
Write-Host -f Green "Start Administrative Units deployment script"
Write-Host

# Import
try {
    $litadmins = import-csv $Admins -delimiter ';'    
    Write-Host f Gray "Admins from $Admins imported"
}
catch {
    Write-Host -f Red "Import of Admins has been failed"
}

try {
    $litentries = import-csv $Locations -delimiter ';'
    Write-Host -f Gray "Admins from $Locations imported"    
}
catch {
    Write-Host -f Red "Import of Locations has been failed"
}

ForEach ($litentry in $litentries){
    $LocationCode = $($litentry.LocationCode)
    $ResponsibleAdmins = $($litentry.ResponsibleAdmins)
    $ResponsibleAdminsMail = $($ResponsibleAdmins -replace " ","-")
    $AUNameUser = $($litentry.AUNameUser)
    $AUNameDevice = $($litentry.AUNameDevice)
    $AUUserDN = $($litentry.onPremisesDistinguishedName)

    Write-Host
    Write-Host -f Green "Processing LIT $LocationCode"
    # Create Group
    try {
        $ResponsibleAdminsRes = New-AzureADMSGroup -DisplayName $ResponsibleAdmins -Description "This group grants permissions to the Administrative Units $AUNameUser and $AUNameDevice in $LocationCode " -MailEnabled $false -SecurityEnabled $true -IsAssignableToRole $true -MailNickName $ResponsibleAdminsMail
        Write-Host -f Gray "Group $ResponsibleAdmins created"
    }
    catch {
        Write-Host -f Red "Creation of Group $ResponsibleAdmins has been failed"
        exit
    }

    # Add Admins to group
    Write-Host
    Write-Host -f Green "Adding Members to $ResponsibleAdmins"
    ForEach ($litadmin in $litadmins) {
        $directoryScopeName = $($litadmin.directoryScopeName)
        if ($directoryScopeName -like "*$LocationCode*") {
            try {
                $LITAdminUPN = $($LitAdmin.userPrincipalName)
                Add-AzureADGroupmember -ObjectId $ResponsibleAdminsRes.Id -RefObjectId (Get-AzureADUser -ObjectId $LITAdminUPN).ObjectId
                Write-Host -f Gray "$LITAdminUPN is now member of Group $ResponsibleAdmins"
            }
            catch {
                Write-Host -f Red "Adding $LITAdminUPN as a member of Group $ResponsibleAdmins has been failed"
                exit
            }
        }
    }

    # Create AUs
    Write-Host
    Write-Host -f Green "Creating Administrative Units for $LocationCode"
    try {
        $AUUserRule = '(user.onPremisesDistinguishedName -contains "' + $AUUserDN + '")'
        $AUUser = New-AzureADMSAdministrativeUnit -DisplayName $AUNameUser -Description "Admin Unit for User in $LocationCode " -MembershipType "Dynamic" -MembershipRuleProcessingState "On" -MembershipRule $AUUserRule    
        Write-Host -f Gray "Administrative Unit $AUNameUser created"
    }
    catch {
        Write-Host -f Red "Creation of Administrative Unit $AUNameUser has been failed"
        exit
    }
    try {
        $AUDeviceRule = '(device.displayName -startsWith "' + $LocationCode + '") and (device.deviceOSType -contains "Windows") and (device.displayName -notStartsWith "' + $LocationCode + 'S")'
        $AUDevice = New-AzureADMSAdministrativeUnit -DisplayName $AUNameDevice -Description "Admin Unit for User in $LocationCode " -MembershipType "Dynamic" -MembershipRuleProcessingState "On" -MembershipRule $AUDeviceRule        
        Write-Host -f Gray "Administrative Unit $AUNameDevice created"
    }
    catch {
        Write-Host -f Red "Creation of Administrative Unit $AUNameDevice has been failed"
        exit
    }

    # Assign Role Authentication Admin
    Write-Host
    Write-Host -f Green "Assign Permissions"
    try {
        $AuthAdmin = Get-AzureADMSRoleDefinition -Filter "displayName eq 'Authentication Administrator'"
        $ScopeId = "/administrativeUnits/" + $AUUser.Id
        $aurole = New-AzureADMSRoleAssignment -RoleDefinitionId $AuthAdmin.Id -PrincipalId $ResponsibleAdminsRes.ID -DirectoryScopeId $ScopeId
        Write-Host -f Gray "Group $ResponsibleAdmins is now Authentication Administrator for the Administrative Unit $AUNameUser"
    }
    catch {
        Write-Host -f Red "Assignment of Authentication Administrator to Group $ResponsibleAdmins for the Administrative Unit $AUNameUser has been failed"
        exit
    }

    # Assign Role Bitlocker Admin
    try {
        $BitlAdmin = Get-AzureADMSRoleDefinition -Filter "displayName eq 'BitLocker Recovery Key Reader'"
        $ScopeId = "/administrativeUnits/" + $AUDevice.Id
        $aurole = New-AzureADMSRoleAssignment -RoleDefinitionId $BitlAdmin.Id -PrincipalId $ResponsibleAdminsRes.ID -DirectoryScopeId $ScopeId
        Write-Host -f Gray "Group $ResponsibleAdmins is now BitLocker Recovery Key Reader for the Administrative Unit $AUNameDevice"        
    }
    catch {
        Write-Host -f Red "Assignment of Bitlocker Administrator to Group $ResponsibleAdmins for the Administrative Unit $AUNameDevice has been failed"
        exit
    }
}

Write-Host
Write-Host -f Green "Finished"
Write-Host




<#
$roleDefinition = Get-AzureADMSRoleDefinition -Filter "displayName eq 'BitLocker Recovery Key Reader'"
New-MgDirectoryRoleScopedMember -DirectoryRoleId $roleDefinition.Id -AdministrativeUnitId $AUDevice.Id -RoleMemberInfo $RoleMember
New-AzureADMSRoleAssignment -RoleDefinitionId $BitlAdmin.Id -PrincipalId $ResponsibleAdminsRes.ID -DirectoryScopeId '/administrativeUnits/fe27892c-5b66-469b-8dce-71d3a034211f'
Get-AzureADMSRoleAssignment -Filter "roleDefinitionId eq '5c62e0b7-287b-4d0e-8e57-31a5e854ec0e'"
https://portal.azure.com/#view/Microsoft_Azure_PIMCommon/SubjectDetailsViewModel/item~/%7B%22resourceId%22%3A%220f642f1e-8030-465d-91cf-5252c6ca581b%22%2C%22roleAssignmentId%22%3A%22Bt-ExWXGwEONhSKI24XNmuNgBg2Ng9JEhWQyLFeH2mQsiSf-ZlubRo3OcdOgNCEf-2-e%22%2C%22subjectId%22%3A%220d0660e3-838d-44d2-8564-322c5787da64%22%2C%22subjectDisplayName%22%3A%22SG-AQA-ADM-Site%20Management-A-G%22%2C%22subjectPrincipalName%22%3Anull%2C%22scopedResourceName%22%3A%22AME%20AQA%20Devices%22%2C%22subjectType%22%3A%22Group%22%2C%22assignmentType%22%3A%22Direct%22%2C%22roleDefinitionId%22%3A%2268588618-5c3f-4d46-a13d-22e4ad6a34df%22%2C%22roleDefinitionDisplayName%22%3A%22BitLocker%20Recovery%20Key%20Reader%22%2C%22level%22%3A%22Eligible%22%2C%22scopedResourceId%22%3A%22fe27892c-5b66-469b-8dce-71d3a034211f%22%2C%22resourceName%22%3A%22%22%2C%22resourceType%22%3Anull%2C%22isPermanent%22%3Atrue%2C%22startDateTime%22%3A%222022-12-15T15%3A50%3A05.59Z%22%2C%22endDateTime%22%3Anull%2C%22functionType%22%3A%22AdminUpdate%22%2C%22groupdId%22%3Anull%2C%22condition%22%3A%22%22%2C%22conditionVersion%22%3A%22%22%7D
#>