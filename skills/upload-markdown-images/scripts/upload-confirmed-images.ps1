[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]] $ImagePath,

    [Parameter(Mandatory)]
    [switch] $Confirmed,

    [string] $PicGoCommand = 'picgo',

    [ValidateRange(0, 3600)]
    [int] $RetryDelaySeconds = 2,

    [ValidateRange(0, 20)]
    [int] $MaxRetries = 3
)

$ErrorActionPreference = 'Stop'

if (-not $Confirmed) {
    throw 'The -Confirmed switch is required after explicit user approval.'
}

$resolvedPicGoCommand = Get-Command -Name $PicGoCommand -ErrorAction SilentlyContinue
if ($null -eq $resolvedPicGoCommand) {
    throw "PicGo command '$PicGoCommand' was not found. Install PicGo-Core CLI or pass -PicGoCommand."
}

function Get-HttpUrl {
    param([string] $Text)

    $matches = [regex]::Matches($Text, 'https?://[^\s''"<>]+')
    for ($index = $matches.Count - 1; $index -ge 0; $index--) {
        $candidate = $matches[$index].Value.TrimEnd('.', ',', ';')
        $uri = $null
        if ([uri]::TryCreate($candidate, [UriKind]::Absolute, [ref]$uri) -and
            ($uri.Scheme -eq 'http' -or $uri.Scheme -eq 'https')) {
            return $uri.AbsoluteUri
        }
    }

    return $null
}

$results = [System.Collections.Generic.List[object]]::new()
$seenPaths = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($inputPath in $ImagePath) {
    $resolvedPath = $null
    try {
        $resolvedPath = (Resolve-Path -LiteralPath $inputPath -ErrorAction Stop).Path
    }
    catch {
        $results.Add([pscustomobject]@{
            path     = [System.IO.Path]::GetFullPath($inputPath)
            status   = 'failed'
            url      = $null
            attempts = 0
            error    = 'Local image file was not found.'
        })
        continue
    }

    if (-not $seenPaths.Add($resolvedPath)) {
        continue
    }

    $attempts = 0
    $uploadedUrl = $null
    $lastError = $null
    $maximumAttempts = 1 + $MaxRetries

    while ($attempts -lt $maximumAttempts -and -not $uploadedUrl) {
        $attempts++
        $outputText = ''
        $exitCode = 1

        try {
            $previousPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $output = & $resolvedPicGoCommand.Source upload $resolvedPath 2>&1
            $exitCode = $LASTEXITCODE
            $outputText = ($output | Out-String).Trim()
        }
        catch {
            $outputText = $_.Exception.Message
        }
        finally {
            $ErrorActionPreference = $previousPreference
        }

        $uploadedUrl = Get-HttpUrl -Text $outputText
        if (-not $uploadedUrl) {
            if ($exitCode -ne 0) {
                $lastError = "PicGo exited with code $exitCode."
            }
            else {
                $lastError = 'PicGo did not return a valid HTTP(S) URL.'
            }

            if ($attempts -lt $maximumAttempts -and $RetryDelaySeconds -gt 0) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }

    if ($uploadedUrl) {
        $results.Add([pscustomobject]@{
            path     = $resolvedPath
            status   = 'uploaded'
            url      = $uploadedUrl
            attempts = $attempts
            error    = $null
        })
    }
    else {
        $results.Add([pscustomobject]@{
            path     = $resolvedPath
            status   = 'failed'
            url      = $null
            attempts = $attempts
            error    = $lastError
        })
    }
}

ConvertTo-Json -InputObject @($results) -Depth 3
