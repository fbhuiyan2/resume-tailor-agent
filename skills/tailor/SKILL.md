---
name: tailor
description: Tailor a resume (and optionally a cover letter) to a specific job description, producing an ATS-scored PDF plus a gap report. Use when the user supplies a job posting and wants a resume targeted at it, asks to "tailor my resume", requests a cover letter for a named role, or passes flags like --pages, --template, --cl-only, --cover, or --target. Runs the resume-tailor-agent engine end to end.
---

# /tailor — job description in, tailored resume + cover letter out

Runs the resume-tailor-agent engine. The authoritative playbook lives in the engine repo; this skill resolves paths so the flow works from ANY directory, adds the `--pages`, `--template`, and `--cl-only` flags, and then hands off.

## 1. Resolve paths (do this first, every run)

**Engine root.** `install.sh` rewrites the line below to the absolute path at install time. If it still reads `__ENGINE_PATH__`, the skill was copied by hand — fall back to `$RESUME_TAILOR_HOME`, then `$HOME/soft/resume-tailor-agent`.

```bash
ENGINE="__ENGINE_PATH__"
test -x "$ENGINE/tool"     || echo "TOOL MISSING - run /resume-engine-setup"
test -x "$ENGINE/tectonic" || echo "TECTONIC MISSING - run /resume-engine-setup"
```

**Profile.** Two locations, in this order:

1. **`inputs/paths.yaml`** — if it exists and its `profile` key is non-empty, that path is the profile. Its `profile_config` key names the derived-mode config the same way. This is how a profile kept outside the repo (a private record, a synced folder) is found.
2. **`$ENGINE/inputs/profile.json`** — the default. `/profile-build` writes here unless told otherwise.

If neither resolves → halt: "No profile found. Run `/profile-build` first." If `$ENGINE/profile.json` exists at the repo root, add: "Found a profile at the old repo-root location; move it to `inputs/profile.json` or point `profile:` at it in `inputs/paths.yaml`."

`$RESUME_TAILOR_PROFILE`, if set, overrides both.

**Derived mode.** If a `profile-config.md` sits next to the resolved profile — or `paths.yaml` names one — the profile is generated from a richer career record rather than maintained by hand. That file is read by `/profile-build`, not by `/tailor`; `/tailor` only ever reads `profile.json`.

**Optional config.** `$ENGINE/inputs/paths.yaml`, when it exists, overrides the defaults in this section. Read it first. Every key is optional; an absent or empty value means "use the default". `~` and `$HOME` expand, and a relative path resolves against `$ENGINE`. Template: `$ENGINE/inputs/paths.example.yaml`. A single-machine setup never needs the file; a profile kept outside the repo does.

| Key | Overrides | Default if empty |
|---|---|---|
| `profile` | profile location | `$ENGINE/inputs/profile.json` |
| `profile_config` | derived-mode config | a `profile-config.md` next to the profile |
| `resume_examples` | resume style dir (§4a) | `$ENGINE/inputs/resume-examples/` |
| `cover_letter_examples` | letter style dir (§4a) | `$ENGINE/inputs/cover-letter-examples/` |
| `resume_template` | named resume layouts + the no-flag default (§2c) | page-aware: `resume` at 1 page, `resume-2page` above |
| `cover_letter_template` | `--cl-template` default | `cover-letter` |
| `output_root` | `$OUTDIR` rules 1 and 2 below | unset — decide per run |
| `default_pages` | `--pages` default (§2b) | `1` |
| `default_target_score` | `--target` default (§2b) | `85` |

A flag passed on the command line always wins over `paths.yaml`, which always wins over the built-in default. `$RESUME_TAILOR_PROFILE` and `$RESUME_TAILOR_OUT` win over everything.

**Style example directories.** `resume_examples` and `cover_letter_examples` above. Used in §4a.

**Output directory.** Decide per run, in this order:

1. JD came from a **file path** → write into that file's directory. The user already made a folder for this job; use it.
2. Otherwise → `./resume-agent-output_{company-slug}-{role-slug}/` in the current working directory.
3. **Never write inside `$ENGINE`.** If rule 1 or 2 resolves to a path inside the engine repo, fall back to `$HOME/job-applications/{company-slug}/{role-slug}-{YYYYMMDD}/` and say so. The engine repo is a public fork and personal artifacts must not land in it.

`output_root` in `paths.yaml` overrides rules 1 and 2; `$RESUME_TAILOR_OUT` overrides everything. Under either, write into `{output_root}/{company-slug}/{role-slug}-{YYYYMMDD}/`.

Call the resolved directory `$OUTDIR`. Announce it before writing anything.

## 2. Invocation + JD intake

The user invokes `/tailor` and supplies the JD by one of:

- **Path:** absolute path to a JD `.txt` file (e.g. `inputs/jd.txt`, or any other location the user saved it).
- **Raw text:** the JD pasted directly into chat between triple-backticks or quotes.

Agent sniffs:
- If input looks like a valid path AND the file exists → read file.
- Else → treat the message as raw JD text.

Either way, the agent ends up with `jd_text` (string) and `jd_dir` (directory the JD lived in, if path-mode; else `null`).

### JD metadata extraction
Try in order:
1. **Sibling `jd.meta.json`** in `jd_dir` — if present, read `{title, company, location, url, source, captured_at}`.
2. **First-two-lines parse** — JD posts usually start with the role title, then company on a separate line. Agent picks them out heuristically.
3. **LLM extract from full text** — only if 1+2 fail. Single shot.

Fields needed: `company`, `role`, `location` (optional), `source_url` (optional).

If `company` or `role` end up empty → ask the user, ONE question total: "Couldn't infer company/role from the JD. Give me `<Company> / <Role>`."

---

### 2b. Mode flags

| Flag | Effect |
|---|---|
| `--pages N` | Page budget. Default `default_pages` from `paths.yaml`, else 1. The gate blocks anything over N. |
| `--template X` | Resume layout, by name or path. Omitted → picked from the page budget. See §2c. |
| `--cl-template X` | Cover letter layout. Default `cover_letter_template` from `paths.yaml`, else `cover-letter`. Resolves the same way. |
| `--cl-pages N` | Hard page cap for the cover letter. Unset by default — the letter runs as long as the content and the examples warrant. |
| `--ref N` | How many references to print, when the template has a References section. Default 1. `--ref 0` drops the section. See §2e. |
| `--cl-only` | Cover letter + outreach only. See §2d. |
| `--cover` | Write cover letter + outreach unconditionally (skip the §11c ask). |
| `--no-cover` | Skip the §11c ask; gap report only. |
| `--target N` | ATS-readiness floor (default `default_target_score` from `paths.yaml`, else 85). Formatting only — it does **not** raise the JD-fit bar, which is never gated. See §8. |

Flags combine and are independent, with one deliberate exception: `--pages` also selects the default layout, so `--pages 2` alone gives the two-page layout at two pages rather than the one-page layout with room to spill (§2c). `--template X` alone uses layout X but still enforces one page.

**Flags are a convenience, not a grammar.** This is a playbook an agent reads, not a CLI parser. Plain language carries the same weight as a flag, and the two mix freely:

| The user writes | Read it as |
|---|---|
| `/tailor --pages 2 use the 2 page template` | `--pages 2 --template 2page` |
| `/tailor two pages, research layout` | `--pages 2 --template research` (if `research` is a configured name) |
| `/tailor <jd> no cover letter` | `--no-cover` |
| `/tailor <jd> three references` | `--ref 3` |
| `/tailor <jd> keep it to one page` | `--pages 1` |

Resolve names as §2c describes. If a phrase is ambiguous or matches nothing, ask once and list the available names — never silently fall back to the default when the user clearly asked for something specific. Echo the resolved settings before writing anything: *"2 pages, layout `2page` (resume-2page-blue.tex.tmpl), 1 reference, cover letter on."*

### 2c. `--template` — layout selection

`resume_template` in `paths.yaml` is a **map of named layouts**, not a single value:

```yaml
resume_template:
  default:       "~/record/templates/resume-blue.tex.tmpl"
  default_2page: "~/record/templates/resume-2page-blue.tex.tmpl"
  compact:       "compact"
  academic:      "~/record/templates/cv-style.tex.tmpl"
```

Two reserved keys pick the layout when the user names none; every other key is a name the user can ask for. Values are resolved the same way a `--template` value is (path first, then `$ENGINE/templates/<value>.tex.tmpl`), so a map entry may itself be a bundled template name.

**Which layout, in order:**

1. **The user named one** — `--template X`, or plain language (§2b). Match `X` case-insensitively against the map's keys first, then resolve as a value.
2. **No name given** — page-aware default: budget of 1 → `default`; budget of 2 or more → `default_2page`.
3. **No `paths.yaml`, or no `resume_template` in it** — same page-aware rule against the bundled templates: 1 page → `resume`, 2+ pages → `resume-2page`. This is the whole reason the rule is page-aware; a one-page layout given a two-page budget produces a stretched one-pager with no Publications and no References section, which is never what "make it two pages" meant.
4. **`resume_template` is a bare string** (the older single-value form) — treat it as `default` and keep using it at every page count. Still supported; the map is what makes `--pages 2` do the right thing on its own.

**Resolving a single value** (a map entry, a `--template` argument, or a bundled name):

1. A path that exists (absolute, `~`/`$HOME`-expanded, or relative to the user's working directory) → use that file. Templates may live outside the engine repo, including in a private profile repo.
2. Otherwise `$ENGINE/templates/<value>.tex.tmpl`.
3. Neither → halt, and list both the configured names from the map and the contents of `$ENGINE/templates/`.

A name in the map that resolves to a missing file is a config error, not a fallback: say which key is broken and stop. Silently substituting a different layout changes the resume's sections.

**The template defines the resume's sections and their order. This playbook does not.** Everything shipped in `templates/` is one example layout, not a required format. Users are expected to copy one and rewrite it — different fields want different sections in different orders.

Consequences for the rest of the run:

- **Section list and order (§6 checks 1 and 2) are derived from the chosen template**, by reading its `\rsection{...}` calls top to bottom, skipping any line commented out with `%`. Do not check against a hardcoded list. The one-page default happens to produce Summary, Skills, Projects, Experience, Education; a research layout might produce Summary, Education, Experience, Skills, Publications. Both are correct for their template.
- **Only populate sections the profile has data for.** If a template has a `Publications` section and `profile.publications[]` is empty, drop the section rather than shipping an empty heading. If the template's core sections are mostly unpopulated, say so plainly — the user probably wants a different template, or needs to run `/profile-build`.
- **Extra profile fields** (`publications`, `talks`, `leadership`, `awards`, `funding`) are optional and only used when the template has somewhere to put them.
- **Publication status is copied verbatim** from `status_verbatim`. Promoting "Submitted" to published is fabrication.
- **Margin floor ~0.7in.** Below roughly 0.65in the bundled scorer false-detects a multi-column layout — `severity: fail`, an automatic gate failure — and text extraction scrambles. This is a property of the scorer, not of any one template, so it applies to any custom layout too. If a run reports `multi-column layout` on a single-column template, widen the margin before anything else, and never tighten below 0.7in to fit content. Cut content instead.

### 2d. `--cl-only`

- Do §2 intake and §3 module selection as normal.
- **Skip §4 through §9 entirely.** No `.tex`, no compile, no `resume.md`, no `score.json`, no repair loop.
- Write `cover-letter.md` in the output folder per the §11d and §11e rules. `--cl-only` is the one mode where the letter is a standalone file; in every other mode it is appended to `recommendations.md` per §11f.
- Still write `recommendations.md` with the §11a gap report — the coverage matrix is what keeps the letter honest.
- `run.json` carries `"mode": "cl-only"` and no `iterations[]`.

**Report this explicitly to the user:** the ATS accept gate never ran on this path, so nothing was scored or verified. The letter ships on the no-fabrication rule alone.
### 2e. `--ref N` — references on the resume

Applies only when the chosen template has a `\rsection{References}`. The bundled `resume-2page` layout does; `resume` does not. If the template has no References section, ignore the flag and say so once.

Source is `profile.references[]`. Each entry carries `name`, `title`, `department`, `organization`, `email`, `phone`, `relationship`, and a boolean `default`. Exactly one entry should have `"default": true`.

| `N` | Behaviour |
|---|---|
| `0` | Drop the References section entirely. A legitimate drop for §6 check 1, same as any section with no data. |
| `1` (default) | Print the single entry with `"default": true`. If no entry is flagged, print the first and say which one you used. |
| `>1` | **Ask the user which ones.** List every entry in `profile.references[]` by name, numbered, marking the default. Take the user's picks and print them in the order given. One question, not one per reference. |

`--ref N` greater than the number of references in the profile: print all of them and say the profile only has that many. Profile has no `references[]` at all: drop the section and tell the user to add references with `/profile-build`.

References go **last**, after every other section, regardless of where they sit in a custom template's `\rsection` order — a References block above Education reads as a mistake. If a template puts them elsewhere, follow the template but flag it.

Never invent a referee, an email, or a title. This is the no-fabrication rule at its sharpest, since a wrong address reaches a real person.

---

## 3. Module selection — deterministic prefilter, LLM final pick

Cuts the LLM's working set so the tailoring pass works on a subset, not the whole profile.

### 3a. Deterministic prefilter
- Tokenize `jd_text`: lowercase, strip punctuation, split on whitespace, drop English stopwords + 1-character tokens.
- Build `jd_keywords` = set of remaining tokens + any 2-token phrases that match against `profile.keyword_bank` and against every `tags[]` array in the profile (`skills.*[].tags`, `experience[].bullets[].tags`, `projects[].bullets[].tags`).
- For each profile module (each bullet in experience, each project, each skills entry), compute `overlap = |module.tags ∩ jd_keywords|`.
- **Include in prefilter** if `overlap ≥ 1`, OR if the module is in `experience` (always include experience entries — most recent role is high-signal even without tag hit), OR if the module appears in `profile.projects[].highlight_for` matching any JD domain word.

Loose. Better to include too much here; LLM trims next.

### 3b. LLM final pick
Agent reads `jd_text` + the prefiltered profile subset + identity + education. Picks the final set of bullets/projects/skills for the résumé. Constraints:

- Page budget: `--pages N`, default 1 (see §6).
- Cover what the JD asks where genuine evidence exists.
- Honest signal weighting (lowest-relevance projects can be cut even if prefilter included them).
- Never invent. Never reword to imply experience that isn't in `profile.json`.

Record the final selection in `run.json.selected_modules[]` for the snapshot.

---

## 4. Tailoring pass — write `resume.tex`

### 4a. Read the style examples first

Read whatever sits in the example directories resolved in §1. A PDF converts with `"$ENGINE/tool" <file> --md <out>.md`; DOCX, TXT and MD read directly. Convert into a scratch directory, and note that `--md` refuses to overwrite an existing path (§6) — it silently writes `<name>-2.md` instead. Empty or missing directory: skip silently, this is optional and common.

**These are style references, never content sources.** Take from them: tone and register, how sections are named and ordered, bullet rhythm (length, whether they open with a verb, how often a number appears), how much detail one item gets, and what the person chooses to leave out.

Do **not** take facts from them. Every claim still traces to the profile, and an example that contradicts the profile is stale — the profile wins. Never reuse a sentence verbatim; a recycled phrase is a style tell, not a style lesson.

When examples disagree with each other, prefer the most recent.

**For the resume**, the template wins on structure and examples inform wording only. **For the cover letter, the examples win outright** — they govern length, organization, and register, and §11d imposes no word or paragraph count that could override them. A research-staff or national-lab letter is commonly several times the length of a short industry one and organized as one bold heading per posting requirement; if the examples show that, write that. Say in the run summary which shape was used and why.


One LLM pass. Input: selected modules + identity + education + `jd_text` + `$ENGINE/templates/resume.tex.tmpl` + `$ENGINE/references/verb-bank.md` + `$ENGINE/references/blacklist.md`.

`$ENGINE/references/writing-style.md` governs prose voice: sentence length, tense consistency, acronym handling, and terminology discipline. It matters most for the cover letter and the gap report (§11); for bullets, the tighter rules below win where the two differ.

Output: a fresh `resume.tex` following the chosen template's **pattern** (§2c) (don't substitute placeholders mechanically — read the template, write fresh).

### Required structure
- Section order comes from the chosen template (§2c), not from this list. The default template produces: Header, Summary, Skills, Projects, Experience, Education, Certifications. Skip any section with no profile data.
- Single column. Page budget per `--pages`, default 1.
- `\rsection{...}` for section headings (defined in the template).
- Categorized Skills: `Languages / Frameworks / Tools / Domains`. Tier 1 gazetteer reads these. List concrete tool names the profile genuinely supports.
- Project + Experience entries: bold title, italic stack/company, date right-aligned with `\hfill`, github URL via `\href`, bullets in `itemize`.

### Bullet rules (the humanizer ruleset applied at write time)
- Lead with an action verb from `$ENGINE/references/verb-bank.md`.
- Past tense for completed work, present tense for current ongoing roles.
- 1–2 lines max per bullet. One factual outcome + quantification when one exists.
- **Apply every rule in `$ENGINE/references/blacklist.md` BEFORE writing the line.** No em-dash punctuation (date ranges exempt), no AI vocab, no copula avoidance, no negative parallelism, no chatbot artifacts, no filler, no hedging, no adverb sludge, no rule-of-three abuse, no vague attribution, no superficial -ing analyses, no promotional language. Date format consistent (`Mon YYYY`).
- Active voice only. Bullets like "Was responsible for X" → "Managed X" or stronger verb from verb-bank.

### Summary rules
- Assembled from `profile.summary_seeds`, weighted toward JD keywords the profile genuinely supports.
- **Wrap it in `\rsummary{...}`, never in `\raggedright`.** The summary is justified like every other paragraph; a ragged block sitting above justified bullets reads as unfinished. `\rsummary` also measures itself, which is what makes the next rule checkable.
- **Four rendered lines is a hard cap** (§6 check 7), two to three is the target. Lines, not sentences: the same words occupy fewer lines on a 2-page layout than a 1-page one, so write it, compile, and read `SUMMARY-LINES` from the log rather than counting words. Over budget → cut the least JD-relevant clause, not the margin and not the font.
- No fabrication. No filler. No AI vocab.
- **JD role title in summary — only if seniority matches.** Surfacing the JD's literal role title (e.g., "Senior Data Engineer") helps Jobscan-class tools ONLY when the profile actually supports that seniority. Inserting "Targeting Senior Data Engineer roles" into a junior profile **lowers** the external score (tested 2026-06-27, Jobscan dropped 96 → 56). For under-seniority cases, leave the title out of the resume entirely; the JD-noun mirroring below + clean projects do more good than a target-claim does harm.

### JD-noun mirroring (parser hit rate)
When the JD uses specific nouns that the profile genuinely covers in concept, mirror the JD's wording verbatim in a bullet. Recruiter ATS gazetteers index these as separate keywords from the verb forms:
- **production** — if the profile has shipped/running pipelines, say "production data pipelines" not just "data pipelines".
- **monitoring**, **alerting**, **validation**, **observability** — if a project really has these, name them as nouns.
- **schema design**, **dimensional modeling**, **normalization** — name the technique not just the activity.
- **batch**, **near-real-time**, **streaming** — name the cadence explicitly.

Only mirror when the underlying experience is genuine. Mirroring without evidence = fabrication.

### Skills rules
- Categorized lines (see template). 
- Only skills with profile evidence. Do NOT add a skill from the JD just to match it.
- Surface skills the profile has but the scorer's parser might miss (e.g., move `Apache Airflow` into Frameworks line even if it's only in a project bullet — Tier 1 gazetteer scans the whole document but the Skills section is a stronger signal).

### Final write
`resume.tex` lives in the run's output folder (§10). Agent writes it directly there.

---

## 5. Compile

```
"$ENGINE/tectonic" --keep-logs --outdir $OUTDIR $OUTDIR/resume.tex
```

- Exit 0 → proceed to §6.
- Non-zero → read `resume.log`, find the LaTeX error, edit `resume.tex`, retry. No iteration cap on compile fixes (these are mechanical and fast).

### Word-boundary safety — required in every template

```latex
\tolerance=3000
\emergencystretch=3em
\hyphenpenalty=10000
\exhyphenpenalty=10000
\AtBeginDocument{\fontdimen4\font=0pt}
```

Two separate extraction failures, both invisible on the printed page.

**Squeezed spaces.** A justified line TeX has compressed can lose its word boundaries entirely: the extractor returns `graphneuralnetworks,machine-learnedinteratomicpotentials` as one token, which no ATS keyword scan can read. `\tolerance`, `\emergencystretch` and the zeroed `\fontdimen4` make TeX set a slightly loose line instead of a crushed one.

**Hyphenation.** A word broken across a line keeps its hyphen in the extracted text — `configu-ration sampling`, `agen-tic`, `develop-ment` — so the keyword never matches the JD even though the PDF is correct. Both penalties are needed: `\hyphenpenalty` stops TeX's automatic hyphenation, `\exhyphenpenalty` stops it breaking at a hyphen the word already contains. Measured on the bundled 2-page layout: adding these lifted JD match 60 → 63 with no other edit. Genuine compounds (`fine-tuning`, `large-scale`) are unaffected — they keep their hyphen and stay on one line.

The bundled templates all carry the block above. If a custom template lacks it, add it before compiling, and run §6 items 6 and 7 afterwards either way.

### Layout macros the bundled templates define

| Macro | Use |
|---|---|
| `\rsection{Name}` | Section heading + rule. Ends with `\par`, never `\\`, so a blank line after it in the source cannot leave an empty line above the content. Widens its own interword space to 0.33em so PDF viewers do not copy the heading back as `LEADERSHIP&TEAMWORKEXPERIENCE`. |
| `\rsummary{...}` | The Summary paragraph. Justified, and writes `SUMMARY-LINES: N` to the log (§6 check 7). |
| `\rsubgroup{Theme}` | 2-page layouts only. A themed workstream inside one role — an open-circle marker plus bold text, indented one step so it reads as a child of the job title rather than a peer of it. |
| `rsubitems` | The itemize that belongs to an `\rsubgroup`, indented one step further. A role with a single focus takes a plain `itemize` at the margin instead. |

Do not flatten `\rsubgroup` back to a flush-left `\textbf{...}`: at the margin it looks like another job title. Its `$\circ$` marker is measured rather than assumed — it scores identically to a text-only heading (ATS 100, JD 63 on the bundled 2-page layout) and the extractor reads the line as a list item instead of a stray bold line. Glyphs stay on the marker; never put one inside bullet text.

### Known LaTeX gotchas — escape at write time, save a recompile
- **Underscores in URL display text** must be escaped: write `github.com/user/Some\_Repo`, NOT `Some_Repo`. The URL inside the FIRST `\href{...}` arg is fine; only the visible second arg needs the escape. Symptom: `Missing $ inserted`.
- **`&`, `%`, `$`, `#`** in any visible text → escape with backslash (`\&`, `\%`, `\$`, `\#`).
- **`~`** literal → `\textasciitilde{}`. Inside URLs use `%7E`.
- **`^`** literal → `\textasciicircum{}`.

---

## 6. Structural verify (via `--md`)

```
rm -f $OUTDIR/resume.md
"$ENGINE/tool" $OUTDIR/resume.pdf --md $OUTDIR/resume.md
```

**The `rm -f` is not optional.** `tool --md` never overwrites: given a path that already exists it writes `resume-2.md`, `resume-3.md`, ... and prints `wrote <actual path>` while returning 0. Skip the delete and every re-verify after a repair reads the *first* iteration's extraction, so a fix looks like it changed nothing and a regression goes unnoticed. Delete first, or read the path the tool prints.

Read `resume.md` and check (all must pass):

1. **Sections present.** Read the `\rsection{...}` calls from the chosen template (§2c), ignoring `%`-commented lines, to get the expected section list, minus any section legitimately dropped for lack of profile data, and minus References when `--ref 0` was passed (§2e). Every remaining one must appear in the extracted MD. Casing: the scorer uppercases by default; match case-insensitively.
2. **Reading order:** sections appear in the same top-to-bottom order as their `\rsection{...}` calls in the template.
3. **Contact present:** the header line at the top of the MD contains the email, and the phone when the profile has one (or `mailto:` / `tel:` URLs are recoverable).
4. **No LaTeX artifacts:** no `\&`, `\%`, `\$`, stray `{` or `}`, `\textbf`, `\hfill`, etc. anywhere in the MD.
5. **Page count: HARD BLOCK.** Budget is `--pages N`, default 1. Exceeding it always blocks. Parse the `Output written on ... (N pages` line from `resume.log`. That is the only method verified to work: `pdfinfo` is often not installed, and the `--md` exporter emits no form-feed characters, so a form-feed count reports 1 page for any document and would let a 3-page resume through. If `N` exceeds the budget → **DO NOT proceed to scoring.** Recompile after one of: tighten `\rsection` `\vspace` 4pt → 2pt, tighten `\setlist` `topsep`/`itemsep` to 0pt, cut the lowest-relevance project, drop a low-value bullet, or shorten a bullet enough to lose a whole wrapped line. **Do not touch the margin** — 0.7in is the floor (§2c), and every bundled template already sits on it. Never skip this check — an overflow page makes the resume look amateur regardless of score.

6. **No collapsed word boundaries.** `grep -oE '[A-Za-z][A-Za-z,.-]{25,}' $OUTDIR/resume.md` must return nothing. A hit means a justified line was compressed until the extractor lost the spaces, so a whole phrase reaches the parser as one token. Fix by adding the §5 word-boundary block to the template, not by rewording. Re-extract (with the `rm -f`) and re-check.

7. **No hyphen-split words.** `grep -nE '[A-Za-z]-$' $OUTDIR/resume.md` must return nothing — a trailing hyphen is a word TeX broke across a line, and it reaches the parser hyphenated. Fix with the two `\hyphenpenalty` lines from §5, not by rewording. Note that a mid-line `state-of-the-art` or `plug-and-play` is a genuine compound and not a hit; only a hyphen at end of line is.

8. **Summary within budget.** `grep -oE 'SUMMARY-LINES: [0-9]+' $OUTDIR/resume.log` must report **4 or fewer**. Over budget → cut the least JD-relevant clause from the summary and recompile. If the line is absent, the summary was not wrapped in `\rsummary{...}` — wrap it (§4 Summary rules) and recompile; do not skip the check.

Fail → identify which check failed, edit `resume.tex` to fix:
- Missing section → add it (only if profile has content; skip empty sections per §4).
- Out-of-order → restructure `resume.tex`.
- Missing contact → check header `\href` URLs.
- LaTeX artifacts → escape or remove the offending macro.
- Page overflow → trim a low-value bullet, tighten wording (don't change template).
- Collapsed word boundaries → add the §5 word-boundary block; expect the document to grow slightly and re-check the page budget.
- Hyphen-split words → add the two `\hyphenpenalty` lines from §5; same caveat, lines get slightly looser.
- Summary over 4 lines → cut a clause from the summary itself. Never shrink the font, the margin, or `\baselineskip` to make it fit.
Then recompile → re-verify. No iteration cap on structural fixes.

---

## 7. Score

**Two modes — use the right one.** The tool prints a well-structured human-readable report by default; reading that is far cheaper than parsing JSON when the agent only needs to UNDERSTAND state. JSON is only for programmatic gate decisions.

### 7a. Inspection (read the report directly)
```
"$ENGINE/tool" $OUTDIR/resume.pdf --jd <jd_tmp>.txt
```
Agent reads the printed report directly: overall, ATS risks, missing keywords, weak requirements, writing advice. No piping, no `jq`, no Python parser. Default for inspection / debugging passes.

### 7b. Accept-gate evaluation (parse JSON)
```
"$ENGINE/tool" $OUTDIR/resume.pdf --jd <jd_tmp>.txt --json > $OUTDIR/score.json
```
ONLY when the agent must check the accept gate (§8) programmatically. Persist `score.json` to the output folder.

`<jd_tmp>.txt` is a plain-text dump of `jd_text` to a temp file (always, even when the source was already `jd.txt` — keeps the invocation uniform).

**`overall` is the ATS-readiness score, not a quality score.** The scorer's own README says so outright: *"The overall score is the ATS-readiness score (0-100)."* It measures whether a parser can read the document. It says nothing about whether the resume fits the job. `jd_match.score` is the fit number, and the two are deliberately never blended. Never report `overall` to the user as though it summarized the run.

JSON shape per spec §5.9:

```
overall: int
ats:            { score, findings: [{severity, ...}, ...] }
writing_advice: { fillers, ai_tells, findings }
jd_match:       { score, skill_coverage, prose_coverage, matched, missing, weak_requirements }
```

---

## 8. Accept gate

All of these must hold:

1. `ats.score >= target_score` (default **85**, `--target N` overrides). This is a **formatting floor**, not a fit bar — a clean template clears it on the first compile. It is here to catch a broken layout, nothing more.

   **`jd_match.score` is reported, never gated.** There is no minimum fit score, deliberately: a low JD score usually means the profile genuinely lacks what the posting wants, and no amount of rewriting fixes that honestly. Items 3 and 4 below are what actually enforce fit — they require every coverable gap to be closed, which is the part a resume can control.
2. Zero entries in `ats.findings` with `severity == "fail"`.
3. `jd_match.missing` contains only skills the profile *genuinely* does NOT support (cross-check each missing entry against `profile.skills.*[].name`, `profile.experience[].bullets[].tags`, `profile.projects[].*tags`, and `profile.keyword_bank`; if found anywhere → it's a coverable gap, must be closed before ship).
4. `jd_match.weak_requirements` after filtering out **fragments** is either empty OR every remaining entry maps to a genuine profile gap.

### Fragment filter for weak_requirements
Drop any entry that:
- Has fewer than 6 words after stripping punctuation.
- Doesn't contain a verb (heuristic: no token in `{is, are, was, were, has, have, build, design, work, manage, lead, own, integrate, ...}`).
- Ends with a comma (sentence-splitter artifact).
- Starts with lowercase AND has no leading conjunction — partial-sentence continuation.

These are scorer quirks, not actionable signal.

---

## 9. Repair loop — hybrid

Fail accept gate → repair pass. **No iteration cap.** Loop until accept gate passes OR remaining gaps are profile-genuine (provable cannot-close).

Track `best_iter` by this ranking, in order: **(1)** fewest `ats.findings` with `severity == "fail"`, **(2)** highest `jd_match.score`, **(3)** highest `ats.score`. Fit is the primary ranking key once the document parses cleanly — that is the whole point of iterating. Do not rank on `overall`; it is the ATS score (§7b), so ranking on it means ranking on formatting and ignoring fit. Keep only `resume.tex` + `resume.pdf` + `score.json` of the best (overwrite when a new best is found). Append every iteration's summary to `run.json.iterations[]`.

### 9a. Deterministic ATS structural fixes (mechanical)
For each `ats.findings` entry, apply the canonical fix without LLM reasoning:

| Finding | Fix |
|---|---|
| `tables present` | Find `\begin{tabular}` / `\begin{table}` in `resume.tex`, replace with itemize or plain text. |
| `multi-column layout` | Remove `multicol` package + environment. Restore single column. |
| `images present` | Remove `\includegraphics` lines. |
| `bullets are graphics, not text` | Ensure bullets use `itemize` not custom graphic markers. |
| `missing section: <name>` | If profile has data for that section, add it; if not, leave (warn). |
| `no email found` | Add `\href{mailto:<email>}{<email>}` to header. |
| `no phone found` | Add `\href{tel:<phone>}{<phone>}` to header. |
| `no location found` | Add city/country to header. |
| `no LinkedIn / portfolio link` | Add LinkedIn `\href` to header line. |
| `inconsistent date formats` | Normalize all dates to `Mon YYYY`. |
| `not machine-readable (scanned)` | Should not happen with a fresh Tectonic compile; halt — investigate. |

### 9b. LLM content rephrasing (judgment)
For each profile-coverable `jd_match.missing` entry → **add the term to the Skills section.** `jd_match.missing` and `skill_coverage` are computed from the Skills section alone (the scorer's Tier 1 gazetteer). Putting the term in a bullet does not move them. Measured on a real run: the phrase "configuration sampling" sitting in an experience bullet left `skill_coverage` at 0.500 and JD match at 57; moving the same phrase into the Skills line took them to 0.556 and 60, with no other edit.

Then, separately, rephrase the bullet that carries the evidence so a human reader sees where the skill was actually used. The Skills entry moves the score; the bullet earns it. Never add a Skills term the profile does not support — that is fabrication, and it is the one place where keyword stuffing is easy and wrong.

Do not chase `missing` entries that are posting boilerplate rather than skills: degree fields ("computer science", "physical science"), values language ("integrity"), soft-skill phrases ("work collaboratively"), and tokenizer debris ("a computer"). Those belong in the cover letter or nowhere. Log them in `recommendations.md` as scorer artifacts so the fit number is not misread.

For each non-fragment `jd_match.weak_requirements` entry → find the project/bullet that genuinely covers it (cross-check profile), rephrase the bullet to use phrasing closer to the JD's requirement language. **Only when underlying experience exists.** No fabrication.

For each `writing_advice.findings` entry → silently clean up. Doesn't gate ship, but humanizer rule is non-negotiable; flagged lines get rewritten until clean.

### 9c. When to stop
- Accept gate passes → break, ship current iteration.
- A full repair pass produces no edits (everything remaining is genuinely uncoverable) → break, ship `best_iter` with explicit log.
- Same exact `score.json` two iterations in a row → break (stuck), ship `best_iter`.

On break-without-pass: write the unresolved gaps to `recommendations.md` (§11) and `run.json.unresolved`.

### 9d. Always report the fit score, and explain a low one

Every run summary states both numbers and keeps them distinct: `ATS <n>/100` (does it parse) and `JD match <n>` (does it fit). Never collapse them into one figure, and never quote `overall` as the headline.

When `jd_match.score` is below **60**, say so plainly and give the reason, drawn from the coverage matrix (§11a) rather than guessed. The reason is one of:

- **Genuine profile gaps** — the posting wants things the record does not contain. Name the top two or three. This is the common case and the honest answer; it means apply anyway or go get the experience, not rewrite the resume.
- **Scorer artifacts** — the posting's boilerplate (degree fields, "integrity", "work collaboratively") tokenizes into `missing` without being a real gap. Say which entries are noise so the number is not read as a verdict.
- **Profile is stale** — the evidence exists in real life but was never written into `profile.json`. Point at `/profile-build`.

A low fit score never blocks the ship (§8). It changes what the user is told.

---

## 10. Output folder

`$OUTDIR`, resolved in §1. Slug rules for the names used there: lowercase, ASCII only, spaces → `-`, strip all other punctuation, trim to 60 chars max. On collision append `-2`, `-3`, …

Final contents:
```
resume.tex
resume.pdf
resume.md           # tool --md snapshot of final PDF
score.json          # final scorer output
jd.txt              # JD snapshot
jd.meta.json        # extracted metadata
recommendations.md  # gap report + optional cover letter + outreach
run.json            # selected_modules, iterations[], shipped, unresolved
```

Nothing written outside this folder.

---

## 11. Recommendations pass

After accept gate passes (or after best-effort exhaustion), one LLM pass writes `recommendations.md`.

### Trigger
- **Default:** agent asks ONE question after résumé is shipped (see §11c).
- **Flag override:** if user invoked `/tailor --cover` → skip the ask, write cover letter + outreach unconditionally.
- **Flag override:** if user invoked `/tailor --no-cover` → skip the ask, write gap report only.

### 11a. Gap report (ALWAYS written)

Two subsections, in this order.

**Coverage matrix.** One row per distinct JD requirement (deduped). Columns:

| JD Requirement | Profile Evidence | Strength |
|---|---|---|

- `JD Requirement`: verbatim noun phrase from JD ("production ETL on AWS", "5+ years experience", "dbt").
- `Profile Evidence`: the project/bullet/skill in `profile.json` that backs it (with module path: `projects[0].bullets[0]` or `skills.frameworks[dbt]`). Empty if nothing in profile maps.
- `Strength`: `strong` (≥1 shipped project + tag overlap), `partial` (mentioned but no project), `thin` (one tangential reference), `gap` (nothing).

Sort: `gap` first (most actionable), then `thin`, `partial`, `strong`.

**Honest framing for thin/gap items.** For each `thin` or `gap` row, one sentence on how to address it in the interview WITHOUT lying. Example:
- ✗ "Spin it positive — say you're 'familiar with Kafka'." — that's fabrication-by-implication.
- ✓ "No Kafka in profile. Interview line: 'I haven't shipped Kafka in production, but my Airflow weather pipeline handles async ingestion at 3,500-source scale — the streaming primitives transfer. I'd ramp in the first month.'" — names the gap, names the closest evidence, names the ramp.

### 11b. Unresolved findings (only if repair loop broke without passing accept gate)

For each unresolved entry from `run.json.unresolved`:
- The finding verbatim.
- Why the engine couldn't close it (one of: `profile lacks evidence`, `JD phrasing too specific to match without invention`, `scorer parser quirk — manually verified safe`).
- One actionable line ("Consider learning X before re-applying" / "Mention in interview, not on résumé").

If `run.json.unresolved` is empty → omit this section entirely. Do not write "No unresolved findings."

### 11c. Opt-in: cover letter + outreach

If trigger is the default (no flag), agent asks ONE question after writing 10a (+ 10b if applicable):

```
Want a cover letter and/or recruiter outreach draft for this role? [Y/n]
```

- `Y` → write both, appended to `recommendations.md`.
- `n` → write nothing more.

If trigger was `--cover` → skip the ask, write both.
If trigger was `--no-cover` → skip the ask, write nothing more.

### 11d. Cover letter rules

**Output format.** Write `cover-letter.tex` from the chosen `--cl-template` (§2c; default `templates/cover-letter.tex.tmpl`) and compile it to `cover-letter.pdf` with the §5 command. Also write the plain text into `recommendations.md`, or into `cover-letter.md` under `--cl-only`, so the wording is reviewable without opening the PDF. If the compile fails and cannot be fixed in two attempts, ship the Markdown alone and say the PDF failed.

Two `moderncv` gotchas: use `newtxtext` rather than `mathptmx`, which XeTeX leaves unresolved; and the bundled template overrides `\makeletterhead` to drop the recipient block and date line, so do not add a `\recipient` call back unless you also restore the stock head (empty `\recipient` arguments abort the compile with "There's no line here to end").

**Content rules.**

The template supplies the frame: sender header, salutation, closing, signature. There is deliberately no recipient block — no "Hiring Manager / Unit / Organization" lines above the salutation. Do not reintroduce them. Between the salutation and the closing, **the style examples govern** (§4a) — tone, register, how the body is organized, whether requirements get bold headings, how long the whole thing runs. There is no default word count and no required paragraph count. A short industry letter and a six-hundred-word national-lab letter organized one heading per posting requirement are both correct; the examples say which one this is.

With no examples available, write a short letter: opening paragraph, two or three evidence paragraphs, closing paragraph.

The only fixed parts:

- **Opening paragraph, short.** Name the role and the organization verbatim from the JD, and state the single strongest evidence-backed match. No "I am writing to apply for…" boilerplate.
- **Closing paragraph, short.** One sentence on what the role offers or what you would bring, then the thank-you. No "I look forward to hearing from you" filler as a paragraph of its own.
- **Addressing:** "Dear <Company> Hiring Team," unless `jd.meta.json` names a hiring manager → "Dear <Name>,". A generic "Dear Hiring Manager," is fine when the examples use it.
- **Body traces to the profile.** Every claim maps to a real `profile.json` module, same no-fabrication gate as the résumé. Mirror JD nouns where the underlying experience genuinely exists (same rule as §4 JD-noun mirroring). Honest gap framing only.
- **Style reference: `$ENGINE/references/writing-style.md`.** Read it before writing the letter. It sets sentence length, tense consistency, acronym handling, and terminology discipline. The style examples (§4a) govern length and organization; this file governs how the sentences read.
- **Humanizer rules apply (`$ENGINE/references/blacklist.md`):** no em-dash punctuation, no AI vocab (leverage, synergy, robust, seamless, cutting-edge, passionate about), no copula avoidance, no negative parallelism, no chatbot artifacts ("I'd be happy to…", "Thank you for considering…" as a paragraph by itself).
- **Sign-off:** the name only — no extra title line, the résumé carries the title.

**`--cl-pages N`.** `N` is a whole number of pages. There is no fractional budget: page count is read as an integer from the `Output written on ... (N pages` line in the `.log`, the same way the résumé budget is (§6 item 5), and nothing in the pipeline can express "a page and a half". To land at roughly a page and a half, write to that length; the flag is a ceiling, not a target.

Unset by default: whatever the content and the examples produce is what ships, however many pages that is. When the flag is given it is a hard cap, enforced the same way as the résumé page budget — compile, count pages, and if it is over, cut body content and recompile. Cut evidence, never the opening or closing, and never tighten the template's margins or spacing to fit. Two failed attempts to fit → ship the overlong PDF and say so plainly.

A letter running to two or more pages is supported and needs no template change: the moderncv header prints once on page 1, the body flows, the closing and signature land on the last page, and moderncv adds an `n/N` page number in the footer once there is more than one page. Verified at 2 pages with the bundled `cover-letter` template.

Report the shape used in the run summary: which examples informed it, the final word count and page count, and whether a cap was applied.

### 11e. Outreach rules

For a recruiter or hiring manager LinkedIn / cold email DM.

- **Length:** ≤ 80 words. Hard limit.
- **Subject (only if email format):** "<Role> — <Name>, <strongest qualifier>" (e.g., "Senior Data Engineer — Mahmoud Mustafa, dbt + Airflow + Snowflake").
- **Structure:**
  1. One sentence naming role + company + how you found it (LinkedIn / company page / referral). Skip the "how" if unknown.
  2. One sentence on the single strongest evidence match (one project, one quantification).
  3. One sentence asking for the next step (15-minute call / hiring manager intro / link to portfolio).
- **No filler:** no "Hope you're doing well," no "I came across your profile and was impressed," no closing pleasantries beyond a single "Thanks,\n<Name>".
- **Humanizer + no-fabrication same as cover letter.**

### 11f. Final write

`recommendations.md` lives at `$OUTDIR/recommendations.md`. Markdown only, no LaTeX, no special escaping. Section order: gap report → unresolved findings (if present) → cover letter (if written) → outreach (if written). Each section a `## H2`.

---

## 12. `run.json` snapshot

```jsonc
{
  "run_id": "{company-slug}_{role-slug}_{YYYYMMDD_HHMMSS}",
  "timestamp": "ISO8601",
  "jd": { "title": "", "company": "", "location": "", "source_path": "", "source_url": "" },
  "target_score": 85,
  "final": { "ats_score": 100, "jd_score": 57, "pages": 2 },
  "selected_modules": ["experience[0].bullets[0]", "projects[0]", "projects[1]", ...],
  "iterations": [
    { "i": 1, "verify_ok": true, "ats_score": 72, "jd_score": 39, "ats_fails": 1, "missing": 5, "weak": 3 },
    { "i": 2, "verify_ok": true, "ats_score": 100, "jd_score": 57, "ats_fails": 0, "missing": 1, "weak": 0 }
  ],
  "shipped": { "i": 2, "reason": "accept_gate_passed" },
  "unresolved": { "missing": [], "weak_requirements": [] }
}
```

`shipped.reason` is one of: `accept_gate_passed`, `best_effort_on_genuine_gaps`, `stuck_no_improvement`.

---

## 13. Non-negotiables

1. **No fabrication.** Every fact on the PDF must trace to `profile.json`. If a JD demand has no profile evidence, it goes to `recommendations.md` as a gap, NEVER as a résumé bullet.
2. **Verification + scorer gates.** PDF only ships after passing both. On best-effort exhaustion, ship best + log unresolved.
3. **Humanizer at write time.** Apply `$ENGINE/references/blacklist.md` BEFORE writing each line. Scorer flags should be rare.

## 14. Failure modes

- **Tectonic not found / fails to install package** → halt with reproduction command + suggest `/resume-engine-setup` re-run.
- **JD too short** (< 50 words) → halt: "JD seems incomplete; paste the full posting or give me a path to a fuller file."
- **profile.json empty / missing essential fields** → halt: "Profile lacks identity/email — run `/profile-build` first."
- **All iterations score below 50** → still ship best, but cover letter section advises against applying without addressing the largest gaps first.
