<#
.SYNOPSIS
Parses a distinguished name (DN) and extracts specific components based on the specified output type.
Particularly useful for extracting the domain from an AD Object in a forest having multiple domains.

.DESCRIPTION
The Read-DistinguishedName function takes a distinguished name (DN) as input and extracts specific components such as the domain, organizational units (OUs), or returns the full DN based on the specified output type. The function supports pipeline input and can handle errors gracefully.

.PARAMETER DN
The distinguished name (DN) to be parsed. This parameter is mandatory and accepts input from the pipeline or by property name.

.PARAMETER OutputType
Specifies the type of output to return. Valid values are 'Domain', 'OU', and 'DN'. The default value is 'DN'.
- 'Domain': Returns the domain component of the DN. 
- 'OU': Returns the everything up to the CN (non-inclusive) component of the DN; useful for extracting the immediate parent OU.
- 'DN': Returns the full distinguished name; default behavior when no output type is specified.

.EXAMPLE
PS> "CN=John Doe,OU=Users,DC=example,DC=com" | Read-DistinguishedName -OutputType 'Domain'
example.com

.EXAMPLE
PS> Read-DistinguishedName -DN "CN=John Doe,OU=Users,DC=example,DC=com" -OutputType 'OU'
OU=Users,DC=example,DC=com

.EXAMPLE
PS> Read-DistinguishedName -DN "CN=John Doe,OU=Users,DC=example,DC=com"
CN=John Doe,OU=Users,DC=example,DC=com

#>
function Read-DistinguishedName {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("DistinguishedName")]
        [String]$DN,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Domain', 'OU', 'DN')]
        [String]$OutputType = 'DN'
    )
        try {
            function Get-DistinguishedNameComponents {
                param (
                    [string]$DN
                )
                return [regex]::Split($DN, '(?<!\\),')
            }
            $DNComponents = Get-DistinguishedNameComponents -DN $DN

            switch($OutputType) {
                'Domain' {
                    return ($DNComponents | Where-Object {$_ -match '^DC='}).Replace("DC=", "") -join "."
                }
                'OU' {
                    return ($DNComponents | Where-Object {$_ -notmatch "^CN="}) -join ","
                }
                'DN' {
                    return $DN
                }
                default{
                    return $DN
                }
            }
        }
        catch {
            Write-Host  "Error: $_ occurred while processing $DN"
        }
}