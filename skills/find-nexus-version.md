# Find Nexus Version Origin

Given a vegapay-commons version, find which branch, commit, and GitHub Actions run pushed it to the nexus-snapshot or nexus-release repository.

## Input

The user will provide: **$ARGUMENTS**

This should be a version string like `7.9.1`, `8.1.1`, `102.0.0-SNAPSHOT`, etc.

If no version is provided, ask the user for the version before proceeding.

## Permissions

- This workflow is **READ-ONLY**. Do NOT make any changes to the repository, branches, or workflows.
- Only use read-safe git commands: `git log`, `git show`, `git branch`, `git merge-base`, `git diff` (read), `git remote`.
- Only use read-safe GitHub CLI commands: `gh api` (GET requests only), `gh run list`, `gh run view`.
- Do NOT use `gh run rerun`, `gh run cancel`, `gh run delete`, or any mutating GitHub API calls.
- Do NOT modify any files, create branches, or push anything.

## Workflow

### Step 0: Verify access prerequisites

Before doing anything else, verify that both git and GitHub CLI access are available. Run these checks in parallel:

**Check 1 — Git access:**
Run: git rev-parse --is-inside-work-tree
- If this fails, STOP and tell the user:
  > This command must be run from inside the `vegapay-commons` git repository.
  > Please `cd` into the repository directory and try again.

**Check 2 — Git remote access:**
Run: git ls-remote --heads origin 2>&1 | head -1
- If this fails with a permission/authentication error, STOP and tell the user:
  > Git remote access to `vegapay/vegapay-commons` is not available.
  > Please configure SSH or HTTPS access:
  >
  > **Option A — SSH (recommended):**
  > 1. Generate a key if you don't have one: ssh-keygen -t ed25519
  > 2. Add the public key to GitHub: GitHub → Settings → SSH and GPG keys → New SSH key
  > 3. Test: ssh -T git@github.com
  >
  > **Option B — HTTPS with token:**
  > 1. Create a PAT at GitHub → Settings → Developer settings → Personal access tokens
  > 2. Run: git remote set-url origin https://<TOKEN>@github.com/vegapay/vegapay-commons.git

**Check 3 — GitHub CLI installed:**
Run: which gh
- If `gh` is not found, STOP and tell the user:
  > GitHub CLI (`gh`) is not installed. It is required to query GitHub Actions runs.
  > Install it:
  > - macOS: brew install gh
  > - Linux: See https://github.com/cli/cli/blob/trunk/docs/install_linux.md
  > - Windows: winget install GitHub.cli

**Check 4 — GitHub CLI authenticated:**
Run: gh auth status
- If not authenticated, STOP and tell the user:
  > GitHub CLI is not authenticated. Please log in by running: gh auth login
  > Steps:
  > 1. Select GitHub.com
  > 2. Choose your preferred protocol (SSH or HTTPS)
  > 3. Authenticate via browser (recommended) or paste a token
  > 4. The token/login needs at least `repo` and `actions:read` scopes

**Check 5 — Repository API access:**
Run: gh api "repos/vegapay/vegapay-commons" --jq '.full_name' 2>&1
- If this returns an error or "Not Found", STOP and tell the user:
  > Your GitHub CLI session does not have access to the `vegapay/vegapay-commons` repository.
  > Ensure your account has read access to the repo, and that your token includes the `repo` scope.
  > Re-authenticate with: gh auth login

Only proceed to Step 1 if ALL checks pass. If multiple checks fail, report all failures together so the user can fix them in one go.

### Step 1: Determine version type

- If the version ends with `-SNAPSHOT`, the target repository is **nexus-snapshots** and the Maven profile is `develop`.
- If the version does NOT end with `-SNAPSHOT`, the target repository is **nexus-releases** and the Maven profile is `release`.

### Step 2: Find commits that set the version in pom.xml

Search for commits that introduced the version in `pom.xml` using:
Run: git log --all --oneline -S '<revision>VERSION</revision>' -- pom.xml

Replace `VERSION` with the user-provided version (e.g., `7.9.1` or `102.0.0-SNAPSHOT`).

For each matching commit, inspect the diff to confirm it **added** (not removed) the version in the correct profile:
- For releases: the `<id>release</id>` profile
- For snapshots: the default/develop profile

### Step 3: Identify the branch and commit

For each candidate commit from Step 2:
Run: git show COMMIT_HASH --format="%H %s%nAuthor: %an%nDate: %ad" --no-patch
Run: git branch --all --contains COMMIT_HASH

Note which branches contain each commit.

### Step 4: Find the GitHub Actions workflow run

The workflow that pushes to Nexus is `ci-cd.yml` (workflow name: "Build and Push vegapay-commons to Nexus"). The workflow ID is `130883274`.

Key logic from the workflow:
- It is triggered via `workflow_dispatch` with a `commons_branch` input.
- If `commons_branch` starts with `release/`, it deploys to **nexus-releases** using the `release` profile.
- Otherwise, it deploys to **nexus-snapshots** using the `develop` profile.

So:
- For **nexus-releases** versions: look for runs on `release/*` branches.
- For **nexus-snapshots** versions: look for runs on non-`release/*` branches.

Get the commit date from Step 3, then query workflow runs around that time:
Run: gh api "repos/vegapay/vegapay-commons/actions/workflows/130883274/runs?created=START_DATE..END_DATE&per_page=50" --jq '.workflow_runs[] | "\(.created_at) | \(.head_branch) | \(.head_sha) | \(.conclusion) | \(.html_url)"'

Use a date range of ~3 days around the commit date (e.g., if commit is Feb 11, search Feb 10..Feb 14).

### Step 5: Cross-reference and verify

For each candidate workflow run on a matching branch type (`release/*` for releases, non-`release/*` for snapshots):

1. Check if the run's commit SHA contains the version-setting commit:
   Run: git merge-base --is-ancestor VERSION_COMMIT RUN_COMMIT_SHA && echo "contains" || echo "no"

2. Verify the version in the run's commit pom.xml:
   Run: git show RUN_COMMIT_SHA:pom.xml | grep -A2 '<id>release</id>'    # for releases
   Run: git show RUN_COMMIT_SHA:pom.xml | grep -A5 '<activeByDefault>'   # for snapshots

3. Only consider runs with `conclusion: success`.

### Step 6: Report findings

Present the results in a clear format:

Version:    <version>
Repository: nexus-releases / nexus-snapshots
Branch:     <branch name>
Commit:     <SHA> - <commit message>
Author:     <author>
Date:       <date>
Run URL:    <GitHub Actions run URL>
Status:     success

If multiple matching runs are found (e.g., the same version was deployed from different branches), list all of them and note which was the **first** successful deployment.

If no matching run is found, report the commit and branch info from git history and suggest the user check the GitHub Actions UI manually (the run may have been deleted or the history may be beyond the API retention window).

## Troubleshooting

- If `gh` CLI is not authenticated, ask the user to run `gh auth login`.
- If the workflow ID `130883274` doesn't work, fetch it dynamically:
  Run: gh api "repos/vegapay/vegapay-commons/actions/workflows" --jq '.workflows[] | "\(.id) \(.name)"'
- If the version was never set in pom.xml (no commits found in Step 2), inform the user that this version may not exist in the repository history.