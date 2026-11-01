# Creates the Glyph Gestures feedback repository on GitHub. Idempotent: every step checks first.
# Run after the owner has created the organisation and run `gh auth login`
# (token scopes: repo, project, read:org; run `gh auth refresh -s project` if projects fail).
# -WhatIf prints every write call and runs none.
param(
    [string]$Org = 'moorle-dev',
    [string]$Repo = 'glyph-gestures-feedback',
    [string]$ProjectTitle = 'Glyph Gestures roadmap',
    [switch]$WhatIf
)
$ErrorActionPreference = 'Continue'
$full = "$Org/$Repo"
$manual = New-Object System.Collections.Generic.List[string]
$hasGh = [bool](Get-Command gh -ErrorAction SilentlyContinue)

function Write-Gh {
    # every gh call that changes GitHub goes through here
    param([string[]]$GhArgs)
    if ($WhatIf) { Write-Host "WHATIF gh $($GhArgs -join ' ')"; return $true }
    & gh @GhArgs
    return ($LASTEXITCODE -eq 0)
}
function Read-Gh {
    param([string[]]$GhArgs)
    if (-not $hasGh) { return $null }
    $out = & gh @GhArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $out
}

# 1. repository
if (Read-Gh @('repo', 'view', $full, '--json', 'name')) { Write-Host "ok   repo $full exists" }
else {
    Write-Gh @('repo', 'create', $full, '--public', '--description', 'Glyph Gestures by Moorle: ideas, questions, bugs and roadmap') | Out-Null
}

# 2. push the local files (the repo is created empty; the orchestrator pushes this folder)
$manual.Add("Push this folder: git remote add origin https://github.com/$full.git ; git push -u origin main")

# 3. Discussions
Write-Gh @('repo', 'edit', $full, '--enable-discussions', '--enable-issues') | Out-Null

# 4. discussion categories
# GitHub's default set (Announcements, General, Ideas, Polls, Q&A, Show and tell) already holds the
# four wanted ones. The API has no create/rename/delete-category mutation, so it is a manual step.
$manual.Add("Discussions categories: open https://github.com/$full/discussions > pencil beside Categories. Keep Ideas (Open-ended), Q&A (Question/Answer), Announcements (Announcement, maintainers only) and Show and tell (Open-ended). Delete General and Polls.")

# 5. labels
$labels = @(
    @('bug', 'd73a4a', 'Something is broken'),
    @('feature', '0e8a16', 'Accepted new feature'),
    @('improvement', '1d76db', 'Makes something existing better'),
    @('docs', '0075ca', 'Documentation'),
    @('wontfix', 'ffffff', 'Not planned'),
    @('duplicate', 'cfd3d7', 'Already reported'),
    @('needs-info', 'fbca04', 'Waiting on details from the reporter'),
    @('question', 'd876e3', 'A question, not a bug'),
    @('buyer', '0e8a16', 'Verified purchaser'),
    @('stale', 'ededed', 'No reply from the reporter for a while'),
    @('area:recognition', '5319e7', 'Gesture recognition'),
    @('area:studio', '5319e7', 'Studio window and editor tools'),
    @('area:input', '5319e7', 'Input devices and platforms'),
    @('area:install', '5319e7', 'Install, packages and upgrades')
)
foreach ($l in $labels) {
    Write-Gh @('label', 'create', $l[0], '--repo', $full, '--color', $l[1], '--description', $l[2], '--force') | Out-Null
}

# 6. public project with a Status field
# Projects (v2) need the `project` scope. When a call fails, it becomes a numbered manual step
# below and the script goes on.
$script:projectFailed = $false
function Write-GhProject {
    param([string]$Step, [string[]]$GhArgs)
    if ($script:projectFailed) { return }
    if (-not (Write-Gh $GhArgs)) {
        $script:projectFailed = $true
        $manual.Add("Project ($Step failed, probably the token lacks the project scope): run 'gh auth refresh -s project' and re-run this script, or do it by hand at https://github.com/orgs/$Org/projects : create '$ProjectTitle', make it public, link it to $full, add a text field named Release.")
    }
}
$projects = Read-Gh @('project', 'list', '--owner', $Org, '--format', 'json', '--limit', '100')
$existing = $null
if ($projects) { $existing = ($projects | ConvertFrom-Json).projects | Where-Object { $_.title -eq $ProjectTitle } | Select-Object -First 1 }
if ($existing) { Write-Host "ok   project '$ProjectTitle' exists (#$($existing.number))"; $num = $existing.number }
else {
    Write-GhProject 'create' @('project', 'create', '--owner', $Org, '--title', $ProjectTitle)
    $num = '<number>'
    if (-not $WhatIf -and -not $script:projectFailed) {
        $num = (Read-Gh @('project', 'list', '--owner', $Org, '--format', 'json', '--limit', '100') | ConvertFrom-Json).projects |
            Where-Object { $_.title -eq $ProjectTitle } | Select-Object -First 1 -ExpandProperty number
    }
}
Write-GhProject 'edit' @('project', 'edit', "$num", '--owner', $Org, '--visibility', 'PUBLIC')
Write-GhProject 'link' @('project', 'link', "$num", '--owner', $Org, '--repo', $full)
Write-GhProject 'field-create' @('project', 'field-create', "$num", '--owner', $Org, '--name', 'Release', '--data-type', 'TEXT')
# A new project already has a single-select Status field (Todo / In Progress / Done). gh cannot
# rename its options, and a second field named Status is refused.
$manual.Add("Project Status options: open the project > Settings > Status. Set the options to Under consideration, Planned, In progress, Shipped, Not planned.")
$manual.Add("Project views: Roadmap = Board grouped by Status, filter -status:""Not planned""; Bugs = Table, filter label:bug; Shipped = Table grouped by Release, filter status:Shipped.")
$manual.Add("Project workflows: Settings > Workflows. Item added -> Status Under consideration; Item closed -> Status Shipped; Auto-add to project with filter repo:$full (one allowed on Free).")
$manual.Add("Organisation: set the avatar and the repository social preview image (Settings > General) when the brand pass delivers them.")

# 7. read every created item back by name
Write-Host ''
Write-Host '--- check ---'
$fail = 0
function Check { param([string]$Name, [bool]$Ok) if ($Ok) { Write-Host "PASS $Name" } else { Write-Host "FAIL $Name"; $script:fail++ } }
if ($WhatIf) {
    Write-Host 'WHATIF nothing was created; the check would read back:'
    Write-Host "  repo $full (public, discussions on)"
    Write-Host "  labels: $(($labels | ForEach-Object { $_[0] }) -join ', ')"
    Write-Host "  project '$ProjectTitle' (public, has Status and Release fields)"
    Write-Host "  discussion categories: Ideas, Q&A, Announcements, Show and tell"
}
else {
    $r = Read-Gh @('repo', 'view', $full, '--json', 'visibility,hasDiscussionsEnabled,hasIssuesEnabled') | ConvertFrom-Json
    Check "repo $full is public" ($r.visibility -eq 'PUBLIC')
    Check 'discussions enabled' ([bool]$r.hasDiscussionsEnabled)
    $have = (Read-Gh @('label', 'list', '--repo', $full, '--limit', '200', '--json', 'name') | ConvertFrom-Json).name
    foreach ($l in $labels) { Check "label $($l[0])" ($have -contains $l[0]) }
    $p = $null
    if (-not $script:projectFailed) { $p = (Read-Gh @('project', 'list', '--owner', $Org, '--format', 'json', '--limit', '100') | ConvertFrom-Json).projects | Where-Object { $_.title -eq $ProjectTitle } | Select-Object -First 1 }
    if ($script:projectFailed) { Write-Host 'SKIP project checks (manual step above)' } else { Check "project '$ProjectTitle'" ($null -ne $p) }
    if ($p) {
        Check 'project is public' ([bool]$p.public)
        $fields = (Read-Gh @('project', 'field-list', "$($p.number)", '--owner', $Org, '--format', 'json') | ConvertFrom-Json).fields.name
        Check 'project field Status' ($fields -contains 'Status')
        Check 'project field Release' ($fields -contains 'Release')
    }
    $q = 'query($o:String!,$r:String!){repository(owner:$o,name:$r){discussionCategories(first:20){nodes{name}}}}'
    $cats = (Read-Gh @('api', 'graphql', '-f', "query=$q", '-f', "o=$Org", '-f', "r=$Repo") | ConvertFrom-Json).data.repository.discussionCategories.nodes.name
    foreach ($c in 'Ideas', 'Q&A', 'Announcements', 'Show and tell') { Check "discussion category $c" ($cats -contains $c) }
}

Write-Host ''
Write-Host '--- manual steps (the API cannot do these) ---'
$i = 1; foreach ($m in $manual) { Write-Host "$i. $m"; $i++ }
if ($fail -gt 0) { Write-Host "$fail check(s) failed"; exit 1 }
