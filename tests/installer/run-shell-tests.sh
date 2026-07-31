#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=tests/installer/helpers.bash
. "$ROOT/helpers.bash"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

make_fixture_release
trap remove_fixture_release EXIT HUP INT TERM

run_fixture_installer >/dev/null
[ -f "$FIXTURE_HOME/.claude/agents/harness-coordinator.md" ] \
  || fail 'default target did not install Claude'
[ -f "$FIXTURE_HOME/.claude/skills/deepwind-harness-prep/SKILL.md" ] \
  || fail 'default target did not install the Claude harness skill alias'
[ -f "$FIXTURE_HOME/.codex/skills/deepwind-harness-prep/SKILL.md" ] \
  || fail 'default target did not install the Codex harness skill alias'
[ -f "$FIXTURE_HOME/.agents/skills/deepwind-harness-prep/SKILL.md" ] \
  || fail 'default target did not install the shared agent harness skill alias'
[ -f "$FIXTURE_HOME/.deepwind/install/share/codex-marketplace/plugins/deepwind-harness/.codex-plugin/plugin.json" ] \
  || fail 'default target did not install Codex'
[ -f "$FIXTURE_HOME/.deepwind/install/share/codex-marketplace/.agents/plugins/marketplace.json" ] \
  || fail 'default target did not install Codex marketplace catalog'

remove_fixture_release
make_fixture_release
if run_fixture_installer --target invalid >/dev/null 2>&1; then
  fail 'invalid target was accepted'
fi
[ ! -e "$FIXTURE_HOME/.claude" ] || fail 'invalid target mutated Claude destination'

remove_fixture_release
make_fixture_release
printf 'tampered\n' >> "$FIXTURE_RELEASE/deepwind-harness-codex-v1.2.3.tar.gz"
if run_fixture_installer >/dev/null 2>&1; then
  fail 'tampered archive was accepted'
fi
[ ! -e "$FIXTURE_HOME/.claude" ] || fail 'integrity failure mutated destination'

remove_fixture_release
make_fixture_release
jq 'del(.bootstrap)' "$FIXTURE_RELEASE/deepwind-release-manifest.json" \
  > "$FIXTURE_RELEASE/deepwind-release-manifest.json.next"
mv "$FIXTURE_RELEASE/deepwind-release-manifest.json.next" \
  "$FIXTURE_RELEASE/deepwind-release-manifest.json"
if run_fixture_installer >/dev/null 2>&1; then
  fail 'manifest without versioned bootstrap contract was accepted'
fi
[ ! -e "$FIXTURE_HOME/.claude" ] || fail 'invalid bootstrap contract mutated destination'

remove_fixture_release
make_fixture_release
run_fixture_installer --dry-run >/dev/null
[ ! -e "$FIXTURE_HOME/.deepwind" ] || fail 'dry run wrote state'

remove_fixture_release
make_fixture_release
run_fixture_installer --target claude >/dev/null
[ -f "$FIXTURE_HOME/.claude/agents/harness-coordinator.md" ] \
  || fail 'claude target did not install Claude'
[ ! -e "$FIXTURE_HOME/.codex" ] || fail 'claude target installed Codex'

remove_fixture_release
make_fixture_release
run_fixture_installer >/dev/null
printf 'user edit\n' > "$FIXTURE_HOME/.claude/agents/harness-coordinator.md"
run_fixture_installer --target claude >/dev/null
[ "$(cat "$FIXTURE_HOME/.claude/agents/harness-coordinator.md")" = 'user edit' ] \
  || fail 'locally modified file was overwritten'

remove_fixture_release
make_fixture_release
if env \
  HOME="$FIXTURE_HOME" \
  PATH="$FIXTURE_ROOT/bin:$PATH" \
  DEEPWIND_INSTALL_TESTING=1 \
  DEEPWIND_TEST_FAIL_TARGET=codex \
  DEEPWIND_RELEASE_DIR="$FIXTURE_RELEASE" \
  bash "$FIXTURE_INSTALLER" --version 1.2.3 >/dev/null 2>&1; then
  fail 'injected second-target failure succeeded'
fi
[ ! -e "$FIXTURE_HOME/.claude" ] || fail 'second-target failure did not roll back Claude'
[ ! -e "$FIXTURE_HOME/.codex" ] || fail 'second-target failure left Codex files'
[ ! -e "$FIXTURE_HOME/.deepwind" ] || fail 'second-target failure left install state'

remove_fixture_release
make_fixture_release
if env \
  HOME="$FIXTURE_HOME" \
  PATH="$FIXTURE_ROOT/bin:$PATH" \
  DEEPWIND_INSTALL_TESTING=1 \
  DEEPWIND_TEST_INTERRUPT_AFTER_MUTATIONS=1 \
  DEEPWIND_RELEASE_DIR="$FIXTURE_RELEASE" \
  bash "$FIXTURE_INSTALLER" --version 1.2.3 >/dev/null 2>&1; then
  fail 'interrupted installer exited successfully'
fi
[ ! -e "$FIXTURE_HOME/.claude" ] || fail 'interrupted installer did not roll back'
[ ! -e "$FIXTURE_HOME/.deepwind" ] || fail 'interrupted installer left state'

remove_fixture_release
make_fixture_release
printf 'BAD-SIGNATURE\n' > "$FIXTURE_RELEASE/deepwind-release-manifest.json.asc"
if run_fixture_installer >/dev/null 2>&1; then
  fail 'bad signature was accepted'
fi
[ ! -e "$FIXTURE_HOME/.claude" ] || fail 'signature failure mutated destination'

remove_fixture_release
make_fixture_release
# shellcheck disable=SC2002 # Deliberately verify the documented pipe install.
cat "$FIXTURE_INSTALLER" | env \
  HOME="$FIXTURE_HOME" \
  PATH="$FIXTURE_ROOT/bin:$PATH" \
  DEEPWIND_INSTALL_TESTING=1 \
  DEEPWIND_RELEASE_DIR="$FIXTURE_RELEASE" \
  bash -s -- --version 1.2.3 >/dev/null
[ -f "$FIXTURE_HOME/.claude/agents/harness-coordinator.md" ] \
  || fail 'standalone pipe did not install Claude'
[ -f "$FIXTURE_HOME/.codex/agents/harness-coordinator.toml" ] \
  || fail 'standalone pipe did not install Codex'

remove_fixture_release
make_fixture_release
mkdir "$FIXTURE_HOME/.claude"
ln -s "$FIXTURE_ROOT" "$FIXTURE_HOME/.claude/agents"
if run_fixture_installer --target claude >/dev/null 2>&1; then
  fail 'symlink destination was accepted'
fi
[ ! -e "$FIXTURE_ROOT/harness-coordinator.md" ] || fail 'symlink escape was written'

remove_fixture_release
make_fixture_release
mkdir "$FIXTURE_HOME/.deepwind-install.lock"
if run_fixture_installer >/dev/null 2>&1; then
  fail 'lock collision was accepted'
fi
[ ! -e "$FIXTURE_HOME/.claude" ] || fail 'lock collision mutated destination'

remove_fixture_release
make_fixture_release
run_fixture_installer >/dev/null
run_fixture_installer --check >/dev/null \
  || fail 'check reported drift after successful install'
printf 'drift\n' > "$FIXTURE_HOME/.claude/agents/harness-coordinator.md"
if run_fixture_installer --check >/dev/null 2>&1; then
  fail 'check did not report modified managed file'
fi

printf 'PASS: portable installer smoke tests\n'
