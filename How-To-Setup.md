# How to set up resume-tailor-agent

Makes `/tailor`, `/profile-build`, and `/resume-engine-setup` work **from any directory**, in **both Claude Code and OpenCode**, on any machine.

The README's quick start assumes you run the agent from the repo root. This document covers the portable setup instead: the playbooks stay in this repo, a thin skill layer in your home directory points at them, and your personal profile lives somewhere private.

---

## The shape of it

Four moving parts, deliberately kept separate:

| Part | Lives in | Why there |
|---|---|---|
| **Engine** — playbooks, templates, references, binaries | this repo | Public. Shareable. No personal data ever. |
| **Slash commands** — `/tailor`, `/profile-build`, `/resume-engine-setup` | this repo's `skills/`, installed to `~/.claude/skills/` | Generic logic, no personal data. Read by Claude Code AND OpenCode, from any directory. |
| **Profile** — your career record + generated `profile.json` | a **private** repo cloned into `~/.claude/skills/` | Data only, no logic. Never in the public engine repo. |
| **Outputs** — per-job resumes, letters, scores | next to the JD, else `./resume-agent-output_{company}-{role}/` | Lands where you are working. Never inside the engine repo. |

Why the split: `profile.json` holds your email, phone, and full career history. This repo is public. Committing the profile here publishes it.

---

## Why skills, not slash commands

Discovery paths differ between the two tools, and only one artifact type is shared:

| Location | Claude Code | OpenCode |
|---|---|---|
| `~/.claude/skills/<name>/SKILL.md` | ✅ any dir, invocable as `/name` | ✅ any dir (reads `~/.claude/skills` natively) |
| `~/.claude/commands/*.md` | ✅ any dir | ❌ not read |
| `~/.config/opencode/command/*.md` | ❌ not read | ✅ any dir |

So the real logic goes in a **skill** — written once, both tools see it. OpenCode surfaces skills through a `skill` tool that the agent picks by description, so if you want a literal `/tailor` keystroke there too, add the three-line command shims in step 4.

---

## Step 1 — clone the engine

```sh
git clone https://github.com/<you>/resume-tailor-agent ~/soft/resume-tailor-agent
```

Any path works — `install.sh` bakes the absolute path into the skills. Re-run the installer if you later move the repo.

## Step 2 — fetch the binaries

Per machine, since both are gitignored. From an agent session, run `/resume-engine-setup`, or do it by hand — Linux x86_64 shown, see [`skills/resume-engine-setup/SKILL.md`](skills/resume-engine-setup/SKILL.md) for other platforms:

```sh
cd ~/soft/resume-tailor-agent
curl -fL -o tool "https://github.com/NoahMustafa/open-ATS/releases/download/v0.2.0/tool-linux-x86_64"
chmod +x tool
curl -fL -o tectonic.tar.gz "https://github.com/tectonic-typesetting/tectonic/releases/download/tectonic@0.17.0/tectonic-0.17.0-x86_64-unknown-linux-musl.tar.gz"
tar -xzf tectonic.tar.gz && chmod +x tectonic && rm tectonic.tar.gz
./tool --version && ./tectonic --version
```

Check the releases pages for newer tags. Tectonic publishes sub-crate releases on the same page — only tags starting `tectonic@` ship the compiler.

First LaTeX compile downloads a package cache (~50 MB, one time). A slow first run is normal.

## Step 3 — install the slash commands

```sh
bash ~/soft/resume-tailor-agent/skills/install.sh
```

That copies the three skills into `~/.claude/skills/` and writes the OpenCode command shims. Idempotent — re-run after a `git pull` to pick up playbook changes.

What it installs:

```
~/.claude/skills/
├── tailor/SKILL.md
├── profile-build/SKILL.md
└── resume-engine-setup/SKILL.md

~/.config/opencode/command/
├── tailor.md
├── profile-build.md
└── resume-engine-setup.md
```

Each skill is self-contained: it resolves the engine path and the profile in its own §1, then carries the full procedure inline. No indirection, nothing to keep in sync.

Frontmatter must satisfy both tools: `name` (lowercase, hyphenated, **matching the directory name**) and `description` are required; unknown fields are ignored. Write the description specifically — it is how OpenCode decides whether to invoke the skill.

## Step 4 — what the shims are, if you want to write them by hand

Only needed for literal `/tailor` keystrokes in OpenCode; `install.sh` already writes them. Both `command/` and `commands/` are accepted; singular shown.

`~/.config/opencode/command/tailor.md`:

```markdown
---
description: Tailor a resume + cover letter to a job description (resume-tailor-agent)
---
Invoke the `tailor` skill and follow it exactly. Arguments: $ARGUMENTS
```

`~/.config/opencode/command/profile-build.md`:

```markdown
---
description: Build or update profile.json
---
Invoke the `profile-build` skill and follow it exactly. Arguments: $ARGUMENTS
```

`~/.config/opencode/command/resume-engine-setup.md`:

```markdown
---
description: Bootstrap the resume-tailor-agent binaries (open-ATS scorer + Tectonic)
---
Invoke the `resume-engine-setup` skill and follow it exactly. Arguments: $ARGUMENTS
```

Without these, OpenCode still works — you just say "tailor my resume to this JD" and the agent invokes the skill by description.

## Step 5 — environment variables (all optional)

Nothing is required. The skills resolve everything themselves:

- **Engine path** is baked in by `install.sh`. Re-run it if you move or re-clone the repo.
- **Profile** defaults to `inputs/profile.json`, which is gitignored. To keep it elsewhere — a private repo, a synced folder — set `profile:` in `inputs/paths.yaml`.
- **Output** is decided per run: next to the JD file if you gave a path, otherwise `./resume-agent-output_{company}-{role}/` in the current directory. Never inside the engine repo.

Override any of them only if you want to:

```sh
export RESUME_TAILOR_HOME="$HOME/soft/resume-tailor-agent"   # engine repo
export RESUME_TAILOR_PROFILE="/path/to/profile.json"       # skip discovery
export RESUME_TAILOR_OUT="$HOME/job-applications"          # fixed output root
```

## Step 5b — optional: style examples and path overrides

Drop previous resumes into `inputs/resume-examples/` and previous letters into `inputs/cover-letter-examples/`. PDFs work directly. Each tailoring run reads them for **style** — tone, section naming, bullet rhythm, level of detail — never for facts. Both directories ship empty and their contents are gitignored.

If you need to point the engine somewhere unusual, copy the config and edit it:

```sh
cp inputs/paths.example.yaml inputs/paths.yaml
```

Every key is optional; anything omitted falls back to discovery. The file is gitignored, so it is per-machine and does not travel with a clone.

## Step 6 — build your profile

Run `/profile-build`. Cold start parses a CV and scrapes GitHub per [`skills/profile-build/SKILL.md`](skills/profile-build/SKILL.md). If you already keep a structured career record as its own skill, derive `profile.json` from that instead — the record stays the source of truth and `profile.json` becomes a regenerable index.

Write it to the profile path, **not** into this repo.

### Derived mode — if you already keep a career record

If you maintain a richer record of your own (a CV plus notes), you do not have to retype it into `profile.json`. Add a `profile-config.md` describing that record — at `inputs/profile-config.md`, next to the profile, or wherever `profile_config:` in `inputs/paths.yaml` points — and `/profile-build` switches to **derived mode**: the record stays the source of truth, `profile.json` becomes a regenerable index of it.

Copy [`profile-config.example.md`](profile-config.example.md) as a starting point. It specifies the four sections the config needs: source files, record conventions, schema extensions, and tagging vocabulary.

---

## Setting up a second machine

```sh
git clone https://github.com/<you>/resume-tailor-agent ~/soft/resume-tailor-agent
git clone git@github.com:<you>/<your-private-profile-repo> ~/.claude/skills/<your-profile-skill>
bash ~/soft/resume-tailor-agent/skills/install.sh

cp ~/soft/resume-tailor-agent/inputs/paths.example.yaml \
   ~/soft/resume-tailor-agent/inputs/paths.yaml
# edit it: set `profile:` (and `profile_config:` if you use derived mode)
# to the paths inside the private repo you just cloned

# then in an agent session: /resume-engine-setup
```

Two things a clone does not carry, both by design:

- **`inputs/paths.yaml`** — `inputs/` is gitignored, so this never travels. It is the file that tells the engine your profile lives in the private repo rather than at the default `inputs/profile.json`. Skip it and `/tailor` will not find your profile.
- **The binaries** — fetched per machine by `/resume-engine-setup`.

Cloning the private repo into `~/.claude/skills/` is what makes it load as a skill in Claude Code and OpenCode. The resume engine itself does not care where it sits, as long as `paths.yaml` points at it — a symlink from `~/.claude/skills/` to a clone kept elsewhere works fine.

---

## Usage

| Command | What it does |
|---|---|
| `/tailor` | Paste a JD or give a path. One-page ATS resume + gap report. |
| `/tailor --pages 2` | Two pages, **and** the two-page layout. The page budget picks the layout when you don't name one. |
| `/tailor --template X` | Use layout `X` — a name from `resume_template` in `paths.yaml`, a name in `$ENGINE/templates/`, or any path. Templates define their own sections and order. |
| `/tailor --pages 2 --template 1page` | Both, when they disagree: a one-page layout with room to run to two. |
| `/tailor --ref N` | References printed, for templates that have the section. Default 1; `--ref 0` drops it; `N>1` asks which. |
| `/tailor --cl-template X` | Cover letter layout. Name in `templates/`, or any path. |
| `/tailor --cl-pages 1` | Cap the cover letter at N whole pages. Uncapped by default; no fractional budgets. |
| `/tailor --cl-only` | Cover letter + outreach only. No PDF, no compile, no scoring. |
| `/tailor --cover` | Write the cover letter unconditionally, skipping the end-of-run ask. |
| `/tailor --no-cover` | Gap report only. |
| `/tailor --target 90` | Raise the accept-gate score floor (default 85). |
| `/profile-build` | Rebuild `profile.json` after a new paper, project, or role. |
| `/resume-engine-setup` | Fetch or upgrade the binaries. |

Flags combine and are independent, with one deliberate exception: `--pages` also picks the default layout, so `--pages 2` on its own gives you the two-page layout rather than a stretched one-pager. Name a template explicitly to override that. `--template` alone picks a layout but still enforces one page.

### You don't have to use flags

`/tailor` is a playbook an agent reads, not a command parser. Plain language works, and mixes with flags:

```
/tailor --pages 2 use the 2 page template
/tailor two pages, research layout, no cover letter
/tailor <path/to/jd.txt> keep it to one page and give me three references
```

The agent resolves layout names against `resume_template` in `paths.yaml` first, then against `templates/`. If a name is ambiguous or matches nothing it asks and lists the options rather than quietly using the default, and it echoes the resolved settings before it starts writing.

### Naming your own layouts

`resume_template` in `paths.yaml` is a map, so layouts get names instead of paths you have to retype:

```yaml
resume_template:
  default:       "~/record/templates/resume-blue.tex.tmpl"   # used at 1 page
  default_2page: "~/record/templates/resume-2page-blue.tex.tmpl"   # used at 2+
  compact:       "compact"          # -> templates/compact.tex.tmpl
  bw:            "resume"           # the shipped black-and-white one
```

`default` and `default_2page` are the two reserved keys — they are what `--pages` selects between. Everything else is a name you can ask for. Leave the key out entirely and the same rule runs against the bundled layouts: `resume` at one page, `resume-2page` above.

The cover letter has no default length. It follows whatever `inputs/cover-letter-examples/` shows — a short industry letter or a long research-staff one organized by posting requirement — and only `--cl-pages N` imposes a hard cap.

Note that `--cl-only` skips the ATS accept gate entirely, so nothing on that path is scored or verified. It ships on the no-fabrication rule alone.

---

## Scope

This engine produces **resumes**, one or two pages, ATS-safe. It is not a CV generator — a full academic CV with a complete publication list has different conventions and no page ceiling, and the one/two-page gate here will fight you. Keep the CV in your own LaTeX and use this for resumes.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `/tailor` not offered | `SKILL.md` must be capitalized exactly; `name` must match the directory name; both `name` and `description` required. |
| Skill found, paths break | `RESUME_TAILOR_HOME` unset and the repo is not at the default path. |
| `TOOL MISSING` / `TECTONIC MISSING` | Binaries are gitignored — run `/resume-engine-setup` on this machine. |
| First compile hangs | Tectonic is downloading its package cache. One time, ~50 MB. |
| Personal data in `git status` | Something wrote into the engine repo. Outputs belong in `$RESUME_TAILOR_OUT`, the profile in the private repo. |
