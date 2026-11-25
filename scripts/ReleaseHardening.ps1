# Shared release hardening helpers for Windows builds.
# Dot-source from build_windows_release.ps1.

function Get-ReleaseFlutterHardeningArgs {
  param(
    [string]$DebugInfoDir,
    [string]$DistributionSource = 'github'
  )
  return @(
    '--release'
    '--obfuscate'
    "--split-debug-info=$DebugInfoDir"
    '--tree-shake-icons'
    '--dart-define=FLUTTER_BUILD_MODE=release'
    "--dart-define=DISTRIBUTION_SOURCE=$DistributionSource"
  )
}

function Resolve-DistributionSource {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Platform,
    [string]$Default = 'github',
    [string]$CliSource = ''
  )
  $source = $CliSource
  if ([string]::IsNullOrWhiteSpace($source)) {
    $source = $env:DISTRIBUTION_SOURCE
  }
  if ([string]::IsNullOrWhiteSpace($source)) {
    $source = $Default
  }
  $source = $source.Trim().ToLowerInvariant().Replace('-', '_')
  switch ($source) {
    'gh' { $source = 'github' }
    'googleplay' { $source = 'google_play' }
    'play' { $source = 'google_play' }
    'play_store' { $source = 'google_play' }
    'msstore' { $source = 'ms_store' }
    'microsoft_store' { $source = 'ms_store' }
    'test_flight' { $source = 'testflight' }
    'appstore' { $source = 'app_store' }
  }
  $allowed = @{
    android = @('github', 'google_play')
    windows = @('github', 'ms_store')
    macos   = @('github', 'testflight', 'app_store')
    ios     = @('testflight', 'app_store')
  }[$Platform]
  if (-not $allowed) {
    throw "Unknown platform for distribution source: $Platform"
  }
  if ($allowed -notcontains $source) {
    throw "Invalid DISTRIBUTION_SOURCE '$source' for $Platform (allowed: $($allowed -join ', '))"
  }
  return $source
}

function Assert-ObfuscationSymbols {
  param([string]$SymbolsDir)
  if (-not (Test-Path $SymbolsDir)) {
    throw "Obfuscation symbols directory missing: $SymbolsDir"
  }
  $files = Get-ChildItem -Path $SymbolsDir -File -Recurse -ErrorAction SilentlyContinue
  if (-not $files -or $files.Count -eq 0) {
    throw "Obfuscation debug symbols empty in $SymbolsDir (build may not be obfuscated)."
  }
}

function Remove-WindowsDebugArtifacts {
  param([string]$ReleaseDir)
  if (-not (Test-Path $ReleaseDir)) { return }
  Get-ChildItem -Path $ReleaseDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in '.pdb', '.ilk', '.exp' } |
    ForEach-Object { Remove-Item -Force $_.FullName }
}

function Assert-NoDebugArtifactsInTree {
  param(
    [string]$Dir,
    [string]$Label
  )
  if (-not (Test-Path $Dir)) { return }
  $bad = Get-ChildItem -Path $Dir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in '.pdb', '.dbg' }
  if ($bad) {
    throw "Debug artifacts ($Label) still present in release tree: $($bad[0].FullName)"
  }
}

# ---------------------------------------------------------------------------
# Machine identity guard
#
# Nothing below is hardcoded. Every probe is read from the machine that runs
# the build (account name, computer name, domain, DNS host name, account full
# name, git user.name / user.email, user profile and other local paths, the
# repo root, the Flutter SDK and Go paths). Artifacts are scanned for those
# values as UTF-8/ASCII and as UTF-16LE, and the build fails on any hit.
# Probe values are never printed, so CI logs stay clean even on a failure.
# ---------------------------------------------------------------------------

function Get-FlutterSdkRoot {
  if ($env:FLUTTER_ROOT) { return $env:FLUTTER_ROOT }
  $cmd = Get-Command flutter -ErrorAction SilentlyContinue
  if (-not $cmd -or -not $cmd.Source) { return $null }
  $bin = Split-Path -Parent $cmd.Source
  if ((Split-Path -Leaf $bin) -ieq 'bin') { return Split-Path -Parent $bin }
  return $bin
}

function Get-GoEnvPathCandidates {
  if (-not (Get-Command go -ErrorAction SilentlyContinue)) { return @() }
  $result = @()
  foreach ($name in 'GOPATH', 'GOROOT', 'GOMODCACHE') {
    try {
      $value = @(& go env $name) | Select-Object -First 1
      if ($value) { $result += @{ Source = $name; Kind = 'path'; Value = $value } }
    } catch { }
  }
  return $result
}

function Get-MachineIdentityProbes {
  param([string]$RepoRoot)

  # pwsh 7.4+ turns a non-zero native exit code into a terminating error under
  # $ErrorActionPreference = 'Stop'; the probes below tolerate missing tools.
  $PSNativeCommandUseErrorActionPreference = $false

  $candidates = @()
  foreach ($name in 'USERNAME', 'USER', 'LOGNAME', 'COMPUTERNAME', 'USERDOMAIN', 'USERDNSDOMAIN', 'USERDOMAIN_ROAMINGPROFILE') {
    $candidates += @{ Source = $name; Kind = 'identity'; Value = [Environment]::GetEnvironmentVariable($name) }
  }
  $candidates += @{ Source = 'LOGONSERVER'; Kind = 'identity'; Value = ("$env:LOGONSERVER" -replace '^\\+', '') }
  $candidates += @{ Source = 'MachineName'; Kind = 'identity'; Value = [Environment]::MachineName }
  $candidates += @{ Source = 'UserName'; Kind = 'identity'; Value = [Environment]::UserName }
  $candidates += @{ Source = 'UserDomainName'; Kind = 'identity'; Value = [Environment]::UserDomainName }
  try {
    $ipProps = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
    $candidates += @{ Source = 'HostName'; Kind = 'identity'; Value = $ipProps.HostName }
    $candidates += @{ Source = 'DnsDomain'; Kind = 'identity'; Value = $ipProps.DomainName }
    if ($ipProps.HostName -and $ipProps.DomainName) {
      $candidates += @{ Source = 'Fqdn'; Kind = 'identity'; Value = "$($ipProps.HostName).$($ipProps.DomainName)" }
    }
  } catch { }
  try {
    $candidates += @{ Source = 'DnsHostName'; Kind = 'identity'; Value = [System.Net.Dns]::GetHostName() }
  } catch { }
  try {
    $account = Get-LocalUser -Name ([Environment]::UserName) -ErrorAction Stop
    $candidates += @{ Source = 'AccountFullName'; Kind = 'identity'; Value = $account.FullName }
  } catch { }
  if ((Get-Command git -ErrorAction SilentlyContinue) -and $RepoRoot -and (Test-Path $RepoRoot)) {
    Push-Location $RepoRoot
    try {
      # --default keeps the exit code at 0 when the key is unset (as on CI).
      foreach ($pair in @(@('GitUserName', 'user.name'), @('GitUserEmail', 'user.email'))) {
        try {
          $value = @(& git config --get --default '' $pair[1]) | Select-Object -First 1
          $candidates += @{ Source = $pair[0]; Kind = 'identity'; Value = $value }
        } catch { }
      }
    } finally { Pop-Location }
  }

  foreach ($name in 'USERPROFILE', 'HOME', 'LOCALAPPDATA', 'APPDATA', 'TEMP', 'TMP', 'PUB_CACHE', 'FLUTTER_ROOT') {
    $candidates += @{ Source = $name; Kind = 'path'; Value = [Environment]::GetEnvironmentVariable($name) }
  }
  if ($env:HOMEDRIVE -and $env:HOMEPATH) {
    $candidates += @{ Source = 'HOMEDRIVE+HOMEPATH'; Kind = 'path'; Value = "$env:HOMEDRIVE$env:HOMEPATH" }
  }
  $candidates += @{ Source = 'FlutterSdk'; Kind = 'path'; Value = (Get-FlutterSdkRoot) }
  $candidates += Get-GoEnvPathCandidates
  if ($RepoRoot) { $candidates += @{ Source = 'RepoRoot'; Kind = 'path'; Value = $RepoRoot } }

  $probes = @()
  $skipped = @()
  $seen = @{}
  foreach ($c in $candidates) {
    $value = "$($c.Value)".Trim()
    if ($c.Kind -eq 'path') { $value = $value.TrimEnd('\', '/') }
    if (-not $value) { continue }
    if ($value.Length -lt 3) { $skipped += $c.Source; continue }
    $key = $value.ToLowerInvariant()
    if ($c.Kind -eq 'path') { $key = $key.Replace('/', '\') }
    if ($seen.ContainsKey($key)) { continue }
    $seen[$key] = $true
    $probes += [pscustomobject]@{ Source = $c.Source; Kind = $c.Kind; Value = $value }
  }

  # A path nested under another probed path is already covered by the parent.
  $pathProbes = @($probes | Where-Object { $_.Kind -eq 'path' })
  $probes = @($probes | Where-Object {
    if ($_.Kind -ne 'path') { return $true }
    $self = $_.Value.Replace('/', '\')
    foreach ($other in $pathProbes) {
      $parent = $other.Value.Replace('/', '\')
      if ($parent.Length -lt $self.Length -and $self.StartsWith($parent + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
        return $false
      }
    }
    return $true
  })

  return [pscustomobject]@{ Probes = $probes; Skipped = $skipped }
}

function ConvertTo-ProbeRegex {
  # Regex for one probe value as it would appear in a file decoded as Latin-1
  # (one char per byte), using $Encoding for the on-disk byte form.
  param(
    [string]$Value,
    [bool]$IsPath,
    [System.Text.Encoding]$Encoding
  )
  $latin1 = [System.Text.Encoding]::GetEncoding(28591)
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $Value.ToCharArray()) {
    $bytes = $Encoding.GetBytes([string]$ch)
    if ($IsPath -and ($ch -eq '\' -or $ch -eq '/')) {
      # Either separator; the path may have been recorded with forward slashes.
      $chunk = '[\\/]'
      if ($bytes.Length -gt 1) { $chunk += [regex]::Escape($latin1.GetString($bytes, 1, $bytes.Length - 1)) }
    } else {
      $chunk = [regex]::Escape($latin1.GetString($bytes))
    }
    [void]$sb.Append($chunk)
  }
  return $sb.ToString()
}

function New-ProbeScanner {
  param(
    [object[]]$Probes,
    [System.Text.Encoding]$Encoding,
    [string]$Name
  )
  $alternatives = @()
  for ($i = 0; $i -lt $Probes.Count; $i++) {
    $body = ConvertTo-ProbeRegex -Value $Probes[$i].Value -IsPath ($Probes[$i].Kind -eq 'path') -Encoding $Encoding
    $alternatives += "(?<p$i>$body)"
  }
  # Whole-token match: a hit must not sit inside a longer identifier, so a
  # short account name does not trip on unrelated words in the binaries.
  $latin1 = [System.Text.Encoding]::GetEncoding(28591)
  $letter = $Encoding.GetBytes('a')
  $tail = ''
  if ($letter.Length -gt 1) { $tail = [regex]::Escape($latin1.GetString($letter, 1, $letter.Length - 1)) }
  $pattern = "(?<![A-Za-z0-9_]$tail)(?:" + ($alternatives -join '|') + ")(?![A-Za-z0-9_]$tail)"
  $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant -bor
    [System.Text.RegularExpressions.RegexOptions]::Compiled
  return [pscustomobject]@{
    Name  = $Name
    Regex = New-Object System.Text.RegularExpressions.Regex($pattern, $options)
    Strip = ($letter.Length -gt 1)
  }
}

function Assert-NoMachineIdentityInArtifacts {
  param(
    [Parameter(Mandatory = $true)][string[]]$Paths,
    [string]$RepoRoot,
    [string]$Label = 'artifacts',
    [object]$ProbeSet
  )
  if (-not $ProbeSet) { $ProbeSet = Get-MachineIdentityProbes -RepoRoot $RepoRoot }
  $probes = @($ProbeSet.Probes)
  if ($probes.Count -eq 0) {
    throw "Machine identity scan ($Label): no probes could be derived from this machine."
  }

  $files = @()
  foreach ($path in $Paths) {
    if (-not $path) { continue }
    if (-not (Test-Path $path)) { throw "Machine identity scan ($Label): path not found: $path" }
    $item = Get-Item $path
    if ($item.PSIsContainer) {
      $base = $item.FullName.TrimEnd('\') + '\'
      foreach ($f in Get-ChildItem -Path $item.FullName -Recurse -File) {
        $files += [pscustomobject]@{ Item = $f; Display = $f.FullName.Substring($base.Length) }
      }
    } else {
      $files += [pscustomobject]@{ Item = $item; Display = $item.Name }
    }
  }
  if ($files.Count -eq 0) { throw "Machine identity scan ($Label): nothing to scan under: $($Paths -join ', ')" }

  Write-Host ("Probes ({0}, values not printed): {1}" -f $probes.Count, (($probes | ForEach-Object { $_.Source }) -join ', '))
  if ($ProbeSet.Skipped.Count -gt 0) {
    Write-Host ("Skipped (shorter than 3 chars): {0}" -f ($ProbeSet.Skipped -join ', '))
  }

  $latin1 = [System.Text.Encoding]::GetEncoding(28591)
  $scanners = @(
    (New-ProbeScanner -Probes $probes -Encoding ([System.Text.Encoding]::UTF8) -Name 'utf8'),
    (New-ProbeScanner -Probes $probes -Encoding ([System.Text.Encoding]::Unicode) -Name 'utf16le')
  )
  # Redactors keep probe values out of the printed context (and out of CI logs).
  $redactOptions = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
  $redactors = @()
  foreach ($p in $probes) {
    foreach ($enc in @([System.Text.Encoding]::UTF8, $latin1)) {
      $body = ConvertTo-ProbeRegex -Value $p.Value -IsPath ($p.Kind -eq 'path') -Encoding $enc
      $redactors += [pscustomobject]@{
        Source = $p.Source
        Regex  = New-Object System.Text.RegularExpressions.Regex($body, $redactOptions)
      }
    }
  }

  $findings = @()
  $shown = @{}
  $suppressed = @{}
  $totalBytes = 0
  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  foreach ($entry in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($entry.Item.FullName)
    $totalBytes += $bytes.Length
    if ($bytes.Length -eq 0) { continue }
    $text = $latin1.GetString($bytes)
    foreach ($scanner in $scanners) {
      foreach ($hit in $scanner.Regex.Matches($text)) {
        $probe = $null
        for ($i = 0; $i -lt $probes.Count; $i++) {
          if ($hit.Groups["p$i"].Success) { $probe = $probes[$i]; break }
        }
        if (-not $probe) { continue }
        $key = "{0}|{1}|{2}" -f $entry.Display, $probe.Source, $scanner.Name
        if (-not $shown.ContainsKey($key)) { $shown[$key] = 0; $suppressed[$key] = 0 }
        if ($shown[$key] -ge 3) { $suppressed[$key]++; continue }
        $shown[$key]++

        $ctxStart = [Math]::Max(0, $hit.Index - 96)
        $ctxEnd = [Math]::Min($text.Length, $hit.Index + $hit.Length + 96)
        $context = $text.Substring($ctxStart, $ctxEnd - $ctxStart)
        if ($scanner.Strip) { $context = $context.Replace([string][char]0, '') }
        foreach ($r in $redactors) { $context = $r.Regex.Replace($context, "[$($r.Source)]") }
        $context = [regex]::Replace($context, '[^\x20-\x7E]', '.')

        $severity = 'error'
        $note = ''
        if ($probe.Source -eq 'RepoRoot' -and $context -match 'dart_plugin_registrant\.dart') {
          # Flutter records the build directory in the AOT snapshot and has no
          # --trimpath equivalent. The path itself carries no identity here:
          # anything personal in it would have hit an identity probe as well.
          $severity = 'warning'
          $note = 'Flutter embeds the build directory in data/app.so. Build on CI or from a neutral directory to keep it anonymous.'
        }
        $findings += [pscustomobject]@{
          Key      = $key
          Severity = $severity
          File     = $entry.Display
          Probe    = $probe.Source
          Kind     = $probe.Kind
          Encoding = $scanner.Name
          Offset   = $hit.Index
          Context  = $context
          Note     = $note
        }
      }
    }
  }
  $stopwatch.Stop()
  Write-Host ("Scanned {0} files ({1:N1} MB) in {2:N1}s" -f $files.Count, ($totalBytes / 1MB), $stopwatch.Elapsed.TotalSeconds)

  $inCi = ($env:GITHUB_ACTIONS -eq 'true')
  $reportedKeys = @{}
  foreach ($f in $findings) {
    $color = 'Red'
    if ($f.Severity -eq 'warning') { $color = 'Yellow' }
    Write-Host ("[{0}] {1} <- {2} ({3}, {4} @0x{5:X}): ...{6}..." -f $f.Severity.ToUpper(), $f.File, $f.Probe, $f.Kind, $f.Encoding, $f.Offset, $f.Context) -ForegroundColor $color
    if ($f.Note) { Write-Host "    $($f.Note)" -ForegroundColor $color }
    if ($suppressed[$f.Key] -gt 0 -and -not $reportedKeys.ContainsKey($f.Key)) {
      Write-Host ("    (+{0} more {1} hit(s) in {2})" -f $suppressed[$f.Key], $f.Probe, $f.File) -ForegroundColor $color
    }
    if ($inCi -and -not $reportedKeys.ContainsKey($f.Key)) {
      Write-Host ("::{0}::Machine identity scan ({1}): {2} contains {3} ({4}, {5}). {6}" -f $f.Severity, $Label, $f.File, $f.Probe, $f.Kind, $f.Encoding, $f.Note)
    }
    $reportedKeys[$f.Key] = $true
  }

  $errors = @($findings | Where-Object { $_.Severity -eq 'error' })
  if ($errors.Count -gt 0) {
    throw "Machine identity found in $Label ($($errors.Count) hit(s), see [ERROR] lines above). Refusing to ship."
  }
  Write-Host "OK: no machine identity in $Label" -ForegroundColor Green
}
