# Analyze Merge Branches (Analyzer SOP)

**Purpose:** Analyse the bank branches of one or more services we intend to merge, and produce a single AI-friendly report describing exactly what stands between us and a safe merge — how many strategy flags are needed, where they go (file + line numbers), whether a `programId` is resolvable in each flow, and whether each service is merge-compatible.

**This SOP never merges anything. It only reads, analyses, and reports.**

This is the **Analyzer SOP**. A companion **Performer SOP** (created later) will do the actual code merge. This page operationalises **Phase 2 — The Code Merge** for the analysis pass only.

## Input

The user will provide: **$ARGUMENTS**

Expected format: `<service> <branch1> <branch2> ... [--base <base_branch>]`

Examples:
- `rewards-service bob/prod ybl/prod ssfb/prod unity/prod --base ssfb/prod`
- `program-service ybl/prod ssfb/prod`

## 0. Hard restrictions (mandatory — do not violate)

These are non-negotiable. Violating any of them can corrupt the real branches.

1. **Read-only.** Do **not** commit, push, merge, rebase, or modify any real branch. No `git merge` / `git rebase` / `git push` / `git commit` onto any branch the team uses.

2. **No approval pings for reading.** Reading files and running `git log`/`git diff`/`git show`/`grep` is always allowed without asking. **Only stop to ask the user when a write/update decision is required** — and this SOP has none, so run end-to-end without interrupting the user.

3. **Temporary branch is the only write allowed, and only if necessary.** Detecting incremental flow-conflicting drift sometimes needs a simulated merge. If and only if a static diff is insufficient, create a **throwaway local branch**, do a **local, non-pushed** trial merge to observe what would auto-introduce, capture findings, then **delete the temporary branch**. Never push it. Clean it up before the report is finalised (§6).

4. **Do not "fix" anything.** If you spot a bug or improvement, record it under `other` findings — never edit code.

5. **The report is the only output.** Each run writes a single `report.json` per service. The `index.html` viewer is reusable and is **not** regenerated per run.

If any step would require breaking a restriction to proceed, **stop and record the blocker in the report** instead of working around it.

## 1. Inputs

| Input | Description | Example |
|---|---|---|
| `services[]` | One or more service names / repo paths to analyse. | `rewards-service`, `program-service` |
| `branches[]` | The bank branches being merged for each service. | `bob/prod`, `ybl/prod`, `ssfb/prod`, `unity/prod` |
| `base_branch` | (Optional) Intended merge base. If omitted, pick the most actively maintained branch and record the choice. | `ssfb/prod` |

If a service lacks one of the named branches, record it as a **skip** in that service's report block and continue.

## 2. Phase 1 — Analyse the entire branch

Build the raw picture of how branches differ, per service, **before** classifying anything.

1. **Locate the repo** and confirm all requested branches exist (`git branch -a`). Record missing branches as skips.
2. **Establish merge bases** between the base branch and every other branch (`git merge-base base other`).
3. **Enumerate drift** — for every pair `(base, other)`: `git diff --name-status base...other`, then for each changed file capture the changed function/method names and their **line ranges** on each branch.
4. **Index every function present on more than one branch** — these are the merge-risk candidates. Note function name, file path, and line range per branch.
5. Record the raw inventory. Nothing is classified yet; Phases 2–4 classify it.

Line numbers are mandatory everywhere. The report is meant to be manually verified — a reviewer should be able to open the exact file at the exact line and see what the SOP saw.

## 3. Phase 2 — Incremental flow-conflicting changes → flags

The **dangerous, silent** case: a function grew an extra behavioural step on one branch (a new notification/LOS/recon call) that a direct merge would leak onto the other banks **with no merge conflict**.

1. Compare branch bodies of each multi-branch function. Identify **added behavioural calls** present on some branches but not others. Per the bloom-filter rule (§7), if there is even a small chance an addition is behavioural, surface it with a low `break_probability` rather than discarding it.
2. If a behavioural step would auto-introduce across banks on merge, it **requires a flag** so each bank keeps its real behaviour.
3. **Define a flag name** (do not implement it) per §5, and record it with the **exact file, fully-qualified class + function + signature, per-branch line ranges, a snippet**, plus `break_probability`, `probable`, and a defaulted `keep`.
4. **Count** the incremental flow-conflicting flags for the service.

If a static diff can't conclusively show whether a step auto-introduces, use the **temporary trial-merge** (§0.3 + §6), then delete the temp branch. Each finding becomes a `category: "incremental_flow_conflicting"` flag.

## 4. Phase 3 — Divergent changes → flags

Divergent changes surface as real merge conflicts, so they're easier to find — but each still needs a strategy + flag. **Both** sub-types produce flags.

### 4.1 Sequence-based

Same steps, different order per bank (e.g. SSFB `A→B→C`, Unity `B→A→C`, YBL `C→B→A`). Record one **per-client strategy flag**. Capture the exact file, class + function + signature, per-branch line ranges, and the observed sequence per branch. → `category: "divergent_sequence"`.

### 4.2 Non-sequence-based

Entirely different implementation under the same function name. Record one **per-client strategy flag** per diverging branch, with the exact file, class + function + signature, per-branch line ranges, and a note on how the approaches differ. → `category: "divergent_non_sequence"`.

**Count** sequence flags and non-sequence flags separately.

## 5. Flag naming convention

Name flags deterministically so the same finding always yields the same flag name. Do **not** create or wire flags — only name them in the report.

`<service>_<function>_<discriminator>_<scope>`

| Category | Pattern | Example |
|---|---|---|
| Incremental flow-conflicting | `<service>_<function>_<feature>_enabled` | `rewards_createOrder_notification_enabled` |
| Divergent — sequence | `<service>_<function>_<client>_seq_strategy` | `rewards_createOrder_unity_seq_strategy` |
| Divergent — non-sequence | `<service>_<function>_<client>_strategy` | `rewards_createOrder_ybl_strategy` |
| Other (necessary, outside the above) | `<service>_<area>_<purpose>_flag` | `rewards_reward_accrual_idempotency_flag` |

Rule: **every strategy gets its own flag.** This keeps consolidation reversible — re-point Unity at `SsfbStrategy`, validate, then retire the redundant flag/strategy.

## 6. Phase 4 — Identifier presence check (programId resolvability)

The strategy switch is keyed on a `programId`, derived from `accountId`/`transactionId` and stored in a ThreadLocal. For every flow that needs a flag (Phases 2–4), confirm the switch can actually be keyed.

For each entrypoint (**controller endpoint** or **consumer/listener**) that reaches a flagged function:

1. **Trace from the entrypoint inward** — controller method or consumer handler — through the call chain to the flagged function.
2. Check whether **any** of `accountId`, `transactionId`, or `programId` appears anywhere in that flow.
3. Record, with **file + line number** of the entrypoint and of the first place each identifier appears: `has_programId`, `has_accountId`, `has_transactionId`, and `resolvable_to_programId`.
4. **If none of the three is present in the whole flow**, record it under `complications` with entrypoint, file, line numbers, and impact.

### Temporary-branch protocol (only if Phase 2 or 4 truly needs it)

```bash
git switch -c _tmp_analysis_<service>_<ts> <base_branch>  # local only
git merge --no-commit --no-ff <other_branch>               # observe; do NOT commit
# ...read the working tree / record findings...
git merge --abort                                           # discard
git switch <base_branch>
git branch -D _tmp_analysis_<service>_<ts>                 # delete temp branch
```

Never `git push`. Confirm `git branch` shows no `_tmp_analysis_*` left before finalising the report.

## 7. Phase 5 — The report (`report.json` per service; one shared `index.html`)

**Each run writes exactly one file per service:** `report.json`. It is the canonical, machine-readable artifact and the **only file fed to** `performer-sop.md`.

**Output layout:**

```
codemerge-v2-reports/
├── index.html          <- the reusable viewer (created ONCE; never regenerated)
├── manifest.json       <- lists the service folders (analyzer appends/updates this)
├── chronos/
│   └── report.json
├── rewards-service/
│   └── report.json
└── <service>/
    └── report.json
```

**Do NOT regenerate** `index.html` **on every run.** The analyzer's only obligations: (a) write `report.json` into the service's subfolder, (b) keep it schema-compatible (§7.4), and (c) list the service in `manifest.json`.

### 7.0 Bloom-filter principle — over-report on purpose (no false negatives)

This analyzer behaves like a **bloom filter: it must never produce a false negative.** If there is **even a 1% chance** a change could alter or break a bank's flow on a naive merge, it **must be reported**.

- Every flag carries `break_probability` (0.0–1.0). **Report any candidate with** `break_probability >= 0.01`.
- Every flag carries a `probable` enum: `LIKELY_REAL`, `UNCERTAIN`, `LIKELY_FALSE_POSITIVE`.
- Every flag carries a `keep` boolean and a `resolution` (§7.5). `performer-sop` **wires only flags where** `keep == true` **and** `resolution == ADD_FLAG`.

`merge_compatible` = `true` only when there are **zero kept** incremental flow-conflicting **and** zero kept divergent findings.

### 7.1 `report.json` schema

```json
{
  "sop": "phase2-branch-analysis-readonly",
  "version": "1.1",
  "scope": {
    "services": ["rewards-service"],
    "branches": ["bob/prod","ybl/prod","ssfb/prod","unity/prod"],
    "base_branch": "ssfb/prod"
  },
  "resolution_values": ["ADD_FLAG","PREFER_BRANCH","UNION_ALL","ASK_AT_MERGE","MANUAL_EDIT","DROP"],
  "services": [
    {
      "service": "rewards-service",
      "branches_analyzed": ["bob/prod","ybl/prod","ssfb/prod","unity/prod"],
      "merge_compatible": false,
      "program_id": {
        "status": "partial",
        "flows_missing_identifier": 1
      },
      "summary": {
        "total_flags": 4,
        "incremental_flow_conflicting": 1,
        "divergent_sequence": 2,
        "divergent_non_sequence": 0,
        "other": 1,
        "merge_directives": 1
      },
      "flags_by_bank": {
        "ssfb/prod": { "incremental_flow_conflicting": 1, "divergent_sequence": 1, "divergent_non_sequence": 0, "other": 0, "total": 2 },
        "unity/prod": { "incremental_flow_conflicting": 1, "divergent_sequence": 1, "divergent_non_sequence": 0, "other": 0, "total": 2 },
        "ybl/prod":   { "incremental_flow_conflicting": 0, "divergent_sequence": 0, "divergent_non_sequence": 0, "other": 0, "total": 0 },
        "bob/prod":   { "incremental_flow_conflicting": 0, "divergent_sequence": 0, "divergent_non_sequence": 0, "other": 1, "total": 1 }
      },
      "flags": [
        {
          "flag_name": "rewards_createOrder_notification_enabled",
          "category": "incremental_flow_conflicting",
          "banks": ["ssfb/prod","unity/prod"],
          "break_probability": 0.85,
          "probable": "LIKELY_REAL",
          "keep": true,
          "resolution": "ADD_FLAG",
          "prefer_branch": null,
          "comment": "",
          "class": "tech.vegapay.rewards.OrderService",
          "function": "createOrder",
          "function_signature": "public OrderResponse createOrder(OrderRequest request)",
          "file": "src/main/java/tech/vegapay/rewards/OrderService.java",
          "locations": [
            { "branch": "ssfb/prod", "file": "src/main/java/tech/vegapay/rewards/OrderService.java", "lines": "120-145", "snippet": "notificationClient.send(buildOrderNotification(order));" },
            { "branch": "unity/prod", "file": "src/main/java/tech/vegapay/rewards/OrderService.java", "lines": "118-130", "snippet": "// no notification call present" }
          ],
          "branches_involved": ["ssfb/prod","unity/prod"],
          "proposed_strategies": ["SsfbStrategy","UnityStrategy"],
          "description": "SSFB added a notification call inside createOrder; a direct merge would silently enable it on Unity.",
          "verify": "Confirm the notification call exists only on SSFB. If both/neither, set keep=false."
        }
      ],
      "identifier_presence": [
        {
          "entrypoint": "OrderController.createOrder",
          "type": "controller",
          "file": "...OrderController.java",
          "line": 42,
          "has_accountId": true,
          "has_transactionId": false,
          "has_programId": false,
          "resolvable_to_programId": true,
          "notes": "accountId@L48; resolver derives programId."
        }
      ],
      "complications": [
        {
          "entrypoint": "ReconConsumer.onMessage",
          "type": "consumer",
          "file": "...ReconConsumer.java",
          "lines": "30-77",
          "issue": "No accountId/transactionId/programId in the flow.",
          "impact": "Switch cannot be keyed here; needs manual handling."
        }
      ],
      "other_flags": [
        {
          "flag_name": "rewards_reward_accrual_idempotency_flag",
          "category": "other",
          "banks": ["bob/prod"],
          "break_probability": 0.40,
          "probable": "UNCERTAIN",
          "keep": true,
          "resolution": "ADD_FLAG",
          "prefer_branch": null,
          "comment": "",
          "class": "tech.vegapay.rewards.AccrualService",
          "function": "accrueRewards",
          "function_signature": "void accrueRewards(String accountId, long amount)",
          "reason": "Differing retry/idempotency guard.",
          "file": "...AccrualService.java",
          "lines": "201-240"
        }
      ],
      "temp_branch_used": false
    }
  ],
  "restrictions_verified": {
    "no_writes_to_real_branches": true,
    "temp_branches_deleted": true
  }
}
```

### 7.2 Resolution values — not everything is a flag

| `resolution` | Means | Flag? | What `performer-sop` does |
|---|---|---|---|
| `ADD_FLAG` (default) | Real per-bank behavioural divergence | **Yes** | Create the strategy/policy flag and wire the per-bank switch. |
| `PREFER_BRANCH` | Minor divergence; one branch's version wins | No | Take `prefer_branch`'s version for all banks. |
| `UNION_ALL` | Each branch has a different subset; combine | No | Merge all branches' additions into one. |
| `ASK_AT_MERGE` | Dev wants to be asked at merge time | No | Pause and ask the dev, using `comment` as context. |
| `MANUAL_EDIT` | Dev will hand-edit; don't flag | No | Surface as a manual step with `comment`. |
| `DROP` | False positive | No | Ignore (equivalent to `keep=false`). |

Counting rule: **only** `keep && resolution == ADD_FLAG` count as flags; the rest go to `summary.merge_directives`.

### 7.3 Per-bank flag attribution

- **Divergent — sequence / non-sequence:** per-client; counts only for the bank whose strategy it gates.
- **Incremental flow-conflicting:** attribute to **every bank that must set it to a non-default value**.
- **Other:** counts under whichever bank(s) the flag applies to.

Counts include only flags where `keep == true` and `resolution == ADD_FLAG`.

### 7.4 `manifest.json` format

```json
{
  "title": "Code Merge v2 — Branch Analysis Reports",
  "report_file": "report.json",
  "reports": [
    { "service": "chronos", "path": "chronos/report.json" },
    { "service": "rewards-service", "path": "rewards-service/report.json" }
  ]
}
```

## 8. Run checklist

Before finalising the report, verify every item:

- [ ] Inputs captured (`services[]`, `branches[]`, `base_branch`)
- [ ] Phase 1 inventory built per service (functions on >1 branch, with line ranges)
- [ ] Phase 2 incremental flow-conflicting flags named + counted (exact file, class/function/signature, per-branch lines, snippet)
- [ ] Phase 3 divergent sequence + non-sequence flags named + counted
- [ ] Phase 4 identifier check done per flagged entrypoint; missing-identifier flows recorded as complications
- [ ] `other` necessary flags captured (with file + function detail)
- [ ] Bloom-filter rule applied — every candidate with `break_probability >= 0.01` reported
- [ ] Every flag has `break_probability`, `probable`, a defaulted `keep`, a `resolution`, and a `comment` field
- [ ] Non-flag merge directives captured under `summary.merge_directives`
- [ ] `merge_compatible` set correctly per service
- [ ] Per-bank flag tally (`flags_by_bank`) produced — ADD_FLAG kept only
- [ ] Every flag is independently verifiable (file + class/function/signature + per-branch lines + snippet + `verify`)
- [ ] Any temporary branch deleted; `git branch` confirms no `_tmp_analysis_*` present
- [ ] `report.json` written to `codemerge-v2-reports/<service>/report.json`; service listed in `manifest.json`; `index.html` NOT regenerated
- [ ] No real branch was written to

## 9. Hand-off — what the dev must do with this report

The analyzer's report is a **first pass, not ground truth.** It deliberately over-reports (bloom filter). Before it can drive a merge, a developer must harden it.

**The dev's job — verify, prune, and decide a resolution.** For every finding:

1. Open `index.html`, pick the service in the sidebar, sort by **break %**, and use the eye control to jump to the cited file + per-branch lines + snippet, on **every branch of every bank** involved.
2. **Triage each kept finding:**
   - False positive → `keep = false`
   - Real, needs a switch → leave `resolution = ADD_FLAG`
   - Real, but no flag → set `resolution` (`PREFER_BRANCH`, `UNION_ALL`, `ASK_AT_MERGE`, or `MANUAL_EDIT`) and write a `comment`
3. Click **"Export pruned `report.json`"**. That exported file is the input to `performer-sop.md`.

**Scope boundary:** The dev owns the **correctness of what the report contains**, not the **completeness of what it might have missed.** Missed incremental flow-conflicting flags are out of dev scope — they are silent and effectively impossible to track exhaustively by hand.

Net effect: the analyzer maximises **recall** (bloom filter); the dev maximises **precision** (prune via `keep`, route survivors via `resolution`).
