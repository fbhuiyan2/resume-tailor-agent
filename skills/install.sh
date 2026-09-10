#!/usr/bin/env bash
# Install the resume-engine slash commands so they work from ANY directory,
# in both Claude Code and OpenCode.
#
#   bash skills/install.sh
#
# Idempotent. Re-run after pulling to pick up playbook changes.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="$(cd "$HERE/.." && pwd)"   # HERE is skills/, so ENGINE is the repo root
# ~/.claude/skills is the ONLY place skills are installed, and that is correct
# for both tools: OpenCode auto-loads ~/.claude/skills/<name>/SKILL.md as
# "external skills" unless disableClaudeCodeSkills or disableExternalSkills is
# set in its config (verified in opencode 1.18.29). Installing a second copy
# under ~/.config/opencode/skills/ makes OpenCode log "duplicate skill name"
# and one copy shadows the other. Do not add a second root.
CLAUDE_SKILLS="$HOME/.claude/skills"
OPENCODE_CMD="$HOME/.config/opencode/command"

SKILLS=(tailor profile-build resume-engine-setup)
MARKER=".installed-by-resume-tailor-agent"   # ownership marker, see the backup check below

# Pre-flight: verify every source exists BEFORE touching anything installed,
# so a missing source cannot leave a skill deleted and not replaced.
for s in "${SKILLS[@]}"; do
  [ -f "$HERE/$s/SKILL.md" ] || { echo "ERROR: missing $HERE/$s/SKILL.md - aborting, nothing changed" >&2; exit 1; }
done

echo "Installing skills -> $CLAUDE_SKILLS"
mkdir -p "$CLAUDE_SKILLS"
for s in "${SKILLS[@]}"; do
  target="$CLAUDE_SKILLS/$s"
  staging="$CLAUDE_SKILLS/.$s.new.$$"

  # These are generic names. If a skill of the same name exists and was not
  # installed by us, back it up rather than silently destroying it.
  # Ownership is decided by a marker file we drop in below. The grep is only
  # a grandfather clause for installs made before the marker existed - do not
  # rely on it, since a clone in a directory not named "resume-tailor-agent"
  # leaves no such string in every SKILL.md.
  if [ -d "$target" ] \
     && [ ! -f "$target/$MARKER" ] \
     && ! grep -q "resume-tailor-agent" "$target/SKILL.md" 2>/dev/null; then
    backup="$target.bak.$(date +%Y%m%d%H%M%S)"
    echo "  NOTE: existing $s/ is not ours - backing up to $(basename "$backup")"
    mv "$target" "$backup"
  fi

  rm -rf "$staging"
  cp -r "$HERE/$s" "$staging"

  # Bake the engine's absolute path in so the skills need no env vars.
  # Done in Python, not sed: an engine path containing | & or \ silently
  # corrupts a sed substitution, and BSD/macOS sed -i needs a suffix arg.
  python3 - "$staging/SKILL.md" "$ENGINE" <<'SUBST'
import sys, pathlib
f = pathlib.Path(sys.argv[1])
f.write_text(f.read_text().replace("__ENGINE_PATH__", sys.argv[2]))
SUBST

  printf '%s\n' "$ENGINE" > "$staging/$MARKER"

  rm -rf "$target"
  mv "$staging" "$target"
  echo "  /$s"
done

echo "Installing OpenCode command shims -> $OPENCODE_CMD"
mkdir -p "$OPENCODE_CMD"
shim() {
  cat > "$OPENCODE_CMD/$1.md" <<SHIM
---
description: $2
---
Invoke the \`$1\` skill and follow it exactly. Arguments: \$ARGUMENTS
SHIM
  echo "  /$1"
}
shim tailor "Tailor a resume + cover letter to a job description (resume-tailor-agent)"
shim profile-build "Build or update profile.json"
shim resume-engine-setup "Bootstrap the resume-tailor-agent binaries (open-ATS scorer + Tectonic)"

echo
echo "Engine path baked in: $ENGINE"
echo "Re-run this script if you move or re-clone the repo."
echo
echo "Next:"
echo "  /resume-engine-setup   fetch the binaries (gitignored, per-machine)"
echo "  /profile-build         build profile.json"
echo "  /tailor                tailor to a job description"
