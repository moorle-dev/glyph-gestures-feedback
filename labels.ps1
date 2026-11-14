# Brings the board's labels to the launch set of 16. Idempotent: `gh label create --force` updates a
# label that exists, and a retired label is deleted only when it is there. Run it with the PC's gh,
# signed in as the owner. -WhatIf prints every write call and runs none.
# `roadmap` is created by roadmap-sync and `via-form` when the server form is switched on.
param(
    [string]$Org = 'moorle-dev',
    [string]$Repo = 'glyph-gestures-feedback',
    [string]$Gh = 'gh',
    [switch]$WhatIf
)
$ErrorActionPreference = 'Stop'
$full = "$Org/$Repo"

$launch = @(
    @('accessibility', 'f143ab', 'Barrier affecting people with disabilities'),
    @('area:input', '5319e7', 'Input devices and platforms'),
    @('area:install', '5319e7', 'Install, packages and upgrades'),
    @('area:recognition', '5319e7', 'Gesture recognition'),
    @('area:studio', '5319e7', 'Studio window and editor tools'),
    @('bug', 'd73a4a', 'Something is broken'),
    @('docs', '0075ca', 'Documentation'),
    @('duplicate', 'cfd3d7', 'Already reported'),
    @('feature', '0e8a16', 'Accepted new feature'),
    @('needs-info', 'fbca04', 'Waiting on details from the reporter'),
    @('question', 'd876e3', 'A question, not a bug'),
    @('wontfix', 'ffffff', 'Not planned'),
    @('needs-triage', 'ededed', 'New, not read yet'),
    @('confirmed', 'b60205', 'Reproduced, or two independent reports agree'),
    @('fixed-pending-release', '0e8a16', 'Fixed for a named version that is not in the store yet'),
    @('from-email', 'c5def5', 'Written from private reports; people to tell by mail when it closes')
)
$retired = @('buyer', 'stale', 'documentation', 'enhancement', 'improvement', 'good first issue', 'help wanted', 'invalid')

function Invoke-Write {
    param([string[]]$GhArgs)
    if ($WhatIf) { Write-Host "WHATIF $Gh $($GhArgs -join ' ')"; return }
    & $Gh @GhArgs
    if ($LASTEXITCODE -ne 0) { throw "gh $($GhArgs -join ' ') failed" }
}

$have = & $Gh label list --repo $full --limit 200 --json name --jq '.[].name'
if ($LASTEXITCODE -ne 0) { throw 'could not read the labels' }
$have = @($have)

foreach ($l in $launch) {
    Invoke-Write @('label', 'create', $l[0], '--repo', $full, '--color', $l[1], '--description', $l[2], '--force')
}
foreach ($name in $retired) {
    if ($have -contains $name) { Invoke-Write @('label', 'delete', $name, '--repo', $full, '--yes') }
    else { Write-Host "ok   $name already gone" }
}

if (-not $WhatIf) {
    $after = @(& $Gh label list --repo $full --limit 200 --json name --jq '.[].name')
    $fail = 0
    foreach ($l in $launch) { if ($after -notcontains $l[0]) { Write-Host "FAIL missing $($l[0])"; $fail++ } }
    foreach ($name in $retired) { if ($after -contains $name) { Write-Host "FAIL still there $name"; $fail++ } }
    $extra = @($after | Where-Object { ($launch | ForEach-Object { $_[0] }) -notcontains $_ -and $_ -notin @('roadmap', 'via-form') })
    if ($extra.Count -gt 0) { Write-Host "FAIL unlisted labels: $($extra -join ', ')"; $fail++ }
    if ($fail -gt 0) { exit 1 }
    Write-Host "PASS the board has the $($launch.Count) launch labels"
}
