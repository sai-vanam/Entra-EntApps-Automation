<#
.SYNOPSIS
    Enterprise Application Governance Audit Script

.DESCRIPTION
    Retrieves all Enterprise Applications (Service Principals) from Microsoft Entra ID
    and exports:

    - Application Name
    - Application ID
    - Service Principal ID
    - Owners
    - Assigned Users/Groups
    - Account Status
    - Certificate Information
    - Certificate Expiry Status

.OUTPUTS
    EnterpriseApps_FullAudit.csv

.NOTES
    Requires:
        Application.Read.All
        Directory.Read.All
        AppRoleAssignment.Read.All

    Author: Sai Vanam
#>

# ============================================================
# CONFIGURATION
# ============================================================

# Output file location
$OutputFile = "$HOME/EnterpriseApps_FullAudit.csv"

# Initialize report array
$Report = @()

# ============================================================
# GET ALL ENTERPRISE APPS
# ============================================================

Write-Host "Retrieving Enterprise Applications..." -ForegroundColor Green

$Apps = Get-MgServicePrincipal -All

Write-Host "$($Apps.Count) applications found." -ForegroundColor Green

# ============================================================
# PROCESS EACH APPLICATION
# ============================================================

foreach ($App in $Apps)
{
    Write-Host "Processing: $($App.DisplayName)"

    # --------------------------------------------------------
    # GET OWNERS
    # --------------------------------------------------------

    try
    {
        $Owners = Get-MgServicePrincipalOwner `
            -ServicePrincipalId $App.Id `
            -ErrorAction Stop

        $OwnerNames = @(
            $Owners | ForEach-Object {
                $_.AdditionalProperties.displayName
            }
        ) -join "; "
    }
    catch
    {
        $OwnerNames = "No Owners Found"
    }

    # --------------------------------------------------------
    # CERTIFICATE INFORMATION
    # --------------------------------------------------------

    $CertificateStartDate = $null
    $CertificateExpiryDate = $null
    $CertificateStatus = "No Certificate"

    if ($App.KeyCredentials.Count -gt 0)
    {
        # Get certificate with latest expiry
        $LatestCertificate = $App.KeyCredentials |
        Sort-Object EndDateTime -Descending |
        Select-Object -First 1

        $CertificateStartDate = $LatestCertificate.StartDateTime
        $CertificateExpiryDate = $LatestCertificate.EndDateTime

        if ($CertificateExpiryDate -lt (Get-Date))
        {
            $CertificateStatus = "Expired"
        }
        else
        {
            $CertificateStatus = "Valid"
        }
    }

    # --------------------------------------------------------
    # GET USER/GROUP ASSIGNMENTS
    # --------------------------------------------------------

    try
    {
        $Assignments = Get-MgServicePrincipalAppRoleAssignedTo `
            -ServicePrincipalId $App.Id `
            -All `
            -ErrorAction Stop
    }
    catch
    {
        $Assignments = @()
    }

    # --------------------------------------------------------
    # APP WITH ASSIGNMENTS
    # --------------------------------------------------------

    if ($Assignments.Count -gt 0)
    {
        foreach ($Assignment in $Assignments)
        {
            $Report += [PSCustomObject]@{

                AppName = $App.DisplayName

                ApplicationId = $App.AppId

                ServicePrincipalId = $App.Id

                AccountEnabled = $App.AccountEnabled

                Owners = $OwnerNames

                AssignedTo = $Assignment.PrincipalDisplayName

                AssignmentType = $Assignment.PrincipalType

                CertificateStartDate = $CertificateStartDate

                CertificateExpiryDate = $CertificateExpiryDate

                CertificateStatus = $CertificateStatus

                ScanDate = Get-Date
            }
        }
    }

    # --------------------------------------------------------
    # APP WITHOUT ASSIGNMENTS
    # --------------------------------------------------------

    else
    {
        $Report += [PSCustomObject]@{

            AppName = $App.DisplayName

            ApplicationId = $App.AppId

            ServicePrincipalId = $App.Id

            AccountEnabled = $App.AccountEnabled

            Owners = $OwnerNames

            AssignedTo = ""

            AssignmentType = ""

            CertificateStartDate = $CertificateStartDate

            CertificateExpiryDate = $CertificateExpiryDate

            CertificateStatus = $CertificateStatus

            ScanDate = Get-Date
        }
    }

}

# ============================================================
# EXPORT RESULTS
# ============================================================

Write-Host "Exporting report..." -ForegroundColor Green

$Report |
Export-Csv `
-Path $OutputFile `
-NoTypeInformation

Write-Host "Report exported to:"
Write-Host $OutputFile -ForegroundColor Cyan

Write-Host "Completed successfully." -ForegroundColor Green