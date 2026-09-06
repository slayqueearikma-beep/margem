#!/usr/bin/env bash
# One-time setup: persist JAVA_HOME for interactive shells (bash/zsh).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKER="# MarGem Flutter JDK 17"
BLOCK=$(cat <<EOF
$MARKER
if [[ -f "$ROOT/scripts/ensure_java17_env.sh" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/scripts/ensure_java17_env.sh" >/dev/null 2>&1 || true
fi
EOF
)

append_if_missing() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    touch "$file"
  fi
  if grep -Fq "$MARKER" "$file" 2>/dev/null; then
    echo "Already configured in $file"
    return 0
  fi
  printf '\n%s\n' "$BLOCK" >>"$file"
  echo "Added JDK 17 setup to $file (open a new terminal or run: source $file)"
}

append_if_missing "$HOME/.bashrc"
if [[ -f "$HOME/.zshrc" ]]; then
  append_if_missing "$HOME/.zshrc"
fi

echo ""
echo "Optional: set Gradle JDK in android/local.properties (gitignored):"
echo "  org.gradle.java.home=/usr/lib/jvm/java-17-openjdk-amd64"
