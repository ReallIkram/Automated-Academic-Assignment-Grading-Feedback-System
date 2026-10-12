$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
if (!(Test-Path '.env')) {
 $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
 function RandomHex([int]$length) { $bytes = New-Object byte[] $length; $rng.GetBytes($bytes); return ([BitConverter]::ToString($bytes)).Replace('-', '').ToLower() }
 "POSTGRES_PASSWORD=$(RandomHex 20)`nJWT_SECRET=$(RandomHex 32)`nDEMO_PASSWORD=$(RandomHex 12)`nCORS_ORIGINS=http://localhost:3000" | Set-Content .env -Encoding ascii
 Write-Host 'Created .env. Read DEMO_PASSWORD there to sign in.'
}
foreach ($language in @('python','java','cpp')) {
 docker build -f "sandbox/$language.Dockerfile" -t "gradeflow-${language}:local" sandbox
 if ($LASTEXITCODE -ne 0) { throw 'Sandbox image build failed' }
}
docker compose up --build -d
if ($LASTEXITCODE -ne 0) { throw 'Compose startup failed' }
docker compose run --rm api python -m app.seed
if ($LASTEXITCODE -ne 0) { throw 'Seeding failed' }
