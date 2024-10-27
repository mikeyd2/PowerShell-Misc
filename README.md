# PowerShell-Misc

Smaller scripts and functions I've made repeated use of. Time-savers, quality-of-life-uppers & the like. Nothing fancy.

## Contents

- **Read-DistinguishedName.ps1**: Takes the distinguished name of an AD object or string and returns either the domain of that object or the top-most parent OU; if neither option is specified, returns the distinguished name by default.

- **Compare-ADGroupAccess.ps1**: Finds either the difference in network group access between two users (in "diff" mode) or the groups they have in common (in "common" mode). Can take either AD User objects as inputs, or use the Get-ADUser -Filter parameter to query user objects for comparison; filter search field can be specified, as can the domain to pass into the -Server parameter if searching for user objects.  

## Usage

Goes nicely in a moudule and loaded into the shell session on start-up. 