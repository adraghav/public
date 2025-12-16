<#
.SYNOPSIS
Converts a file to Base64 and then "cloaks" it using a custom cipher array.

.DESCRIPTION
The script reads the content of a payload file, encodes it in Base64,
and then uses the characters of the Base64 string as indices to select
corresponding lines from a separate cipher file. The result is a
"cloaked" string or file where each Base64 character is replaced by a
string from the cipher file.

.PARAMETER PayloadFilename
The path to the file to be "cloaked" (encoded and mapped).

.PARAMETER CipherFilename
The path to the cipher file. This file must contain 64 or more lines,
each line being the string that will replace a Base64 character.

.PARAMETER OutputFilename
(Optional) The path to the file where the cloaked output will be written.
If omitted, the output will be printed to the console.

.EXAMPLE
.\cloakify.ps1 -PayloadFilename ".\secret.txt" -CipherFilename ".\cipher.txt"
# Prints the cloaked output to the console.

.EXAMPLE
.\cloakify.ps1 -PayloadFilename ".\malware.exe" -CipherFilename ".\cipher.txt" -OutputFilename ".\cloaked_data.txt"
# Writes the cloaked output to 'cloaked_data.txt'.
#>
function Cloakify-Data {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PayloadFilename,

        [Parameter(Mandatory=$true)]
        [string]$CipherFilename,

        [string]$OutputFilename
    )

    # Base64 standard character set (64 characters + padding)
    $Base64Charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/+="
    
    # 1. Read Payload and Convert to Base64
    Write-Verbose "Reading payload file: '$PayloadFilename'"
    try {
        # Read the file content as raw bytes
        $payloadRaw = [System.IO.File]::ReadAllBytes($PayloadFilename)
        # Convert the byte array to a Base64 string
        $payloadB64 = [System.Convert]::ToBase64String($payloadRaw)
    }
    catch {
        Write-Error "!!! Oh noes! Problem reading payload '$PayloadFilename'. Verify the file path."
        return
    }

    # 2. Read Cipher File
    Write-Verbose "Reading cipher file: '$CipherFilename'"
    try {
        # Read all lines from the cipher file
        $cipherArray = Get-Content -Path $CipherFilename -Raw | ConvertFrom-Csv -Delimiter "`n" -Header CipherLine | Select-Object -ExpandProperty CipherLine
    }
    catch {
        Write-Error "!!! Oh noes! Problem reading cipher '$CipherFilename'. Verify the location of the cipher file."
        return
    }

    # Remove any empty lines that Get-Content might return at the end of the file
    $cipherArray = $cipherArray | Where-Object { $_ -ne $null -and $_.Trim() -ne "" }
    
    # Check if we have enough cipher lines (64 is the minimum for the full Base64 charset)
    if ($cipherArray.Count -lt 64) {
        Write-Warning "Cipher file '$CipherFilename' contains $($cipherArray.Count) lines. A full Base64 charset requires 64 lines."
    }

    # 3. Process Base64 and Apply Cloaking
    Write-Verbose "Processing Base64 payload and applying cipher..."
    $cloakedOutput = @()
    
    # Iterate over each character in the Base64 string
    foreach ($char in $payloadB64.ToCharArray()) {
        $charString = [string]$char
        
        # We ignore newline characters (the original Python script does this to handle
        # the way base64.encodestring in older Python versions added newlines)
        if ($charString -ne "`n" -and $charString -ne "`r") {
            # Find the index of the character in the Base64 character set
            $index = $Base64Charset.IndexOf($charString)
            
            if ($index -ge 0) {
                # Map the index to the corresponding line in the cipher array
                if ($index -lt $cipherArray.Count) {
                    $cloakedOutput += $cipherArray[$index]
                } else {
                    Write-Warning "Character '$charString' (index $index) is out of bounds for the cipher array (size $($cipherArray.Count)). Skipping."
                }
            } else {
                # This should only happen for characters not in the charset (e.g., other whitespace)
                Write-Warning "Character '$charString' not found in the Base64 charset. Skipping."
            }
        }
    }

    # 4. Output Result
    if ($OutputFilename) {
        Write-Verbose "Writing cloaked output to file: '$OutputFilename'"
        try {
            # Join the array of cloaked strings and write to the output file
            # The original Python script prints each cipher string on a new line (as read from cipherArray).
            # To emulate this line-by-line output, we use Add-Content/Out-File on the array.
            $cloakedOutput | Out-File -FilePath $OutputFilename -Encoding UTF8
            Write-Host "✅ Successfully wrote cloaked data to '$OutputFilename'"
        }
        catch {
            Write-Error "!!! Oh noes! Problem opening or writing to file '$OutputFilename'. $($_.Exception.Message)"
        }
    }
    else {
        # Print the output to the console, one cloaked string per line
        $cloakedOutput
    }
}

# --- Script Entry Point ---
# Check for correct arguments passed when executing the script file
if ($args.Count -lt 2 -or $args.Count -gt 3) {
    Write-Host "usage: .\cloakify.ps1 <payloadFilename> <cipherFilename> [outputFilename]"
    Exit 1
} else {
    # The $args array contains the command-line arguments in order
    # The argument names in the function call must match the parameter names
    Cloakify-Data -PayloadFilename $args[0] -CipherFilename $args[1] -OutputFilename $args[2]
}