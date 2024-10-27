<#
.SYNOPSIS
    Compares Active Directory group memberships between two users.

.DESCRIPTION
    The Compare-ADGroupAccess function compares the group memberships of two Active Directory users and returns the differences or common groups between them. 
    It can operate in two modes: 'diff' to find differences and 'common' to find common groups.

.PARAMETER user1
    The second user to compare. This can be an ADUser object or a string representing the user's SamAccountName, DistinguishedName, &.

.PARAMETER user1Server
    The domain controller to query for the first user. This parameter is optional.

.PARAMETER user1SearchField
    The field to search for the first user. Default is 'SamAccountName'. This parameter is optional.

.PARAMETER user2
    The second user to compare. This can be an ADUser object or a string representing the user's SamAccountName, DistinguishedName, &.

.PARAMETER user2Server
    The domain controller to query for the second user. This parameter is optional.

.PARAMETER user2SearchField
    The field to search for the second user. Default is 'SamAccountName'. This parameter is optional.

.PARAMETER type
    The type of comparison to perform. Valid values are 'diff' for differences and 'common' for common groups. Default is 'diff'. This parameter is optional.

.OUTPUTS
    PSCustomObject
        Returns a custom object with the group names and domains for the specified comparison type.
        "diff" mode returns the group and group domain for each user.
        "common" mode returns the common group and group domain.

.EXAMPLE
    Compare-ADGroupAccess -user1 'sjohansson' -user2 'gribisi'
    Validates the AD User objects for 'sjohansson' and 'gribisi' and, if successful, returns the differences in group memberships.

.EXAMPLE
    Compare-ADGroupAccess -user1 'sjohansson' -user2 'bmurray' -type 'common'
    Validates the AD User objects for 'sjohansson' and 'bmurray' and, if successful, returns the commonalities in group memberships.

.EXAMPLE
    Compare-ADGroupAccess -user1 'nsteiner' -user1Server 'us.contoso.com' -user2 'bmurray' -user2Server 'jp.contoso.com'
    Compares the group memberships of users 'nsteiner' and 'bmurray' from different domain controllers and returns the differences.
.EXAMPLE
    Compare-ADGroupAccess -user1 "CN=Bill Murray,OU=Users,DC=us,DC=example,DC=com" -user1SearchField 'DistinguishedName' -user2 'sjohansson'
    CValidates the AD User objects corresponding to a DistinguishedName of "CN=Bill Murray,OU=Users,DC=us,DC=example,DC=com", 
    and a SAMAccountName of "sjohansson" and, if successful, returns the differences in group memberships.

.NOTES
    This function requires the ActiveDirectory module.
#>
function Get-GroupDomain{
    param(
        [string]$groupDN
    )
    $groupDNComponents = [regex]::Split($groupDN, '(?<!\\),')
    return ($groupDNComponents | Where-Object {$_ -match "^DC="}).Replace("DC=", "") -join "."
}
function Get-GroupName{
    param(
        [string]$groupDN
    )

    $groupDNComponents = [regex]::Split($groupDN, '(?<!\\),')
    return ($groupDNComponents | Where-Object {$_ -match '^CN=' -and
        $_ -notmatch '^CN=Builtin'}).Replace("CN=", "") -replace '\\([#,+="<>;\\])', '$1'
}

function Compare-ADGroupAccess {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [object]$user1,

        [Parameter(Mandatory=$false)]
        [String]$user1Server,

        [Parameter(Mandatory=$false)]
        [String]$user1SearchField = 'SamAccountName',

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [object]$user2,

        [Parameter(Mandatory=$false)]
        [String]$user2Server,

        [Parameter(Mandatory=$false)]
        [String]$user2SearchField = 'SamAccountName',

        [Parameter(Mandatory=$false)]
        [ValidateSet('diff', 'common')]
        [String]$type = 'diff'
    )
    $output = @()

    if($null -eq $user1 -or $null -eq $user2) {
        Write-Host "Error: Both users must be specified."
        return
    }
    
    if($user1 -eq $user2) {
        Write-Host "Error: The two users must be different."
        return
    }
    
    if($user1 -isnot [Microsoft.ActiveDirectory.Management.ADUser]) {
        try {
            if($user1Server -ne '') {
                $user1 = Get-ADUser -Server $user1Server -Filter "$user1SearchField -eq '$user1'"
                } 
            else {
                $user1 = Get-ADUser -Filter "$user1SearchField -eq '$user1'"
                }
        }
        catch {
            Write-Host "Error: user1 not found."
            return
        }
    }
    
    if($user2 -isnot [Microsoft.ActiveDirectory.Management.ADUser]) {
        try {
            if($user2Server -ne '') {
                $user2 = Get-ADUser -Server $user2Server -Filter "$user2SearchField -eq '$user2'"
                } 
            else {
                $user2 = Get-ADUser -Filter "$user2SearchField -eq '$user2'"
                }
        }
        catch {
            Write-Host "Error: user2 not found."
            return
        }
    }
    if($user1.Count -gt 1){
        Write-Host "Error: Multiple users found for user1."
        return
    }
    if($user2.Count -gt 1){
        Write-Host "Error: Multiple users found for user2."
        return
    }
    
    $user1Groups = Get-ADUser $user1 -Properties MemberOf | Select-Object -ExpandProperty MemberOf
    $user2Groups = Get-ADUser $user2 -Properties MemberOf | Select-Object -ExpandProperty MemberOf
    
    if($type -eq 'diff') {
        $user1UniqueGroups = Compare-Object -ReferenceObject $user1Groups -DifferenceObject $user2Groups -PassThru -IncludeEqual:$false | 
            Where-Object { $_.SideIndicator -eq '<=' }
        
        $user2UniqueGroups = Compare-Object -ReferenceObject $user2Groups -DifferenceObject $user1Groups -PassThru -IncludeEqual:$false | 
        Where-Object { $_.SideIndicator -eq '<=' }

        $user1UniqueGroupCount = $user1UniqueGroups.Count
        $user2UniqueGroupCount = $user2UniqueGroups.Count

        $count = (@($user1UniqueGroupCount, $user2UniqueGroupCount) | Measure-Object -Maximum).Maximum

        For($i=0; $i -lt $count; $i++){
            if(($i -ge $user1UniqueGroupCount) -and ($i -le $user2UniqueGroupCount)){
                $output += ([PSCustomObject]@{
                    "User1Group" = ""
                    "User1GroupDomain" = ""
                    "User2Group" = Get-GroupName -groupDN $user2UniqueGroups[$i]
                    "User2GroupDomain" = Get-GroupDomain -groupDN $user2UniqueGroups[$i]
                })
            }
            elseif(($i -ge $user2UniqueGroupCount) -and ($i -le $user2UniqueGroupCount)){
                $output += ([PSCustomObject]@{
                    "User1Group" = Get-GroupName -groupDN $user1UniqueGroups[$i]
                    "User1GroupDomain" = Get-GroupDomain -groupDN $user1UniqueGroups[$i]
                    "User2Group" = ""
                    "User2GroupDomain" = ""
                })
            }
            else{
                $output += ([PSCustomObject]@{
                    "User1Group" = Get-GroupName -groupDN $user1UniqueGroups[$i]
                    "User1GroupDomain" = Get-GroupDomain -groupDN $user1UniqueGroups[$i]
                    "User2Group" = Get-GroupName -groupDN $user2UniqueGroups[$i]
                    "User2GroupDomain" = Get-GroupDomain -groupDN $user2UniqueGroups[$i]
                })
            }
        }
    }
    elseif ($type -eq 'common') {
        $commonGroups = Compare-Object -ReferenceObject $user1Groups -DifferenceObject $user2Groups -PassThru -IncludeEqual:$true |
            Where-Object { $_.SideIndicator -eq '==' }
        foreach($commonGroup in $commonGroups){
            $output += ([PSCustomObject]@{
                "CommonGroup" = Get-GroupName -groupDN $commonGroup
                "CommonGroupDomain" = Get-GroupDomain -groupDN $commonGroup
            })
        }
    }
    return $output
}