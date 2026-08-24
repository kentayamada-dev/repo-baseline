#!/usr/bin/env bash
#
# Deletes the files that belong to this template itself, leaving only what a
# repository created from it keeps using: the workflows, the ruleset, the setup
# script, the issue and PR templates, and the tool configuration.
#
# A repository with no README at all is worse than one with a placeholder, so a
# stub holding the repository name is written in place of the deleted README. That
# is the only thing written; nothing stands in for the rest.
#
# LICENSE is deliberately not deleted. The parts that stay (the workflows, the
# ruleset, sync-repo-config.sh) are the licensed work, and MIT asks for the notice
# to travel with them, so replace the copyright line or the whole file instead.
#
# Mentions of the deleted paths that survive in the files that stay are listed
# before anything is deleted, to be rewritten by hand. Only mentions that spell the
# path out are found; prose such as "see the README" is not.
#
# Only tracked files are deleted, with one exception: .claude is removed
# wholesale, so untracked local files under it (for example
# .claude/settings.local.json) go with it. Elsewhere untracked files are left
# where they are.
#
# The script deletes itself as its last act, so it runs once.
#
# Usage:
#   ./scripts/cleanup-template.sh            # list what will go, ask, then delete
#   ./scripts/cleanup-template.sh --yes      # delete without asking
#   ./scripts/cleanup-template.sh --dry-run  # only list what would go; delete nothing
#
set -euo pipefail

DRY_RUN=false
ASSUME_YES=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -y | --yes) ASSUME_YES=true ;;
    -h | --help)
      awk 'NR>1 && !/^#/{exit} NR>1{sub(/^# ?/, ""); print}' "$0"
      exit 0
      ;;
    *)
      echo "unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# "<what this group is>:<pathspec> <pathspec> ...". A directory pathspec covers
# everything tracked under it, so files added there later are picked up without
# editing the list here.
TARGET_GROUPS=(
  "Documentation about the template itself:README.md README.ja.md docs CLAUDE.md"
  "Claude Code settings, skills, and hook scripts that back CLAUDE.md:.claude"
  "Community documents written for this repository:CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md"
  "This script:scripts/cleanup-template.sh"
)

# The stub written in place of the deleted README. The name comes from the origin
# remote, which is what the repository is called on GitHub; without a remote the
# directory name is the best guess available.
README_STUB=README.md
repo_name="$(basename -s .git "$(git config --get remote.origin.url || echo "$repo_root")")"

targets=()
listing=""
for group in "${TARGET_GROUPS[@]}"; do
  read -r -a pathspecs <<<"${group#*:}"
  found=()
  while IFS= read -r -d '' file; do
    found+=("$file")
    targets+=("$file")
  done < <(git ls-files -z -- "${pathspecs[@]}")
  # A group whose files are already gone is not worth a heading.
  if [[ ${#found[@]} -eq 0 ]]; then
    continue
  fi
  listing="${listing}  ${group%%:*}"$'\n'
  for file in "${found[@]}"; do
    listing="${listing}    ${file}"$'\n'
  done
done

if [[ ${#targets[@]} -eq 0 ]]; then
  echo "Nothing to delete: none of the template's own files are tracked here any more."
  exit 0
fi

# Only stand in for a README this run actually removes.
write_stub=false
for target in "${targets[@]}"; do
  if [[ "$target" == "$README_STUB" ]]; then
    write_stub=true
    break
  fi
done

# The files that stay, so they can be searched for mentions of the ones that go.
# Collected before anything is deleted, because grep needs both sides to exist.
keep=()
while IFS= read -r -d '' file; do
  kept=true
  for target in "${targets[@]}"; do
    if [[ "$file" == "$target" ]]; then
      kept=false
      break
    fi
  done
  if [[ "$kept" == true ]]; then
    keep+=("$file")
  fi
done < <(git ls-files -z)

mentions=""
if [[ ${#keep[@]} -gt 0 ]]; then
  for target in "${targets[@]}"; do
    # cut keeps file:line and drops the matched text, which is often a whole
    # sentence. -I skips anything binary.
    hits="$(grep -I -n -F -- "$target" "${keep[@]}" | cut -d: -f1,2 || true)"
    if [[ -z "$hits" ]]; then
      continue
    fi
    mentions="${mentions}  ${target}"$'\n'
    while IFS= read -r hit; do
      mentions="${mentions}    ${hit}"$'\n'
    done <<<"$hits"
  done
fi

echo "These ${#targets[@]} tracked files belong to the template and will be deleted."
echo
printf '%s' "$listing"
echo
echo "The .claude directory is removed wholesale, so untracked local files under it"
echo "(for example .claude/settings.local.json) are deleted with it."

if [[ "$write_stub" == true ]]; then
  echo
  echo "A stub ${README_STUB} holding the repository name (${repo_name}) will be written"
  echo "in place of the deleted one. Nothing stands in for the rest."
fi

if [[ -n "$mentions" ]]; then
  echo
  echo "Files that stay behind mention the paths below. Rewrite or drop them by hand."
  echo "No CI check fails on these: they are comments and runtime messages, not links."
  echo
  printf '%s' "$mentions"
fi

if [[ "$DRY_RUN" == true ]]; then
  echo "Dry run: nothing was deleted."
  exit 0
fi

if [[ "$ASSUME_YES" != true ]]; then
  if [[ ! -t 0 ]]; then
    echo "Nothing to confirm on (stdin is not a terminal). Pass --yes to delete anyway." >&2
    exit 2
  fi
  read -r -p "Delete them? [y/N] " answer
  case "$answer" in
    y | Y | yes | YES) ;;
    *)
      echo "Aborted. Nothing was deleted."
      exit 1
      ;;
  esac
fi

# Defined before the deletion so it is already parsed when the script removes itself.
print_next_steps() {
  cat <<'MSG'

Next steps
  1. Rewrite or drop the leftover mentions listed above.
  2. Fill in the README stub, and write your own CLAUDE.md if you want one.
  3. Put your own name in LICENSE, or replace the file with the license you want.
  4. Land the changes through a PR — main is protected once the setup script
     has run, so it cannot be pushed to directly.

       git switch -c chore/drop-template-files
       git add -A
       git commit -m "Remove the files that belonged to the template"
       git push -u origin HEAD
       gh pr create --title "chore: remove the files that belonged to the template"
MSG
}

# Plain rm rather than git rm: the deletions are left unstaged so they show up in
# git status alongside whatever else is in progress, and a file the user has already
# edited does not abort the run.
rm -f -- "${targets[@]}"
# .claude is deliberately removed wholesale, untracked local files included; docs
# keeps untracked leftovers, so it is only removed once the deletions emptied it.
rm -rf .claude
rmdir docs 2>/dev/null || true

echo
echo "Deleted ${#targets[@]} files."

if [[ "$write_stub" == true ]]; then
  cat >"$README_STUB" <<STUB
# ${repo_name}

<!-- What this repository is, and anything someone needs to know to work in it. -->
STUB
  echo "Wrote ${README_STUB} (a heading and a comment, for you to fill in)."
fi

print_next_steps
