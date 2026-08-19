<#
.SYNOPSIS
    Bump the RWANG plugin version across every harness manifest in one step.

.DESCRIPTION
    Updates the "version" field in:
      .claude-plugin/plugin.json   (Claude Code — this is the marketplace update signal)
      .codex-plugin/plugin.json    (Codex adapter)
    marketplace.json intentionally carries no version: Claude Code always uses
    the plugin.json value (a stale manifest version would mask it).

    Formatting of the JSON files is preserved (regex replace, no re-serialize).

.EXAMPLE
    .\scripts\bump-version.ps1 -Version 1.2.0
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version
)

$ErrorActionPreference = "Stop"
$pluginRoot = Split-Path -Parent $PSScriptRoot

$manifests = @(
    (Join-Path $pluginRoot ".claude-plugin\plugin.json"),
    (Join-Path $pluginRoot ".codex-plugin\plugin.json")
)

foreach ($m in $manifests) {
    if (-not (Test-Path $m)) { throw "Manifest not found: $m" }
    # Read explicitly as UTF-8: PS 5.1 Get-Content defaults to ANSI on BOM-less
    # files and would mangle non-ASCII descriptions on rewrite.
    $content = [System.IO.File]::ReadAllText($m, [System.Text.Encoding]::UTF8)
    $updated = [regex]::Replace($content, '"version"\s*:\s*"\d+\.\d+\.\d+"', ('"version": "' + $Version + '"'), 1)
    if ($updated -eq $content -and $content -notmatch [regex]::Escape('"version": "' + $Version + '"')) {
        throw "No version field found in $m"
    }
    [System.IO.File]::WriteAllText($m, $updated, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "OK  $m -> $Version"
}

Write-Host ""
Write-Host "Next steps: update CHANGELOG.md, commit, then tag v$Version (release workflow verifies tag == manifest versions)."
