# Versioning and downstream upgrades

`codex-workflow` is an upstream workflow distribution. Target repositories vendor an exact snapshot of workflow-owned files and keep their own project-specific policy, code, experiments, and reports separate.

## Ownership model

Workflow-owned files are safe for the upstream installer to manage:

- `.codex/agents/*.toml`
- `.agents/skills/dev-orchestrator/**`
- `.agents/skills/ml-research-orchestrator/**` when the `ml-research` profile is installed
- `.codex/codex-workflow.config.example.toml`
- the marked workflow blocks inside `AGENTS.md`

Project-owned files are never overwritten by a normal upgrade:

- `.codex/config.toml`
- project-local skills such as `.agents/skills/<project-skill>/`
- source code, docs, configs, data manifests, tests, experiments, reports, and outputs
- any `AGENTS.md` content outside codex-workflow managed markers

Do not manually customize workflow-owned copies in a downstream repository. Put project-specific rules in the project's own Skill/AGENTS/docs instead.

## Lock and manifest

A successful install writes two files.

### `.codex-workflow.lock`

Lock format v2 records the upstream identity:

```yaml
lock_version: 2
workflow_repository: "https://github.com/example/codex-workflow.git"
workflow_version: "0.3.0"
workflow_commit: "<exact-commit>"
profile: "ml-research"
source_dirty: false
managed_manifest: ".codex-workflow.manifest"
```

The commit is the reproducibility anchor. `workflow_version` is human-readable metadata and does not replace the commit.

### `.codex-workflow.manifest`

The manifest records every workflow-owned file installed into the target and its SHA-256:

```text
# codex-workflow managed-file manifest v1
# path<TAB>sha256
.agents/skills/dev-orchestrator/SKILL.md    <hash>
...
```

Before upgrade, the installer compares the downstream copy against this manifest. Any local edit or deletion is treated as divergence and blocks overwrite.

## Bootstrap

Checkout the exact upstream revision you want to vendor:

```bash
git clone https://github.com/<owner>/codex-workflow.git
git clone https://github.com/<owner>/<target-project>.git

cd codex-workflow
git checkout <approved-commit>

bash scripts/install.sh ../<target-project> --profile ml-research
```

Commit the generated workflow snapshot, lock, and manifest in the target repository.

Do not install from an uncommitted upstream checkout. The installer refuses dirty sources by default because the lock commit would no longer describe the copied bytes.

## Upgrade

1. Update the local `codex-workflow` checkout.
2. Checkout the exact reviewed commit that should become the downstream version.
3. Run:

```bash
bash scripts/update.sh ../<target-project>
```

or equivalently:

```bash
bash scripts/install.sh ../<target-project> --upgrade
```

When `--profile` is omitted during upgrade, the existing downstream profile is retained.

To promote a core install to ML research:

```bash
bash scripts/update.sh ../<target-project> --profile ml-research
```

Automatic `ml-research -> core` downgrade is intentionally refused because removing research policy/skills is destructive and should be reviewed explicitly.

## Divergence handling

If a workflow-owned downstream file was locally edited, upgrade stops before overwriting it:

```text
error: locally modified workflow-owned files detected:
  .agents/skills/dev-orchestrator/SKILL.md
```

Preferred resolution:

1. move project-specific customizations into a project-owned Skill or `AGENTS.md` section;
2. restore the managed file to the previously installed version;
3. rerun upgrade.

If the local edit is disposable and upstream should win, use the explicit escape hatch:

```bash
bash scripts/update.sh ../<target-project> --force-managed
```

`--force-managed` only affects workflow-owned files. It does not overwrite project-owned `.codex/config.toml`, project skills, docs, experiments, or reports.

## Legacy lock migration

Installations created before lock v2 may have `.codex-workflow.lock` but no manifest.

During the first upgrade, the installer:

1. reads the recorded legacy `workflow_commit`;
2. reconstructs the old workflow-owned file set from Git history;
3. compares downstream files with the recorded old commit;
4. refuses migration if local divergence is detected;
5. upgrades and writes lock v2 + the managed manifest.

The old commit must be available in the local upstream clone. If it is missing (for example because of a shallow clone), fetch history before upgrading.

## AGENTS.md managed blocks

The installer only owns content between these markers:

```text
<!-- codex-workflow:start -->
...
<!-- codex-workflow:end -->
```

and, for ML research:

```text
<!-- codex-workflow:ml-research:start -->
...
<!-- codex-workflow:ml-research:end -->
```

Upgrade replaces those blocks in place and preserves all content outside them.

## Source cleanliness

By default install/upgrade refuses a dirty `codex-workflow` checkout.

For exceptional local testing only:

```bash
bash scripts/update.sh ../<target-project> --allow-dirty-source
```

The lock records `source_dirty: true`. A dirty-source installation should not be used as the reproducibility basis for formal experiments.

## Downstream release discipline

Recommended lifecycle:

```text
codex-workflow commit/release
        ↓
review exact upstream revision
        ↓
explicit install/upgrade
        ↓
target repo commits vendored snapshot + lock + manifest
        ↓
project experiments reference the target repo commit
```

Never make a downstream project follow `codex-workflow/main` dynamically. Explicit snapshot upgrades are the boundary between upstream workflow evolution and reproducible project research.
