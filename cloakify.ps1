<#
.SYNOPSIS
    Exfiltration toolset that transforms any filetype into lists of words/phrases/Unicode to ease exfiltration.

.DESCRIPTION
    Base64-encodes the given payload and translates the output using a list of words/phrases/Unicode provided in the cipher.
    This is NOT a secure encryption tool, the output is vulnerable to frequency analysis attacks.

.PARAMETER PayloadFile
    Path to the file to be cloaked.

.PARAMETER CipherFile
    Path to the cipher file containing the list of words/phrases/Unicode.

.PARAMETER OutputFile
    (Optional) Path to save the cloaked output. If not provided, output will be written to console.

.EXAMPLE
    .\cloakify.ps1 -PayloadFile payload.txt -CipherFile ciphers\desserts.txt -OutputFile exfiltrate.txt
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$PayloadFile,

    [Parameter(Mandatory=$true)]
    [string]$CipherFile,

    [string]$OutputFile
)

# Base64 character array
$array64 = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/+=".ToCharArray()

function Invoke-Cloakify {
    param(
        [string]$payloadFilePath,
        [string]$cipherFilePath,
        [string]$outputFilePath
    )

    try {
        # Read payload file as byte array and convert to Base64
        $payloadRaw = [System.IO.File]::ReadAllBytes($payloadFilePath)
        $payloadB64 = [System.Convert]::ToBase64String($payloadRaw)
    }
    catch {
        Write-Host ""
        Write-Host "!!! Oh noes! Problem reading payload file '$payloadFilePath'"
        Write-Host "!!! Verify the file exists and is accessible"
        Write-Host ""
        exit
    }

    try {
        # Read cipher file
        $cipherArray = Get-Content -Path $cipherFilePath -Raw | Split-String -RemoveEmptyStrings
    }
    catch {
        Write-Host ""
        Write-Host "!!! Oh noes! Problem reading cipher '$cipherFilePath'"
        Write-Host "!!! Verify the location of the cipher file"
        Write-Host ""
        exit
    }

    try {
        if ($outputFilePath) {
            Write-Host $outputFilePath
            # Write to output file
            $output = foreach ($char in $payloadB64.ToCharArray()) {
                if ($char -ne "`n") {
                    $cipherArray[$array64.IndexOf($char)]
                }
            }
            Write-Host $output
            $output | Out-File -FilePath $outputFilePath -Encoding utf8
        }
        else {
            # Write to console
            foreach ($char in $payloadB64.ToCharArray()) {
                if ($char -ne "`n") {
                    Write-Output $cipherArray[$array64.IndexOf($char)]
                }
            }
        }
    }
    catch {
        Write-Host ""
        Write-Host "!!! Oh noes! Problem opening or writing to file '$outputFilePath'"
        Write-Host ""
        exit
    }
}

# Helper function to split string by newlines and remove empty entries
function Split-String {
    param(
        [string]$InputString,
        [switch]$RemoveEmptyStrings
    )
    $stringReader = New-Object System.IO.StringReader($InputString)
    $output = while ($line = $stringReader.ReadLine()) {
        $line
    }
    if ($RemoveEmptyStrings) {
        $output = $output | Where-Object { $_ -ne "" }
    }
    return $output
}

# Main execution
if ($PayloadFile -and $CipherFile) {
    Invoke-Cloakify -payloadFilePath $PayloadFile -cipherFilePath $CipherFile -outputFilePath $OutputFile
}
else {
    Write-Host "usage: cloakify.ps1 -PayloadFile <payloadFilename> -CipherFile <cipherFilename> [-OutputFile <outputFilename>]"
    exit
}
```
