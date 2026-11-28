#Requires -Version 5.1
<#
  anotherme skill linter -- L0 mechanical checks.

  Covers only what can be decided without running a model:
    - each skill folder carries SKILL.md
    - frontmatter has name/description, and name equals the folder name
    - clause IDs (**SB-1**) are unique and contiguous per prefix
    - references/*.md linked from a skill actually exists
    - a referenced skill name exists under skills\
    - SKILL.md stays inside the line budget
    - hard-rule lines avoid soft wording
    - README lists every skill and nothing extra

  Behavior, triggering quality and clause conflicts are NOT covered here;
  those need a scenario run (L2), see the eval notes in the repo README.

  Exit code 1 when any ERROR is reported, so this can gate a commit.

  NOTE: keep this file pure ASCII. Windows PowerShell 5.1 reads .ps1
  files as ANSI unless they carry a BOM, so CJK literals would break on
  some machines. The few CJK fragments matched below are built from code
  points in the U() helper.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$repo      = Split-Path -Parent $PSScriptRoot
$skillsDir = Join-Path $repo 'skills'

if (-not (Test-Path -LiteralPath $skillsDir)) {
    Write-Host "[ERROR] skills directory not found: $skillsDir"
    exit 1
}

# ---- CJK fragments built from code points -------------------------------
function U([int[]]$cp) { -join ($cp | ForEach-Object { [char]$_ }) }

$SOFT_WORDS = @(
    @{ Label = 'as-far-as-possible'; Text = (U 0x5C3D, 0x91CF) }
    @{ Label = 'suggest';            Text = (U 0x5EFA, 0x8BAE) }
    @{ Label = 'should';             Text = (U 0x5E94, 0x8BE5) }
    @{ Label = 'preferably';         Text = (U 0x6700, 0x597D) }
)

$LINE_WARN = 120
$LINE_FAIL = 200

# A token ending in one of these is treated as a skill reference, so a typo
# or a deleted skill surfaces as an error instead of a silent no-op.
$SKILL_SUFFIX = @('-spec', '-gate', '-execution', '-stack', '-fidelity',
                  '-troubleshooting', '-writing', '-design', '-research',
                  '-reliability')

$errors   = New-Object 'System.Collections.Generic.List[string]'
$warnings = New-Object 'System.Collections.Generic.List[string]'

function Add-Err([string]$m)  { $script:errors.Add($m) }
function Add-Warn([string]$m) { $script:warnings.Add($m) }

function Read-Text([string]$p) {
    $t = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)
    if ($t.Length -gt 0 -and $t[0] -eq [char]0xFEFF) { $t = $t.Substring(1) }
    return $t
}

$dirs = @(Get-ChildItem -LiteralPath $skillsDir -Directory |
          Where-Object { $_.Name -notlike '_*' } |
          Sort-Object Name)
$known = @($dirs | ForEach-Object { $_.Name })

foreach ($d in $dirs) {
    $name = $d.Name
    $file = Join-Path $d.FullName 'SKILL.md'

    if (-not (Test-Path -LiteralPath $file)) {
        Add-Err "[$name] missing SKILL.md"
        continue
    }

    $text  = Read-Text $file
    $lines = $text -split "`r?`n"

    if ($lines.Count -gt $LINE_FAIL) {
        Add-Err "[$name] SKILL.md is $($lines.Count) lines, over the hard limit ($LINE_FAIL)"
    }
    elseif ($lines.Count -gt $LINE_WARN) {
        Add-Warn "[$name] SKILL.md is $($lines.Count) lines (soft limit $LINE_WARN)"
    }

    # ---- frontmatter ----------------------------------------------------
    $fm = [regex]::Match($text, '(?s)\A---\r?\n(.*?)\r?\n---')
    if (-not $fm.Success) {
        Add-Err "[$name] missing YAML frontmatter"
    }
    else {
        $head = $fm.Groups[1].Value
        $nm = [regex]::Match($head, '(?m)^name:\s*(\S+)\s*$')
        if (-not $nm.Success) {
            Add-Err "[$name] frontmatter has no name field"
        }
        elseif ($nm.Groups[1].Value -ne $name) {
            Add-Err "[$name] frontmatter name '$($nm.Groups[1].Value)' differs from folder name"
        }
        if ($head -notmatch '(?m)^description:') {
            Add-Err "[$name] frontmatter has no description field"
        }
    }

    # ---- clause IDs: **SB-1** ------------------------------------------
    $ids = [regex]::Matches($text, '\*\*([A-Z][A-Z0-9]{1,5})-(\d+)\*\*')
    $buckets = @{}
    foreach ($m in $ids) {
        $p   = $m.Groups[1].Value
        $num = [int]$m.Groups[2].Value
        if (-not $buckets.ContainsKey($p)) {
            $buckets[$p] = New-Object 'System.Collections.Generic.List[int]'
        }
        $buckets[$p].Add($num)
    }
    foreach ($p in $buckets.Keys) {
        $nums = @($buckets[$p] | Sort-Object)
        $dup = @($nums | Group-Object | Where-Object { $_.Count -gt 1 })
        if ($dup.Count -gt 0) {
            $list = ($dup | ForEach-Object { "$p-$($_.Name)" }) -join ', '
            Add-Err "[$name] duplicate clause ID: $list"
        }
        $uniq = @($nums | Sort-Object -Unique)
        if ($uniq.Count -gt 0) {
            $gaps = @(Compare-Object -ReferenceObject (1..$uniq[-1]) -DifferenceObject $uniq |
                      Where-Object { $_.SideIndicator -eq '<=' } |
                      ForEach-Object { $_.InputObject })
            if ($gaps.Count -gt 0) {
                Add-Warn "[$name] clause IDs not contiguous: missing $p-$($gaps -join ", $p-")"
            }
        }
    }

    # ---- linked reference files -----------------------------------------
    # A link may point at this skill's own references/ or at another skill's
    # (`doc-writing` refs `references/readme-template.md`). Resolve the owner
    # from the token right before the path; only fall back to "own missing"
    # when no skill name sits there.
    foreach ($m in [regex]::Matches($text, '`references/([^`\s]+)`')) {
        $rel = $m.Groups[1].Value
        $own = Join-Path (Join-Path $d.FullName 'references') $rel
        if (Test-Path -LiteralPath $own) { continue }

        $start  = [Math]::Max(0, $m.Index - 60)
        $before = ($text.Substring($start, $m.Index - $start) -replace "`r?`n", ' ')
        # `[^`]{0,10}$` forces the match to end at the path, so the last
        # backticked token before it wins even when several skills appear.
        $pm = [regex]::Match($before, '`([a-z][a-z0-9-]+)`[^`]{0,10}$')
        if ($pm.Success) {
            $owner = $pm.Groups[1].Value
            if ($known -notcontains $owner) {
                Add-Err "[$name] linked reference names unknown skill '$owner'"
                continue
            }
            $foreign = Join-Path (Join-Path (Join-Path $skillsDir $owner) 'references') $rel
            if (-not (Test-Path -LiteralPath $foreign)) {
                Add-Err "[$name] cross-skill reference not found: $owner/references/$rel"
            }
            continue
        }

        Add-Err "[$name] linked reference not found: references/$rel"
    }

    # ---- referenced skill names -----------------------------------------
    foreach ($m in [regex]::Matches($text, '`([a-z][a-z0-9]*(?:-[a-z0-9]+)+)`')) {
        $t = $m.Groups[1].Value
        if ($known -contains $t) { continue }
        foreach ($s in $SKILL_SUFFIX) {
            if ($t.EndsWith($s)) {
                Add-Err "[$name] references unknown skill '$t'"
                break
            }
        }
    }

    # ---- soft wording inside hard-rule lines ----------------------------
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch '^\*\*[A-Z][A-Z0-9]{1,5}-\d+\*\*') { continue }
        foreach ($w in $SOFT_WORDS) {
            if ($lines[$i].Contains($w.Text)) {
                # Report the ASCII label, not the CJK word: the console
                # encoding of whoever consumes this output is unknown.
                Add-Warn "[$name] soft wording '$($w.Label)' in clause at line $($i + 1)"
            }
        }
    }
}

# ---- README skill table keeps in sync with skills\ -----------------------
$readme = Join-Path $repo 'README.md'
if (Test-Path -LiteralPath $readme) {
    $rt = Read-Text $readme
    $listed = @([regex]::Matches($rt, '(?m)^\|\s*`([a-z][a-z0-9-]+)`\s*\|') |
                ForEach-Object { $_.Groups[1].Value } |
                Sort-Object -Unique)
    foreach ($k in $known) {
        if ($listed -notcontains $k) {
            Add-Warn "[README] skill '$k' is not listed in the skill table"
        }
    }
    foreach ($l in $listed) {
        if ($known -notcontains $l) {
            Add-Warn "[README] lists '$l' but no such skill folder"
        }
    }
}

# ---- report --------------------------------------------------------------
Write-Host ''
Write-Host "skills scanned: $($known.Count)"
foreach ($e in $errors)   { Write-Host "[ERROR] $e" }
foreach ($w in $warnings) { Write-Host "[WARN]  $w" }
Write-Host ''
Write-Host "errors: $($errors.Count)   warnings: $($warnings.Count)"

if ($errors.Count -gt 0) { exit 1 }
Write-Host 'OK'
exit 0
