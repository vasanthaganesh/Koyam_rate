# build_secure.ps1
# This script reads your .env file and runs/builds the Flutter app with the correct --dart-define flags.

$envFile = ".env"
if (-Not (Test-Path $envFile)) {
    Write-Error ".env file not found! Please create it with SUPABASE_URL and SUPABASE_ANON_KEY."
    exit 1
}

# Parse .env file
$envVars = @{}
Get-Content $envFile | Where-Object { $_ -match "=" } | ForEach-Object {
    $parts = $_.Split("=", 2)
    $key = $parts[0].Trim()
    $val = $parts[1].Trim()
    $envVars[$key] = $val
}

$supabaseUrl = $envVars["SUPABASE_URL"]
$supabaseAnonKey = $envVars["SUPABASE_ANON_KEY"]

if (-Not $supabaseUrl -Or -Not $supabaseAnonKey) {
    Write-Error "SUPABASE_URL or SUPABASE_ANON_KEY missing in .env!"
    exit 1
}

$dartDefines = "--dart-define=SUPABASE_URL=$supabaseUrl --dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey"

Write-Host "--- KoyamRate Secure Launcher ---" -ForegroundColor Cyan
Write-Host "1. Run Debug"
Write-Host "2. Build Release APK"
Write-Host "3. Build App Bundle (AAB)"
$choice = Read-Host "Select an option (1-3)"

switch ($choice) {
    "1" {
        Write-Host "Launching in Debug mode..." -ForegroundColor Green
        Invoke-Expression "flutter run $dartDefines"
    }
    "2" {
        Write-Host "Building Release APK..." -ForegroundColor Green
        Invoke-Expression "flutter build apk --release $dartDefines"
    }
    "3" {
        Write-Host "Building App Bundle..." -ForegroundColor Green
        Invoke-Expression "flutter build appbundle --release $dartDefines"
    }
    Default {
        Write-Host "Invalid selection." -ForegroundColor Red
    }
}
