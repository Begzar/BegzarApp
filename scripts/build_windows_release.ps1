#Requires -Version 5.1
<#
.SYNOPSIS
  Hardened Flutter Windows release: obfuscated binary, no PDB in artifacts,
  begzar_engine DLL (stripped), portable ZIP + optional Inno Setup installer.
  Fails if any artifact contains this machine's identity (account, host,
  domain, git identity, local paths) - probes are read from the machine at
  build time, nothing is hardcoded.

.EXAMPLE
  .\scripts\build_windows_release.ps1

.EXAMPLE
  .\scripts\build_windows_release.ps1 -Source github

.EXAMPLE
  .\scripts\build_windows_release.ps1 -Source ms_store -SkipInstaller

DISTRIBUTION_SOURCE (github | ms_store) is baked in via --dart-define.
Default: github. Override with -Source or the DISTRIBUTION_SOURCE env var.
#>
[CmdletBinding()]
param(
  [switch]$SkipFlutterBuild,
  [switch]$SkipBegzar,
  [switch]$SkipPortable,
  [switch]$SkipInstaller,
  [switch]$InstallInnoSetup,
  [switch]$NoClean,
  [string]$Source = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "ReleaseHardening.ps1")

function Write-Step([string]$Message) {
  Write-Host ""
  Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-PubspecVersion([string]$PubspecPath) {
  $line = Get-Content -Path $PubspecPath |
    Where-Object { $_ -match '^\s*version:\s*' } |
    Select-Object -First 1
  if (-not $line) {
    throw "Could not read version from $PubspecPath"
  }
  $raw = ($line -replace '^\s*version:\s*', '').Trim()
  if ($raw -notmatch '^([0-9]+(?:\.[0-9]+)*)(?:\+(\d+))?$') {
    throw "Unexpected version format: $raw"
  }
  return [pscustomobject]@{
    Name  = $Matches[1]
    Build = if ($Matches[2]) { $Matches[2] } else { "0" }
    Full  = $raw
  }
}

function Find-InnoCompiler {
  $candidates = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "${env:LocalAppData}\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 7\ISCC.exe"
  )
  foreach ($path in $candidates) {
    if (Test-Path $path) { return $path }
  }
  $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

function Ensure-InnoSetup {
  $iscc = Find-InnoCompiler
  if ($iscc) { return $iscc }

  if (-not $InstallInnoSetup) {
    throw @"
Inno Setup compiler (ISCC.exe) not found.
Install it, then re-run:
  winget install --id JRSoftware.InnoSetup --source winget --accept-package-agreements --accept-source-agreements
Or re-run this script with -InstallInnoSetup
"@
  }

  Write-Step "Installing Inno Setup via winget..."
  winget install --id JRSoftware.InnoSetup --source winget `
    --accept-package-agreements --accept-source-agreements --disable-interactivity |
    Out-Host

  $iscc = Find-InnoCompiler
  if (-not $iscc) {
    throw "Inno Setup installed but ISCC.exe still not found. Open a new terminal and retry."
  }
  return $iscc
}

# Resolves the flutter command this build runs.
#
# PATH is the usual answer and the only one CI ever needs, but a local shell
# often does not carry the SDK, and calling `flutter` bare turned that into a
# CommandNotFoundException from the middle of the build. FLUTTER_ROOT comes
# first because someone who sets it means it. The project's own
# package_config.json is the last resort: it records the SDK that actually
# resolved these packages, which is the right one to build them with. Every
# candidate is read at build time — nothing here is hardcoded to a machine.
function Resolve-Flutter {
  if ($env:FLUTTER_ROOT) {
    $fromRoot = Join-Path $env:FLUTTER_ROOT "bin\flutter.bat"
    if (Test-Path $fromRoot) { return $fromRoot }
    Write-Warning "FLUTTER_ROOT is set but has no bin\flutter.bat: $env:FLUTTER_ROOT"
  }

  $onPath = Get-Command flutter -ErrorAction SilentlyContinue
  if ($onPath) { return $onPath.Source }

  # Read before `flutter clean` deletes it; resolution happens up front.
  $packageConfig = Join-Path $root ".dart_tool\package_config.json"
  if (Test-Path $packageConfig) {
    try {
      $config = Get-Content -Raw -Path $packageConfig | ConvertFrom-Json
      $pkg = $config.packages | Where-Object { $_.name -eq "flutter" } | Select-Object -First 1
      if ($pkg) {
        # rootUri points at <sdk>/packages/flutter, absolute or relative to .dart_tool.
        $uri = [System.Uri]::UnescapeDataString(($pkg.rootUri -replace '^file:///', ''))
        if ($uri) {
          if (-not [System.IO.Path]::IsPathRooted($uri)) {
            $uri = Join-Path (Split-Path -Parent $packageConfig) $uri
          }
          $sdk = Split-Path -Parent (Split-Path -Parent $uri)
          $fromConfig = Join-Path $sdk "bin\flutter.bat"
          if (Test-Path $fromConfig) { return $fromConfig }
        }
      }
    } catch {
      # A package_config this script cannot parse is not its failure to report;
      # fall through to the message below, which says what to do about it.
    }
  }

  throw @"
Flutter SDK not found.
Add the SDK's bin directory to PATH, or point FLUTTER_ROOT at the SDK root:
  `$env:FLUTTER_ROOT = "C:\path\to\flutter"
"@
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

$pubspec = Join-Path $root "pubspec.yaml"
$version = Get-PubspecVersion $pubspec
$releaseDir = Join-Path $root "build\windows\x64\runner\Release"
$distDir = Join-Path $root "dist"
$debugInfoDir = Join-Path $root "build\debug-info\windows"
$issPath = Join-Path $root "windows\installer\begzar.iss"
$exeName = "begzar.exe"

Write-Host "Begzar Windows hardened release build" -ForegroundColor Green
Write-Host "Version: $($version.Full)"
$distributionSource = Resolve-DistributionSource -Platform "windows" -Default "github" -CliSource $Source
Write-Host "Source:  $distributionSource"
Write-Host "Root:    $root"
Write-Host "Security: Dart obfuscate + split debug-info + strip PDB/ILK from artifacts + machine identity scan"

# Resolved before the engine is built: a missing SDK used to surface minutes in,
# after the Go compile had already run, rather than on the second line.
$flutter = $null
if (-not $SkipFlutterBuild) {
  $flutter = Resolve-Flutter
  Write-Host "Flutter: $flutter"
}

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
New-Item -ItemType Directory -Force -Path $debugInfoDir | Out-Null

# pubspec.yaml depends on the open stand-in, which connects nothing; a release
# is built on the private engine, chosen by an uncommitted pubspec_overrides.yaml
# as scripts/use_engine.sh writes it.
Write-Step "Choosing the private engine"
if (-not (Test-Path (Join-Path $root "begzar-engine\pubspec.yaml"))) {
  throw "The private engine is not checked out: git submodule update --init"
}
@(
  "# Written by build_windows_release.ps1; not committed."
  "dependency_overrides:"
  "  begzar_engine:"
  "    path: begzar-engine"
) | Set-Content -Encoding ascii -Path (Join-Path $root "pubspec_overrides.yaml")

$begzarZip = Join-Path $root "begzar-engine\windows\libbegzar_engine.zip"
if (-not $SkipBegzar) {
  Write-Step "Building begzar_engine engine DLL and tunnel helper, with pinned Wintun (stripped, trimpath)"
  $begzarScript = Join-Path $root "begzar-engine\scripts\build_windows.ps1"
  if (-not (Test-Path $begzarScript)) {
    throw @"
begzar Windows build script missing: $begzarScript
It is likely ignored by begzar-engine/.gitignore (scripts/*). Ensure !scripts/*.ps1 is allowed and the file is committed.
"@
  }
  & $begzarScript -SkipFfigen
  if (-not (Test-Path $begzarZip)) {
    throw "begzar_engine zip missing after build: $begzarZip"
  }
} else {
  Write-Step "Skipping begzar_engine build (-SkipBegzar)"
  if (-not (Test-Path $begzarZip)) {
    throw "begzar_engine zip not found: $begzarZip (run without -SkipBegzar)"
  }
}

if (-not $SkipFlutterBuild) {
  if (-not $NoClean) {
    Write-Step "flutter clean (fresh release tree)"
    & $flutter clean
    if ($LASTEXITCODE -ne 0) { throw "flutter clean failed" }
  }

  Write-Step "flutter pub get"
  & $flutter pub get
  if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

  $hardeningArgs = Get-ReleaseFlutterHardeningArgs $debugInfoDir $distributionSource
  Write-Step "flutter build windows (obfuscated release)"
  & $flutter build windows @hardeningArgs
  if ($LASTEXITCODE -ne 0) { throw "flutter build windows failed" }

  Write-Step "Verifying Dart obfuscation symbols"
  Assert-ObfuscationSymbols $debugInfoDir
} else {
  Write-Step "Skipping Flutter build (-SkipFlutterBuild)"
}

$exePath = Join-Path $releaseDir $exeName
if (-not (Test-Path $exePath)) {
  throw "Release binary not found: $exePath"
}

Write-Step "Removing Windows debug artifacts (PDB/ILK/EXP) from release tree"
Remove-WindowsDebugArtifacts $releaseDir
Assert-NoDebugArtifactsInTree $releaseDir "Windows Release"

Write-Step "Scanning release tree for machine identity (account, host, domain, local paths)"
$identityProbes = Get-MachineIdentityProbes -RepoRoot "$root"
Assert-NoMachineIdentityInArtifacts -Paths $releaseDir -RepoRoot "$root" -Label "Windows Release tree" -ProbeSet $identityProbes

$artifactStamp = "Begzar-$($version.Name)+$($version.Build)-Windows"
$producedArtifacts = @()

if (-not $SkipPortable) {
  Write-Step "Creating portable ZIP (no debug symbols)"
  $portableZip = Join-Path $distDir "$artifactStamp-Portable.zip"
  if (Test-Path $portableZip) { Remove-Item -Force $portableZip }

  $portableStage = Join-Path $env:TEMP "begzar-portable-$([guid]::NewGuid().ToString('N'))"
  $portableRoot = Join-Path $portableStage $artifactStamp
  New-Item -ItemType Directory -Force -Path $portableRoot | Out-Null
  Copy-Item -Path (Join-Path $releaseDir "*") -Destination $portableRoot -Recurse -Force
  Remove-WindowsDebugArtifacts $portableRoot
  Assert-NoDebugArtifactsInTree $portableRoot "Windows portable ZIP"

  $readme = @"
Begzar Portable $($version.Full)

1. Extract this folder anywhere.
2. Run begzar.exe
3. No installer required.

"@
  Set-Content -Path (Join-Path $portableRoot "README.txt") -Value $readme -Encoding UTF8

  Compress-Archive -Path $portableRoot -DestinationPath $portableZip -Force
  Remove-Item -Recurse -Force $portableStage
  Write-Host "Portable: $portableZip" -ForegroundColor Green
  $producedArtifacts += $portableZip
}

if (-not $SkipInstaller) {
  Write-Step "Building Inno Setup installer (release tree without PDB)"
  $iscc = Ensure-InnoSetup
  Write-Host "ISCC: $iscc"

  $releaseDirForIss = $releaseDir.Replace('\', '/')
  $distDirForIss = $distDir.Replace('\', '/')

  & $iscc `
    "/DMyAppVersion=$($version.Name)" `
    "/DMyAppBuild=$($version.Build)" `
    "/DMyReleaseDir=$releaseDirForIss" `
    "/DMyOutputDir=$distDirForIss" `
    $issPath
  if ($LASTEXITCODE -ne 0) { throw "Inno Setup compile failed" }

  $setupExe = Join-Path $distDir "$artifactStamp-Setup.exe"
  if (-not (Test-Path $setupExe)) {
    $setupExe = Get-ChildItem -Path $distDir -Filter "*-Setup.exe" |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1 -ExpandProperty FullName
  }
  Write-Host "Installer: $setupExe" -ForegroundColor Green
  if ($setupExe) { $producedArtifacts += $setupExe }
}

if ($producedArtifacts.Count -gt 0) {
  Write-Step "Scanning packaged artifacts for machine identity (raw ZIP / installer bytes)"
  Assert-NoMachineIdentityInArtifacts -Paths $producedArtifacts -RepoRoot "$root" -Label "dist artifacts" -ProbeSet $identityProbes
}

Write-Step "Done"
Write-Host "Artifacts in: $distDir"
Write-Host "PRIVATE (crash deobfuscation only): $debugInfoDir"
Write-Host "Never publish debug-info/ with release builds."
Get-ChildItem $distDir | Format-Table Name, Length, LastWriteTime
