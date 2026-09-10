# Security Policy

## Scope

This repo is plain Markdown playbooks + a LaTeX template + two bundled binaries fetched by `/resume-engine-setup`. There's no server, no auth, no network calls at runtime (after `/resume-engine-setup` + Tectonic's first-run package cache).

Security-relevant concerns in scope:

- **Profile data leakage.** `profile.json` is gitignored — but if any playbook ever writes profile contents into a tracked file or a network request, that's a bug. Report it.
- **Command injection via JD.** `/tailor` reads JD text and shells out. If a crafted JD can cause arbitrary command execution, report it.
- **LaTeX-side injection.** If a profile field can be crafted to escape the template and execute shell-escape commands during Tectonic compile, report it.
- **Supply chain.** If a `/resume-engine-setup` download URL can be tricked into fetching a different binary, report it.

Out of scope:

- Vulnerabilities in the bundled binaries themselves (`tool`, `tectonic`) — report those upstream: [open-ATS](https://github.com/NoahMustafa/open-ATS/security) and [tectonic-typesetting/tectonic](https://github.com/tectonic-typesetting/tectonic/security).
- Output PDFs being parseable by an attacker who already has the file.
- Issues in the user's agentic LLM tool.

## Reporting

Email <fbhuiyan@anl.gov> with:

- A short description of the issue.
- Repro steps (a sample profile / JD if relevant — strip your real personal data first).
- What you think the impact is.

No PGP, no bug bounty, no SLA. This is a side project. I'll acknowledge within a week and patch as soon as I can verify.

Issues in the original upstream project belong at [NoahMustafa/open-resume-agent](https://github.com/NoahMustafa/open-resume-agent/security), not here.

**Don't open a public issue for security bugs.** Anything else is fine in [Issues](../../issues).

## Supported versions

`main`. There are no release branches yet.
