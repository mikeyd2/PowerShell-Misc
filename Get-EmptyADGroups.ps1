<#
.SYNOPSIS
    Retrieves and logs all empty Active Directory groups.

.DESCRIPTION
    The Get-EmptyADGroups function scans all Active Directory groups and identifies those without any members.
    Groups are processed in batches to avoid a DC overload, & empties are logged. 
    to a specified CSV file.

.PARAMETER BatchSize
    Specifies the number of groups to process in each batch. Default is 100.

.PARAMETER LogFile
    Specifies the path to the CSV file where the details of empty groups will be logged. Default is ".\EmptyGroupsLog.csv".

.EXAMPLE
    Get-EmptyADGroups -BatchSize 50 -LogFile "C:\Logs\EmptyGroups.csv"
    This example processes the groups in batches of 50 and logs the empty groups to "C:\Logs\EmptyGroups.csv".
#>
function Get-EmptyADGroups {
    param (
        [int]$BatchSize = 100,
        [string]$LogFile = ".\EmptyGroupsLog.csv"
    )

    Clear-Content -Path $LogFile -ErrorAction SilentlyContinue
    $start = Get-Date
    Write-Host "Started looking for empty groups at $start`n"

    $allGroups = Get-ADGroup -Filter * -properties members, whencreated, whenchanged

    $totalGroups = $allGroups.Count
    $batchCount = [math]::Ceiling($totalGroups / $BatchSize)
    Write-Host "Processing $totalGroups groups in batches of $BatchSize"

    for ($i = 0; $i -lt $batchCount; $i++) {
        $startIndex = $i * $BatchSize
        $endIndex = [math]::Min($startIndex + $BatchSize, $totalGroups) - 1
        $batchGroups = $allGroups[$startIndex..$endIndex]

        foreach ($group in $batchGroups) {
            if (($group.members).count -eq 0) {
                $emptyGroup = @{
                    Name = $group.Name
                    whenCreated = $group.whenCreated
                    whenChanged = $group.whenChanged
                }
                $emptyGroup | Export-Csv -Path $LogFile -Append -NoTypeInformation
            }
        }
        Write-Host "Processed batch $($i+1) of $batchCount"
    }
    $end = Get-Date
    Write-Host "Finished looking for empty groups at $end."
    Write-Host "Total time taken: $(($end - $start))"
    Write-Host "Empties logged to: $LogFile"
}