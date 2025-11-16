#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

start_time=$(date +%s)
TMPFILE=${TMPFILE:-$(mktemp)}
VERBOSE_MODE=false

cleanup() {
  rm -f "$TMPFILE"
}

trap cleanup EXIT INT TERM

log() { echo "[setup] $*"; }
die() {
  log "error: $*"
  exit 1
}

is_macos() { [[ "$(uname)" == "Darwin" ]]; }
is_linux() { [[ "$(uname)" == "Linux" ]]; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

determine_os_and_hostname() {
  if is_macos; then
    OS="macos"
    HOSTNAME="${1:-macos}"
  else
    OS="linux"
    HOSTNAME="${1:-linux}"
  fi
}

ensure_xcode_clt_if_macos() {
  is_macos || return 0
  if ! xcode-select -p >/dev/null 2>&1; then
    log "installing xcode command line tools"
    xcode-select --install >/dev/null 2>&1 || true
    until xcode-select -p >/dev/null 2>&1; do sleep 5; done
    log "xcode command line tools installed"
  fi
}

source_nix_daemon_if_present() {
  local daemon_sh="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
  local profile_sh="$HOME/.nix-profile/etc/profile.d/nix.sh"

  # shellcheck disable=SC1090
  if [[ -f $daemon_sh ]]; then
    . "$daemon_sh"
  elif [[ -f $profile_sh ]]; then
    . "$profile_sh"
  fi
}

install_nix_if_missing() {
  has_cmd nix && return 0

  log "installing nix"
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install --no-confirm

  source_nix_daemon_if_present

  has_cmd nix || die "nix installation failed or not in PATH"
  log "nix installed successfully"
}

load_env_overrides_and_emit_env_nix() {
  # shellcheck disable=SC1091
  [[ -f .env ]] && source .env
  # shellcheck disable=SC1091,SC1090
  [[ -f ".env.$OS" ]] && source ".env.$OS"

  local username="${BOX_USERNAME:-yaitso}"

  local env_nix_content="{
  username = \"$username\";
}"

  if [[ ! -f env.nix ]] || [[ "$(cat env.nix)" != "$env_nix_content" ]]; then
    log "generating env.nix"
    printf '%s\n' "$env_nix_content" >env.nix
  fi
}

stage_env_nix_if_git_repo() {
  [[ -d .git ]] && [[ -f env.nix ]] && git add -f env.nix 2>/dev/null || true
}

run_and_capture_or_die() {
  local label="$1"
  local cmd="$2"

  if [[ "$VERBOSE_MODE" == "true" ]]; then
    # shellcheck disable=SC2086
    eval "$cmd" || die "$label"
  else
    # shellcheck disable=SC2086
    if ! eval "$cmd" &>"$TMPFILE"; then
      cat "$TMPFILE"
      die "$label"
    fi
  fi
}

run_native_or_nix() {
  local native_cmd="$1"
  local nix_package="$2"
  local args="$3"
  local sudo_prefix="${4:-}"

  if has_cmd "$native_cmd"; then
    run_and_capture_or_die \
      "$native_cmd $args" \
      "$sudo_prefix $native_cmd $args"
  else
    run_and_capture_or_die \
      "nix run $nix_package $args" \
      "$sudo_prefix nix --extra-experimental-features 'nix-command flakes' run $nix_package -- $args"
  fi
}

apply_system_configuration_for_current_os() {
  log "building system configuration for $OS"

  case "$OS" in
  macos)
    run_native_or_nix \
      "darwin-rebuild" \
      "nix-darwin" \
      "switch --flake .#macos" \
      "sudo -H -E"
    ;;
  linux)
    run_native_or_nix \
      "home-manager" \
      "home-manager" \
      "switch --flake .#linux" \
      ""
    ;;
  *)
    die "unsupported OS: $OS"
    ;;
  esac
}

configure_default_shell_and_hostname_on_linux() {
  is_linux || return 0
  has_cmd nu || return 0

  log "configuring nushell as default shell"
  sudo hostnamectl set-hostname "$HOSTNAME"

  local nu_path
  nu_path=$(command -v nu)

  grep -qxF "$nu_path" /etc/shells || echo "$nu_path" | sudo tee -a /etc/shells >/dev/null
  sudo chsh -s "$nu_path" "$USER"
}

install_git_hook_and_unstage_env_nix() {
  [[ -d .git ]] || return 0

  log "installing git precommit hook"
  mkdir -p .git/hooks
  ln -sf "$PWD/script/precommit.nu" .git/hooks/pre-commit

  log "cleaning up env.nix from staging"
  git reset HEAD env.nix >/dev/null 2>&1 || true
}

validate_environment() {
  cd "$SCRIPT_DIR" || die "cannot cd to $SCRIPT_DIR"
  [[ -f "setup.sh" ]] || die "setup.sh must be run from box directory"

  for arg in "$@"; do
    [[ "$arg" == "--verbose" ]] && VERBOSE_MODE=true
  done
}

#================================#
validate_environment "$@"
determine_os_and_hostname "${1:-}"
ensure_xcode_clt_if_macos
source_nix_daemon_if_present
install_nix_if_missing
load_env_overrides_and_emit_env_nix
stage_env_nix_if_git_repo
apply_system_configuration_for_current_os
configure_default_shell_and_hostname_on_linux

elapsed=$(($(date +%s) - start_time))
log "system configuration applied in ${elapsed}s"
install_git_hook_and_unstage_env_nix
