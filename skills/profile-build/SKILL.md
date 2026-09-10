---
name: profile-build
description: Build or update profile.json, the structured source of truth the resume engine reads when tailoring. Use when the user asks to build, refresh, regenerate, or correct their resume profile, after they finish a new project, paper, or role that should appear on future resumes, or when /tailor halts because the profile is missing or stale.
---

# /profile-build — build or update profile.json

`profile.json` is the tag-indexed view the tailoring engine reads. Depending on setup it is either the source of truth itself, or a **derived index** of a richer record kept elsewhere.

## 1. Resolve paths

**Engine root.** `install.sh` rewrites this to an absolute path at install time. If it still reads `__ENGINE_PATH__`, the skill was copied by hand — fall back to `$RESUME_TAILOR_HOME`, then `$HOME/soft/resume-tailor-agent`.

```bash
ENGINE="__ENGINE_PATH__"
```

**Profile destination.** Resolve in this order:

1. **`$ENGINE/inputs/paths.yaml`**, if it exists — a non-empty `profile:` key is the destination, and a non-empty `profile_config:` key is the record config. Use this when the profile belongs somewhere other than the engine repo: a private record, a synced folder, a second machine's clone.
2. **`$ENGINE/inputs/profile.json`** — the default. `inputs/` is gitignored, so the profile stays private.

`$RESUME_TAILOR_PROFILE`, if set, overrides both.

**Mode.** Look for `profile-config.md`: at the `profile_config:` path if `paths.yaml` names one, otherwise beside the resolved profile.

- Found → **derived mode**. `RECORD` is that file's directory, `CONFIG` is the file.
- Not found → **standalone mode**.

**Announce the resolved destination before doing any work**, so the user can redirect it before a file appears somewhere they did not expect:

```
Mode:    derived (or: standalone)
Config:  <path to profile-config.md, or "none — standalone mode">
Writing: <absolute path to profile.json>
```

## 2. Pick the mode

**Derived mode** — a `profile-config.md` was found. The user keeps a richer career record and `profile.json` is generated from it. **Read the config and follow it.** It names the record's files, its conventions, any schema extensions, and the tagging vocabulary, and overrides the defaults below wherever they disagree.

In this mode `profile.json` is generated, never hand-edited. Adding a fact means editing the record and regenerating; otherwise the two drift and the resume starts citing things the record does not contain.

If a user wants derived mode but has no config yet, point them at `$ENGINE/profile-config.example.md` — it is the template and specifies the four sections. It can sit beside the profile, or anywhere `paths.yaml` points.

**Standalone mode** — no config found. Follow the appendix below: parse a CV from `inputs/`, fetch GitHub repos, ask where ambiguous, write the profile. Schema reference is `$ENGINE/profile.example.json`.

The profile lands at `$ENGINE/inputs/profile.json`. `inputs/` is gitignored, so it stays private — but that also means **it does not travel with a clone.** Mention this once, after writing, without labouring it:

> Your profile is at `<path>`. `inputs/` is gitignored, so it stays on this machine — fine for one computer, but it will not follow you to another. To keep it somewhere that syncs, put it in a repo of your own and point `profile:` in `inputs/paths.yaml` at it. And if you already keep a CV and notes you would rather not retype, add a `profile-config.md` describing that record and re-run — `/profile-build` switches to derived mode and regenerates the profile from it instead. Templates: `$ENGINE/inputs/paths.example.yaml`, `$ENGINE/profile-config.example.md`.

Say it once. Do not repeat it on later runs in the same session.

## 3. Cold start vs update

- **Cold start** — no `profile.json`. Build from scratch.
- **Update** — it exists. Regenerate, then diff against the old file and show the user what changed before writing. Never silent-delete.

## 4. Tagging quality

The engine's module prefilter is tag-overlap, so weak tags mean weak module selection. This is the single biggest lever on output quality. Tag every bullet, project, and publication along whatever axes the record uses (derived mode: `$CONFIG` defines them), and always include **transferable** tags alongside specialist ones.

Specialist terms rarely appear in job postings verbatim. A posting says "molecular simulation", "ML for science", or "distributed computing" where a record says `ReaxFF`, `MLIP`, or `Parsl`. Without the transferable tags, a relevant posting prefilters to nothing.

## 5. Honest depth

Where the record calibrates how deep a skill actually goes, carry that into a `depth` field (`expert` | `working` | `familiar`). The tailoring pass must not present a `familiar` skill as a headline strength. This is the no-fabrication rule applied at the skills line.

## 6. References

Collect referees into `profile.references[]`. Each entry:

```json
{ "name": "", "title": "", "department": "", "organization": "",
  "email": "", "phone": "", "relationship": "", "default": false }
```

Sources, in order: an existing References section in the CV or record; `inputs/notes.md`; then ask. In derived mode the record's own conventions win, including which referees are currently active — a referee commented out in the record is deliberately inactive, so leave it out and mention that you saw it.

**Ask which one is the default.** Exactly one entry gets `"default": true`. That is the single reference `/tailor` prints under its default `--ref 1`, so it is a real choice and the user has to make it. Ask once, listing the collected names, after you have the full list. Never guess by ordering.

Never invent a referee, a title, or an email address. A wrong address here reaches a real person. If the CV shows a name but no email, leave `email` empty and say so rather than reconstructing one from a pattern.

If the user has no references to give, write `"references": []` and move on. `/tailor --ref 0` and templates without a References section both work fine without it.

## 7. Write and report

Write `$PROFILE` — the exact path announced in §1. Print counts per section, then batch any judgment calls into one set of questions at the end, not one at a time during the build.

If the destination already existed, show the diff and confirm before writing (§3).

---

# Appendix — standalone-mode playbook

Follow this only in standalone mode (§2). Derived mode follows the record's `profile-config.md` instead.

`$PROFILE` is the engine's source of truth. Everything the résumé can ever say lives there. This playbook builds it once from CV + GitHub + your input, and updates it on later runs.

**Pre-req:** `/resume-engine-setup` has run (`"$ENGINE/tool"` exists at repo root) — needed only to parse a CV. If no CV is being parsed, `tool` is not required.

---

## Modes

- **Cold start** — `$PROFILE` does NOT exist at repo root. Build from scratch.
- **Update** — `$PROFILE` exists. Additive merge; never silent-delete.

Decide by `test -f profile.json`.

## Inputs (all optional, all in `inputs/`, all gitignored)

| File | Purpose |
|---|---|
| `inputs/cv.pdf` or `inputs/cv.docx` | Existing résumé to parse. |
| `inputs/github_username.txt` | One line, just the username. |
| `inputs/notes.md` | Freeform context — anything the CV doesn't say. |

User drops files here. None mandatory, but at least one strongly recommended for cold start.

---

## Flow

### 1. Load existing or empty profile

- Cold start → start with empty schema (see `profile.example.json` for shape).
- Update → load `$PROFILE`. Keep every existing field unless explicit user instruction to remove. Already-decided per-repo include/exclude flags carry over so the agent doesn't re-ask.

### 2. Parse CV if present

```
"$ENGINE/tool" inputs/cv.pdf --md inputs/cv.md
```

Read `inputs/cv.md`. Extract:
- `identity` (name, location, contact links).
- `summary_seeds` — raw factual statements, NOT a pre-written summary.
- `skills` (languages, frameworks, tools, domains).
- `experience` (company, title, dates, bullets — keep bullets verbatim, mark any with concrete numbers in `metric`).
- `projects`, `education`, `certifications`.

If CV is genuinely ambiguous about something (e.g., dates say "Recent"), ask — don't guess.

### 3. GitHub fetch if username present

```
curl -fsSL "https://api.github.com/users/<USERNAME>/repos?per_page=100&sort=updated&type=owner"
```

Unauthenticated. 60 req/hr is plenty — one user-repos call is one request. If rate-limited, halt with "wait until <X-RateLimit-Reset>" + re-run hint.

Skip forks (`fork: true`) by default. For each remaining repo:

- Read `name`, `description`, `language`, `stargazers_count`, `html_url`, `topics`.
- If update mode and this repo already has `enrichment.github.repos[name].included` set → skip the question, honor the prior decision.
- Else ask: `Include "<name>" — <description>? [Y/n] (glob: "skip-pattern" to blanket-skip)`. Default Y. A glob answer (e.g., `experiments-*`) excludes all matching repos at once and is remembered.
- Included + substantial repos (has README, > N lines, or user-flagged) → add to `projects[]`. All repos (included or not) recorded in `enrichment.github.repos[]` with their `included` flag.

### 4. Read notes.md

Freeform. Treat as ground truth for anything CV missed. User's word > parser's guess.

### 4b. References

Parse a References section out of the CV if one exists. Record name, title, department, organization, and email into `references[]`. Then ask which is the default (§6). Do not fabricate missing emails.

### 5. Ask clarifying questions — only on genuine gaps

NO interrogation. Skip every question you can answer from inputs. Ask only when something is missing AND the résumé needs it. Examples worth asking:

- Missing contact field the CV shows in a non-text logo (`linkedin.com/in/...`).
- Date ambiguity ("Recent", "current" without context).
- Work auth — include or omit (depends on market).
- Target domains — which tags should weigh higher in `/tailor` relevance selection (data / backend / frontend / devops / security / ml ...).

### 6. Derive tags

Every `skills[].*`, `experience[].bullets[]`, `projects[].bullets[]` gets a `tags: []` array. Tags = lowercase keywords lifted from the text (`python`, `etl`, `kafka`, `react`, `terraform`). Hand-editable later. These drive relevance selection in `/tailor`.

### 7. Diff + confirm

- **Update mode:** print a unified diff of `$PROFILE` (old vs new). Ask `apply? [Y/n]`. On Y, write file. On n, abort — no partial writes.
- **Cold start:** print compact summary of proposed profile (counts per section + identity). Ask `write profile.json? [Y/n]`.

### 8. Write

Pretty-printed JSON, 2-space indent, sorted top-level keys per schema order (see `profile.example.json`, which now includes `references[]`).

Set `meta.last_updated` to current ISO8601. Set `meta.source` to `"cv"`, `"github"`, `"manual"`, or comma-joined for hybrids.

---

## Non-negotiables

- **No fabrication.** If CV unclear → ask, don't guess. If GitHub repo description is empty, leave it empty, don't invent.
- **No silent delete.** Update mode keeps anything not explicitly removed. Even unused tags stay.
- **Profile is local.** `$PROFILE` is gitignored. Never logged outside the repo. Never sent anywhere except as context the LLM sees in this session.

## Failure modes

- **Tool can't parse CV** → halt with: "Open `inputs/cv.md` (if exists) or `inputs/cv.<ext>`, manually paste a cleaned plain-text version to `inputs/cv.md`, re-run."
- **GitHub rate-limited** → halt, print reset time, suggest re-run later.
- **Network down** → cold-start still proceeds with CV + notes only; mark `meta.source` accordingly.
- **No inputs at all** → halt with: "Drop a CV in `inputs/cv.pdf` and/or a GitHub username in `inputs/github_username.txt`, then re-run."

## Schema reference

See `profile.example.json` for the exact shape. Spec §5.1 has the prose description (in dev workspace, gitignored from production repo).
