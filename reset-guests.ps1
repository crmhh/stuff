# You'll need a fresh version of the module
Uninstall-Module AzureADPreview
Install-Module AzureADPreview
Connect-AzureAD

$mydomain = "*example*"
$myguests = Get-AzureADUser -All 1| Where-Object {$_.Usertype -eq "Guest"} | Where-Object {$_.UserPrincipalName -like $mydomain}
foreach ($guest in $myguests) {
  $msGraphUser = New-Object Microsoft.Open.MSGraph.Model.User -ArgumentList $guest.ObjectId
  New-AzureADMSInvitation -InvitedUserEmailAddress $guest.mail -SendInvitationMessage $True -InviteRedirectUrl "http://myapps.microsoft.com" -InvitedUser $msGraphUser -ResetRedemption $True
}
