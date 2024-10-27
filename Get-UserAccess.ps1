<#
.SYNOPSIS
    Retrieves user access information based on specified users and groups.

.DESCRIPTION
    The Get-UserAccess function takes a list of users and groups, resolves them to their Active Directory objects, 
    and checks if the users are members of the specified groups. It returns a list of users and their corresponding groups.

.PARAMETER users
    The users to be checked. This can be a string, an array of strings, or an ADUser object. 
    If a string is provided, it can be a username or a file path containing usernames.
    The expected format for the file is one username per line, no headers.

.PARAMETER userSearchField
    The field to search for the user in Active Directory. Default is 'SAMAccountName'.

.PARAMETER groups
    The groups to be checked. This can be a string, an array of strings, or an ADGroup object. 
    If a string is provided, it can be a group name or a file path containing group names.
    The expected format for the file is one group name per line, no headers.

.EXAMPLE
    Get-UserAccess -users "djones", "ruggles" -groups "Domain Admins"
    Retrieves the access information for user 'jdoe' in the 'Admins' group.

.EXAMPLE
    Get-UserAccess -users "C:\UsersList.txt" -groups "C:\GroupsList.txt"
    Retrieves the access information for users listed in 'UsersList.txt' and groups listed in 'GroupsList.txt'.

.NOTES
    This function requires the Active Directory module.
#>
function Get-UserAccess {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
        [Alias('User')]
        [object]$users,

        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [string]$userSearchField = 'SAMAccountName',

        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $true)]
        [Alias('Group')]
        [object]$groups
    )
    begin{
        $output = @()
    }
    process{
        function Resolve-ADUsers{
            param(
                [object]$user,
                [Parameter(Mandatory = $false)]
                [string]$userSearchField = 'SAMAccountName'
            )
            if($user -is [string]){
                if(Test-Path $user){
                    $fileContent = Get-Content -Path $user
                    return $fileContent | %{Resolve-ADUsers -user $_ -userSearchField $userSearchField}
                }
                else{
                    try {
                        return Get-ADUser -Filter "$userSearchField -eq '$user'"
                    }
                    catch {
                        Write-Host "Error: User '$user' not found."
                    }
                }
            }
            elseif($user -is [Microsoft.ActiveDirectory.Management.ADUser]){
                return $user
            }
        }
        function Resolve-ADGroups{
            param(
                [object]$group
            )
            if($group -is [string]){
                if(Test-Path $group){
                    $fileContent = Get-Content -Path $group
                    return $fileContent | %{Resolve-ADGroups -group $_}
                }
                else{
                    try {
                        return Get-ADGroup $group
                    }
                    catch {
                        Write-Host "Error: Group '$group' not found."
                    }
                }
            }
            elseif($group -is [Microsoft.ActiveDirectory.Management.ADGroup]){
                return $group
            }
        }
        $resolvedUsers = @()
        $resolvedGroups = @()

        if($users){
            foreach($user in $users){
                $resolvedUser = Resolve-ADUsers -user $user -userSearchField $userSearchField
                if($resolvedUser){
                    $resolvedUsers += $resolvedUser
                }
            }
        }
        if($groups){
            foreach($group in $groups){
                $resolvedGroup = Resolve-ADGroups -group $group
                if($resolvedGroup){
                    $resolvedGroups += $resolvedGroup
                }
            }
        }
        foreach($user in $resolvedUsers){
            $userGroups = Get-ADUser $user -Properties MemberOf | Select-Object -ExpandProperty MemberOf
            foreach($group in $resolvedGroups){
                if($userGroups -contains $group.distinguishedName){
                    $output += ([pscustomobject]@{
                        User = $user.SamAccountName
                        Group = $group.Name
                    })
                }
            }
        }
    }
    end{
        return $output
    }
}