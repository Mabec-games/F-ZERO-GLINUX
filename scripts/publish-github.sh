#!/usr/bin/env bash
# Publish the prepared source repository; game data/build outputs stay local.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
command -v gh >/dev/null || { echo 'Install GitHub CLI (gh) first.' >&2; exit 1; }
owner="$(gh api user --jq .login)"
[[ "$owner" == Mabec-games ]] || { echo "Expected Mabec-games account; logged in as $owner. Switch accounts with gh auth switch." >&2; exit 1; }
repo="$owner/F-ZERO-GLINUX"
# Explicit paths avoid adding disc images, builds, saves or unrelated workspace files.
git add -- .gitignore README.md GLINUX.md docs assets packaging patches scripts
if ! git diff --cached --quiet; then
    git -c user.name="$owner" -c user.email="$owner@users.noreply.github.com" \
        commit -m 'Introduce F-ZERO GLINUX launcher, Linux packages and project presentation'
fi
expected="https://github.com/$repo.git"
if git remote get-url glinux >/dev/null 2>&1; then
    actual="$(git remote get-url glinux)"
    [[ "$actual" == "$expected" ]] || { echo "Remote glinux points elsewhere: $actual" >&2; exit 1; }
fi
if ! gh repo view "$repo" --json name >/dev/null 2>&1; then
    gh repo create "$repo" --public \
        --description 'F-ZERO GX on Linux: controller-friendly SDL3 launcher, Dolphin JIT, AppImage and Flatpak previews.'
fi
if ! git remote get-url glinux >/dev/null 2>&1; then git remote add glinux "$expected"; fi
# Preserve the upstream origin and never force-push an existing repository.
git push -u glinux HEAD:main
gh repo edit "$repo" --default-branch main --add-topic f-zero-gx --add-topic linux \
    --add-topic dolphin --add-topic flatpak --add-topic appimage --add-topic sdl3
printf 'Published: https://github.com/%s\n' "$repo"
