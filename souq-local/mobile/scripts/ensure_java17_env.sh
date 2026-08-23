#!/usr/bin/env bash
# Source from lab/start scripts so Flutter and Gradle use JDK 17 without manual exports.
# Usage: source mobile/scripts/ensure_java17_env.sh

_ensure_java17_env() {
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    local ver
    ver="$("${JAVA_HOME}/bin/java" -version 2>&1 | head -n1 || true)"
    if [[ "$ver" == *"17"* ]]; then
      export PATH="$JAVA_HOME/bin:$PATH"
      return 0
    fi
  fi

  local candidate=""
  for candidate in \
    /usr/lib/jvm/java-17-openjdk-amd64 \
    /usr/lib/jvm/java-17-openjdk \
    /usr/lib/jvm/java-17-amazon-corretto \
    /usr/lib/jvm/temurin-17-jdk \
    /usr/lib/jvm/temurin-17-jdk-amd64 \
    /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
    /Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home; do
    if [[ -x "$candidate/bin/java" ]]; then
      JAVA_HOME="$candidate"
      export JAVA_HOME
      export PATH="$JAVA_HOME/bin:$PATH"
      return 0
    fi
  done

  if command -v java >/dev/null 2>&1; then
    local java_bin java_home
    java_bin="$(command -v java)"
    java_home="$(readlink -f "$java_bin" 2>/dev/null || true)"
    if [[ -n "$java_home" ]]; then
      JAVA_HOME="$(dirname "$(dirname "$java_home")")"
      export JAVA_HOME
      export PATH="$JAVA_HOME/bin:$PATH"
      return 0
    fi
  fi

  echo "WARNING: JDK 17 not found. Install: sudo apt install openjdk-17-jdk" >&2
  return 1
}

_ensure_java17_env
