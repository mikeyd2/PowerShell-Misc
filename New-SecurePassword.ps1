<#
.SYNOPSIS
Generates a secure password of a specified length.

.DESCRIPTION
The New-SecurePassword function generates a secure password containing a mix of uppercase letters, lowercase letters, numbers, and special characters. The length of the password is specified by the user and must be between 8 and 128 characters.

.PARAMETER Length
Specifies the length of the password to be generated. This parameter is mandatory and must be an integer between 8 and 128.

.EXAMPLE
PS> New-SecurePassword -Length 12
Generates a secure password with a length of 12 characters.
#>
Function New-SecurePassword {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateRange(8, 128)]
        [int]$Length
    )
    $uppercase = 65..90 | ForEach-Object { [char]$_ }
    $lowercase = 97..122 | ForEach-Object { [char]$_ }
    $nums = 48..57 | ForEach-Object { [char]$_ }
    $special = 33..47 + 58..64 + 91..96 + 123..126 | ForEach-Object { [char]$_ }
    $all = $uppercase + $lowercase + $nums + $special

    $passwordChars = @(
        $uppercase | Get-Random
        $lowercase | Get-Random
        $nums | Get-Random
        $special | Get-Random
    )

    for ($i = $passwordChars.Count; $i -lt $Length; $i++) {
        $passwordChars += $all | Get-Random
    }

    $shuffledPassword = $passwordChars | Get-Random -Count $passwordChars.Count
    return -join $shuffledPassword
}
New-SecurePassword -Length 12