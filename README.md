<div align="center">

# Resume Tailor Agent

**A pure-Markdown playbook that turns any agentic LLM into a per-job résumé tailor — no fabrication, no AI filler, no servers, no glue code.**

[![License: MIT](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Playbook only](https://img.shields.io/badge/playbook-Markdown%20only-blue)](skills/)
[![No fabrication](https://img.shields.io/badge/policy-no%20fabrication-critical)](#non-negotiables)
[![ATS-safe output](https://img.shields.io/badge/output-ATS--safe%20PDF-lightgrey)](#)
[![Powered by open-ATS](https://img.shields.io/badge/powered%20by-open--ATS-orange)](https://github.com/NoahMustafa/open-ATS)

**[Try the underlying scorer in your browser →](https://open-ats-site.pages.dev/)** &nbsp;·&nbsp; **[CLI scorer source](https://github.com/NoahMustafa/open-ATS)**

A derivative of **[NoahMustafa/open-resume-agent](https://github.com/NoahMustafa/open-resume-agent)**, created and modified by **Fakhrul Hasan Bhuiyan**. MIT.

</div>

---

Drop a job description into chat. Get back a one-page, ATS-safe PDF tailored to it, plus a gap report telling you exactly which requirements your profile doesn't actually meet. The engine refuses to invent experience you don't have — if you're underqualified, it ships an honest score and tells you why, instead of stuffing buzzwords into a bullet.

The repo is plain Markdown playbooks + a LaTeX template. Your agent (Claude Code, OpenCode, Cursor, etc.) reads the playbooks and shells out to two bundled binaries (`tool` for ATS scoring, `tectonic` for LaTeX). One profile file is the source of truth for every résumé this engine ever produces.

---

## Quick start

```sh
# 1. Clone, then install the slash commands (once per machine):
git clone https://github.com/fbhuiyan2/resume-tailor-agent ~/soft/resume-tailor-agent
bash ~/soft/resume-tailor-agent/skills/install.sh

# 2. Then in chat, from ANY directory:
/resume-engine-setup    # one time per machine — fetches tool + tectonic
/profile-build          # one time per person — builds profile.json
/tailor                 # per job — paste JD or give a path
```

Three slash commands, one self-contained `SKILL.md` each. The installer copies them into `~/.claude/skills/`, which both Claude Code and OpenCode read, so they work from any directory. Full setup guide, including the OpenCode command shims: **[How-To-Setup.md](How-To-Setup.md)**.

---

## What you get per `/tailor` run

```
<output folder>/
├── resume.tex            # tailored LaTeX
├── resume.pdf            # compiled, ATS-safe, within the --pages budget
├── resume.md             # tool --md snapshot (structural verify oracle)
├── score.json            # ATS readiness + JD-match breakdown
├── jd.txt                # JD snapshot
├── jd.meta.json          # company, role, location, source
├── recommendations.md    # gap report (always) + cover letter & outreach (opt-in)
├── cover-letter.tex/.pdf # only when a letter was written
└── run.json              # selected modules, iteration history, what shipped + why
```

**Where it lands:** next to the JD file if you gave a path, otherwise `./resume-agent-output_{company}-{role}/` in the current directory. Set `output_root` in `inputs/paths.yaml` (or `$RESUME_TAILOR_OUT`) to force a single root, and the run goes to `{output_root}/{company-slug}/{role-slug}-{YYYYMMDD}/`. Never inside the engine repo.

Each ships only after passing an ATS structural verify and a coverable-gap check: anything the posting asks for that the profile genuinely supports must appear in the resume before it ships. The JD-match *score* is reported, never gated — a low one usually means the profile lacks the experience, and no rewrite fixes that honestly. When a gap can't be closed, the engine ships the best attempt and writes the unresolved gaps to `recommendations.md` rather than lying.

---

## Requirements

| | |
|---|---|
| Harness | Any agentic LLM tool with file + shell access (Claude Code, OpenCode, Cursor, Aider, etc.) |
| OS | Windows 10+ (x86_64), macOS (arm64), Linux (x86_64 / arm64). See [`skills/resume-engine-setup/SKILL.md`](skills/resume-engine-setup/SKILL.md) for the build-from-source path on other arches. |
| Disk | ~150 MB after `/resume-engine-setup` (`tool` + `tectonic` + LaTeX package cache) |
| Network | First `/resume-engine-setup` only (GitHub releases). Tectonic caches LaTeX packages on first compile, then offline. |
| Account | Optional. A GitHub username (read-only, unauthenticated) lets `/profile-build` scrape your public repos; it works without one. |

No Docker. No Node. No Bun. No Python. The two binaries are self-contained.

---

## Slash commands

### `/resume-engine-setup` — bootstrap binaries
Detects OS + arch, queries GitHub releases for latest stable `tool` (ATS scorer at [NoahMustafa/open-ATS](https://github.com/NoahMustafa/open-ATS)) and `tectonic` (LaTeX compiler), downloads with `curl`, verifies, gitignores. Idempotent.

Playbook: [`skills/resume-engine-setup/SKILL.md`](skills/resume-engine-setup/SKILL.md)

### `/profile-build` — build or update profile.json
Cold start: parses a CV (via `tool cv.pdf --md`), fetches your GitHub repos, asks which to include, asks clarifying questions only where ambiguous, writes `inputs/profile.json` (gitignored — it has personal data). Schema: [`profile.example.json`](profile.example.json). To keep the profile outside the repo so it syncs across machines, set `profile:` in `inputs/paths.yaml`.

Update mode: re-running adds and edits, never silent-deletes. Shows a diff, confirms once.

Inputs (all optional, all in `inputs/`, contents gitignored):
- `inputs/cv.pdf` or `inputs/cv.docx` — existing résumé
- `inputs/github_username.txt` — single-line GitHub handle (or asked at runtime)
- `inputs/notes.md` — free-form additions / corrections
- `inputs/resume-examples/` and `inputs/cover-letter-examples/` — previous documents of yours, read before each tailoring pass as **style** guidance (tone, section shape, bullet rhythm), never as a content source. PDF, DOCX, TXT, or MD.
- `inputs/paths.yaml` — optional per-machine path overrides; see `inputs/paths.example.yaml`

Playbook: [`skills/profile-build/SKILL.md`](skills/profile-build/SKILL.md)

### `/tailor` — JD → tailored PDF + recommendations
End-to-end per-job flow. Non-interactive except one optional question at the end (cover letter / outreach).

**JD intake — two ways:**
- **Paste** — drop the JD into chat between triple-backticks or quotes.
- **File path** — save it to a `.txt` anywhere (e.g. `inputs/jd.txt`) and give the path.

`/tailor` sniffs which one it got. The rest is automatic: module selection → tailoring pass → compile → structural verify → score → repair loop → recommendations → output folder.

Flags:
- `/tailor --pages N` — page budget (default 1). It also selects the layout when you don't name one: 1 page → `resume`, 2+ → `resume-2page`.
- `/tailor --template X` — layout to use. A name you configured in `resume_template`, a name in [`templates/`](templates/), or any path. Templates define their own sections and order — see [`templates/README.md`](templates/README.md).
- `/tailor --ref N` — how many references to print, for templates that have a References section (`resume-2page` does, `resume` does not). Default 1, the one flagged `"default": true` in the profile. `--ref 0` drops the section; `--ref N>1` asks which ones.
- `/tailor --cl-template X` — cover letter layout (default `cover-letter`).
- `/tailor --cl-pages N` — hard page cap for the cover letter. Unset by default; length follows the style examples in `inputs/cover-letter-examples/`.
- `/tailor --cl-only` — cover letter and outreach only, no resume. Note this path skips the ATS accept gate entirely.
- `/tailor --cover` — write cover letter + outreach unconditionally.
- `/tailor --no-cover` — skip the end-of-run ask.
- `/tailor --target 90` — raise the ATS-readiness floor (default 85). Formatting only; it does not raise the JD-fit bar, which is never gated.

> **The flags are optional.** `/tailor` is a playbook an agent reads, not a command parser, so plain language does the same work — and the two mix freely in one line.
>
> ```
> /tailor --pages 2 use the 2 page template
> /tailor two pages, research layout, no cover letter
> /tailor ~/jobs/alcf.txt keep it to one page and give me three references
> /tailor <paste JD> cover letter too, cap it at one page
> /tailor ~/jobs/alcf.txt cover letter only, no resume
> ```
>
> Layout names are matched against your `resume_template` map first, then against `templates/`. If a name is ambiguous or matches nothing, the agent asks and lists the options instead of quietly using the default — and it echoes what it resolved before writing anything: *"2 pages, layout `2page` (resume-2page-blue.tex.tmpl), 1 reference, cover letter on."*

Playbook: [`skills/tailor/SKILL.md`](skills/tailor/SKILL.md)

---

## Architecture

```
 ┌──────────────────────────────────┐
 │ User: copies JD from job site    │   any browser, no extension.
 │ → pastes into chat OR saves      │
 │   to a .txt file with the path   │
 └────────────────┬─────────────────┘
                  │
                  ▼
 ┌────────────────────────────────────────────────────────────┐
 │  HARNESS — any agentic LLM tool                             │
 │  (reads skills/*/SKILL.md, then:)                           │
 │    1. load profile.json (or run /profile-build first)       │
 │    2. read JD (path or raw text)                            │
 │    3. select relevant modules by tag overlap + LLM judgment │
 │    4. write resume.tex from templates/resume.tex.tmpl       │
 │    5. shell: tectonic resume.tex → resume.pdf               │
 │    6. shell: ./tool resume.pdf --md → structural verify     │
 │    7. shell: ./tool resume.pdf --jd jd.txt --json → score   │
 │    8. accept-gate? no → targeted edit → goto 5              │
 │    9. write recommendations.md (gap report + opt-in extras) │
 │   10. write the output folder (next to the JD, or ./…)      │
 └─────────────────────────────────────────────────────────────┘
```

No daemon. No background loop. One invocation per job.

**Why this shape:** the agent IS the engine. No glue code, no orchestration framework — the Markdown playbook is the program, the agent is the runtime. Same playbooks work in any harness.

---

## Repo layout

```
resume-tailor-agent/
├── README.md                  # this file
├── LICENSE                    # MIT
├── CONTRIBUTING.md            # how to contribute
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── TOOL-README.md             # bundled ATS scorer's own README
│
├── .github/
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.yml
│   │   ├── feature_request.yml
│   │   └── config.yml
│   └── PULL_REQUEST_TEMPLATE.md
│
├── How-To-Setup.md            # portable install: any directory, Claude Code + OpenCode
│
├── skills/                    # one self-contained SKILL.md per command
│   ├── tailor/SKILL.md
│   ├── profile-build/SKILL.md
│   ├── resume-engine-setup/SKILL.md
│   └── install.sh             # installs them into ~/.claude/skills/
│
├── templates/                 # example layouts — copy and edit, none is required
│   ├── README.md              # how to write your own + the ATS rules any template must follow
│   ├── resume.tex.tmpl        # default, one page, industry flavoured
│   ├── resume-2page.tex.tmpl  # longer form, research flavoured, References last
│   └── cover-letter.tex.tmpl  # moderncv cover letter
│
├── references/                # rules read by the tailoring pass
│   ├── verb-bank.md           # action verbs grouped by intent + banned openers
│   ├── blacklist.md           # humanizer ruleset (no AI filler, etc.)
│   └── writing-style.md       # prose voice: sentences, tense, acronyms, terminology
│
├── profile.example.json       # schema reference (checked in)
├── profile-config.example.md  # template for derived-mode profiles (see /profile-build)
├── job_description_template.txt   # sample JD shape
│
├── inputs/                    # everything personal (contents gitignored)
│   ├── profile.json           # YOUR profile — default location
│   ├── profile-config.md      # optional; switches /profile-build to derived mode
│   ├── paths.example.yaml     # copy to paths.yaml to point anything elsewhere
│   ├── resume-examples/       # drop previous resumes here — read as STYLE guidance
│   └── cover-letter-examples/ # same, for letters
├── tool[.exe]                 # fetched by /resume-engine-setup (gitignored)
└── tectonic[.exe]             # fetched by /resume-engine-setup (gitignored)
```

---

## Non-negotiables

1. **No fabrication.** Every claim on the PDF traces back to `profile.json`. If a JD demands experience that isn't in your profile, it goes to the gap report — never as a bullet.
2. **Accept gate.** PDF only ships after structural verify (sections and reading order derived from the chosen template, contact recoverable, within the `--pages` budget), zero ATS failures, and every profile-coverable JD gap closed. `overall` from the scorer is the ATS-readiness score, not a quality score; JD match is reported alongside it and is never a pass/fail bar. On honest stuck (provably profile-genuine gaps), the engine ships the best attempt + logs unresolved.
3. **Humanizer at write time.** Every line the user reads passes through [`references/blacklist.md`](references/blacklist.md) — no em-dash punctuation, no "leverage", no negative parallelism, no chatbot ceremony. Longer prose (cover letter, gap report) also follows [`references/writing-style.md`](references/writing-style.md).
4. **Profile = source of truth.** All résumé writing reads from `profile.json`. Stale profile → stale tailoring. Re-run `/profile-build` when you finish a new project.

---

## Sample run (real validation)

| Role tested | Field | ATS | JD match | Verdict |
|---|---|---|---|---|
| Junior Data Developer | tech, strong fit | 100/100 | 57/100 | ceiling = sector + startup-history gaps (gambling, US/UK startup) |
| Data Engineer (mid) | tech, strong fit | 100/100 | 72/100 | ceiling = Azure / AWS / LLM-RAG gaps |
| Data Quality Engineer | tech, niche stack | 100/100 | 77/100 | ceiling = Azure Databricks / PySpark / SAP gaps |
| Senior Data Engineer | tech, junior profile | 100/100 | 58/100 | flagged "don't apply at this level" in recommendations |
| Junior Accountant | non-tech, no fit | 100/100 | 45/100 | engine refused to fabricate; skills 57% on Excel/Power BI, requirements 28% on real financial work |

Scores scale with real qualification, not iteration count. ATS readiness is 100/100 on all of them — the formatting engine is solid regardless of fit.

External validation: a strong-fit run hit **100% on Jobscan**, **92% on MyCVCreator**. Our internal scorer is stricter than industry tools.

---

## Notes & gotchas

- **First-run install pulls ~150 MB.** Tectonic alone is ~50 MB; LaTeX package cache adds another ~50 MB on first compile.
- **Page budget is a hard block.** One page by default; raise it with `--pages N`. The engine will cut a project or tighten wording rather than spill over whatever budget is set. It never ships a resume that exceeds it.
- **Profile drives everything.** A thin profile produces a thin résumé. Spend time on `/profile-build` once; reap it on every job after.
- **No browser extension.** Earlier scope considered one for JD capture; killed it. Manual paste-or-file-path is simpler and avoids per-browser dev-mode installs + native messaging hosts for arbitrary disk paths.
- **Repair loop has no iteration cap.** It runs until the accept gate passes OR remaining gaps are provably profile-genuine, ranking iterations by JD fit once the document parses cleanly. Two consecutive iterations with the same score = stuck; ships best.
- **`tool --md` never overwrites.** Given a path that already exists it writes `resume-2.md` and returns 0. The playbook deletes the target first; if you script around the engine, do the same or you will re-read a stale extraction.
- **Justified text can lose its word boundaries.** Every template sets `\tolerance`, `\emergencystretch` and zeroes the interword shrink. Without that, a squeezed line extracts as `graphneuralnetworks,machine-learnedinteratomicpotentials` — perfect on screen, invisible to an ATS. Keep the block if you write your own template.
- **Hyphenation is switched off on purpose.** A word TeX breaks across a line keeps the hyphen in the extracted text — `configu-ration sampling`, `agen-tic` — so the keyword never matches the JD even though the PDF is right. `\hyphenpenalty` and `\exhyphenpenalty` are both set to 10000; removing either costs real JD points (measured: 60 → 63 from adding them).
- **Summary is capped at four rendered lines.** `\rsummary` measures itself and writes `SUMMARY-LINES: N` to the log, so the cap is checked, not eyeballed. Lines, not words — the same sentence wraps differently on a 1-page and a 2-page layout.
- **Test on the agent's tooling, not the engine.** If `/tailor` misbehaves, `skills/tailor/SKILL.md` is the source of truth — read it, then ask the harness to follow it more strictly.

---

## Contributing

PRs welcome — but read [CONTRIBUTING.md](CONTRIBUTING.md) first. The short version: this is a Markdown playbook system. Glue code, build steps, web UIs, and new external dependencies will be politely declined. The whole point is that the agent IS the engine.

Good first issues are labelled [`good first issue`](../../issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22) — usually playbook wording, verb-bank additions, doc fixes.

Security issues: see [SECURITY.md](SECURITY.md) — email, don't open a public issue.

Be a person: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

---

## Credits and license

This repository is a **derivative work** of [NoahMustafa/open-resume-agent](https://github.com/NoahMustafa/open-resume-agent) by Mahmoud Mustafa, released under the MIT License. It has been created and substantially modified by **Fakhrul Hasan Bhuiyan** and is maintained here independently; changes are not submitted upstream. The original copyright notice is retained in [LICENSE](LICENSE) as the MIT terms require.

It also uses [open-ATS](https://github.com/NoahMustafa/open-ATS), the same author's scorer, as a bundled binary.

The Markdown playbooks, templates, and references in this repo are [MIT-licensed](LICENSE): use them, fork them, change them. The two bundled binaries (`tool`, `tectonic`) are governed by their own licenses — see [TOOL-README.md](TOOL-README.md) and [tectonic-typesetting/tectonic](https://github.com/tectonic-typesetting/tectonic).

Contact: <fbhuiyan@anl.gov>.
