param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $GodotArgs
)

$localGodot = Join-Path $PSScriptRoot 'work\godot\Godot_v4.5-stable_win64.exe'
$godotCommand = $null

if (Test-Path -LiteralPath $localGodot) {
    $godotCommand = $localGodot
} else {
    $installedGodot = Get-Command godot -ErrorAction SilentlyContinue
    if ($installedGodot) {
        $godotCommand = $installedGodot.Source
    }
}

if (-not $godotCommand) {
    Write-Error 'Godot was not found. Install Godot 4.5+, or place the portable executable at work\godot\Godot_v4.5-stable_win64.exe.'
    exit 1
}

& $godotCommand @GodotArgs
exit $LASTEXITCODE
