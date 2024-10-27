<#
.SYNOPSIS
Generates a report of user access to groups in Active Directory.

.DESCRIPTION
The Get-AccessReport function retrieves information about user memberships in Active Directory groups based on a specified property and value. It returns a sorted list of groups with the number of users having access and their respective SAM account names.

.PARAMETER property
The property of the user object to filter on (e.g., 'Name', 'EmailAddress').

.PARAMETER value
The value of the specified property to filter on.

.PARAMETER server
(Optional) The Active Directory server to query. If not specified, the default domain controller is used.

.EXAMPLE
Get-AccessReport -property "Department" -value "Admin"
Generates an access report for the set of users in the "Admin" department.
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

function Get-AccessReport{
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('prop')]
        [string]$property,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias('val')]
        [string]$value,

        [Parameter(Mandatory=$false)]
        [string]$server
    )
    begin{
        $groupsInfo = @()
    }
    process{
        if($server -eq ''){
            $users = Get-ADUser -Filter "$property -eq '$value'" -Properties MemberOf
        }
        elseif(Get-ADDomain -Server $server){
            $users = Get-ADUser -Server $server -Filter "$property -eq '$value'" -Properties MemberOf
        }
        else{
            Write-Host "Error: Unable to connect to the specified server."
            return
        }
        foreach($user in $users){
            foreach($userGroup in $user.MemberOf){
                if($userGroup -notin $groupsInfo.GroupDN){
                    $groupsInfo += ([PSCustomObject]@{
                        Group = Get-GroupName -groupDN $userGroup
                        GroupDN = $userGroup
                        GroupDomain = Get-GroupDomain -groupDN $userGroup
                        Members = $user.SamAccountName
                        AccessCount = 1
                    })
                }
                else{
                    $groupInfo = $groupsInfo | Where-Object {$_.GroupDN -eq $userGroup} 
                    $userSAMAccountName = $user.SamAccountName
                    $groupInfo.AccessCount++
                    $groupInfo.Members += ", $userSAMAccountName"
                }
            }
        }
    }
    end{
        return $groupsInfo | Sort-Object -Property @{Expression='AccessCount'; Descending=$true},
                                            @{Expression='Group'; Ascending=$true} 
    }
}