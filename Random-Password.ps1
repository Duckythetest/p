$location = Set-Location $env:HOMEPATH"\Desktop"
$savelocation = "RandomPassword.txt"
function Get-RandomPassword {
    param (
        [Parameter(Mandatory)]
        [int] $length,
        [int] $amountOfNonAlphanumeric = 1
    )
    Add-Type -AssemblyName 'System.Web'
    return [System.Web.Security.Membership]::GeneratePassword($length, $amountOfNonAlphanumeric)
}
Get-RandomPassword 32 | Out-File $savelocation
