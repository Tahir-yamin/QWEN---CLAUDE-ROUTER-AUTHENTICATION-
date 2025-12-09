# PowerShell script to update Qwen access_token into Claude Code Router config
param(
    [string]$QwenCreds = "$env:USERPROFILE\.qwen\oauth_creds.json",
    [string]$CcrConfig = "$env:USERPROFILE\.claude-code-router\config.json"
)

Set-StrictMode -Version Latest

if (-not (Test-Path $QwenCreds)) {
    Write-Error "Qwen credentials file not found at $QwenCreds"
    exit 2
}
if (-not (Test-Path $CcrConfig)) {
    Write-Error "CCR config file not found at $CcrConfig"
    exit 2
}

# Read and parse
$creds = Get-Content $QwenCreds -Raw | ConvertFrom-Json
$token = $creds.access_token
if (-not $token) {
    Write-Error "access_token not found in $QwenCreds"
    exit 2
}

# Backup
$bak = "$CcrConfig.bak.$([int][double]::Parse((Get-Date -UFormat %s)))"
Copy-Item -Path $CcrConfig -Destination $bak -Force

$json = Get-Content $CcrConfig -Raw | ConvertFrom-Json
$updated = $false

# Helper to write JSON back preserving formatting as best as possible
function Write-JsonFile($obj, $path) {
    $obj | ConvertTo-Json -Depth 100 | Out-File -FilePath $path -Encoding UTF8
}

# 1) top level keys
if ($json.PSObject.Properties.Name -contains 'api_key') {
    $json.api_key = $token
    Write-JsonFile $json $CcrConfig
    Write-Host "Updated top-level api_key in $CcrConfig"
    $updated = $true
}
elseif ($json.PSObject.Properties.Name -contains 'APIKEY') {
    $json.APIKEY = $token
    Write-JsonFile $json $CcrConfig
    Write-Host "Updated top-level APIKEY in $CcrConfig"
    $updated = $true
}

# 2) single-provider object with name 'qwen'
if (-not $updated -and $json.name -eq 'qwen') {
    $json.api_key = $token
    Write-JsonFile $json $CcrConfig
    Write-Host "Updated api_key for single provider named 'qwen'"
    $updated = $true
}

# 3) Providers or providers array
if (-not $updated) {
    if ($json.PSObject.Properties.Name -contains 'Providers') {
        $found = $false
        for ($i=0; $i -lt $json.Providers.Count; $i++) {
            if ($json.Providers[$i].name -eq 'qwen') {
                $json.Providers[$i].api_key = $token
                $found = $true
            }
        }
        if ($found) {
            Write-JsonFile $json $CcrConfig
            Write-Host "Updated api_key for provider 'qwen' in .Providers[]"
            $updated = $true
        }
    }
    if (-not $updated -and $json.PSObject.Properties.Name -contains 'providers') {
        $found = $false
        for ($i=0; $i -lt $json.providers.Count; $i++) {
            if ($json.providers[$i].name -eq 'qwen') {
                $json.providers[$i].api_key = $token
                $found = $true
            }
        }
        if ($found) {
            Write-JsonFile $json $CcrConfig
            Write-Host "Updated api_key for provider 'qwen' in .providers[]"
            $updated = $true
        }
    }
}

if (-not $updated) {
    Write-Host "Could not detect where to update api_key in $CcrConfig. Token is: `n$token"
    exit 3
}

# Try to restart ccr if available
try {
    if (Get-Command ccr -ErrorAction SilentlyContinue) {
        Write-Host "Restarting ccr..."
        & ccr stop
        & ccr start
        Write-Host "ccr restarted."
    } else {
        Write-Host "ccr command not found on PATH. Please restart the router manually: ccr stop && ccr start"
    }
} catch {
    Write-Warning "Failed to restart ccr automatically: $_"
}

Write-Host "Done. Backup saved to $bak"