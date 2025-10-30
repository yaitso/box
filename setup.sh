#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

start_time=$(date +%s)
TMPFILE=${TMPFILE:-$(mktemp)}
trap 'rm -f "$TMPFILE"' EXIT

log() { echo "[setup] $*"; }

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
  local p=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  # shellcheck disable=SC1090
  [ -f "$p" ] && . "$p"
}

install_nix_if_missing() {
  if ! has_cmd nix; then
    log "installing nix"
    curl --proto '=https' --tlsv1.2 -sSf -L \
      https://install.determinate.systems/nix | sh -s -- install --no-confirm
    source_nix_daemon_if_present
    log "nix installed"
  fi
}

load_env_overrides_and_emit_env_nix() {
  [ -f .env ] && source .env
  # shellcheck disable=SC1090
  [ -f .env."$OS" ] && source .env."$OS"

  BOX_USERNAME="${BOX_USERNAME:-yaitso}"
  BOX_FULLNAME="${BOX_FULLNAME:-Yai Tso}"
  BOX_EMAIL="${BOX_EMAIL:-root@yaitso.com}"

  ENV_NIX_CONTENT=$(
    cat <<EOF
{
  username = "$BOX_USERNAME";
  fullname = "$BOX_FULLNAME";
  email = "$BOX_EMAIL";
}
EOF
  )

  if [ ! -f env.nix ] || [ "$(cat env.nix)" != "$ENV_NIX_CONTENT" ]; then
    log "generating env.nix"
    printf '%s\n' "$ENV_NIX_CONTENT" >env.nix
  fi
}

stage_env_nix_if_git_repo() {
  [ -d .git ] && [ -f env.nix ] && git add -f env.nix || true
}

run_and_capture_or_die() {
  # usage: run_and_capture_or_die "human friendly label" "actual command as string"
  # silencing eval-related nits is intentional to keep main flow DRY
  # shellcheck disable=SC2086,SC2016
  local label=$1 cmd=$2
  # shellcheck disable=SC2086,SC2016
  if ! eval "$cmd" &>"$TMPFILE"; then
    cat "$TMPFILE"
    log "failed: $label"
    exit 1
  fi
}

apply_system_configuration_for_current_os() {
  log "building system configuration for $OS"
  if [ "$OS" = "macos" ]; then
    if has_cmd darwin-rebuild; then
      run_and_capture_or_die \
        "darwin-rebuild switch" \
        "sudo -H -E darwin-rebuild switch --flake .#macos"
    else
      run_and_capture_or_die \
        "nix run nix-darwin switch" \
        "sudo -H -E nix --extra-experimental-features 'nix-command flakes' run nix-darwin -- switch --flake .#macos"
    fi
  else
    if has_cmd home-manager; then
      run_and_capture_or_die \
        "home-manager switch" \
        "home-manager switch --flake .#linux"
    else
      run_and_capture_or_die \
        "nix run home-manager switch" \
        "nix --extra-experimental-features 'nix-command flakes' run home-manager -- switch --flake .#linux"
    fi
  fi
}

configure_default_shell_and_hostname_on_linux() {
  is_linux || return 0
  if has_cmd nu; then
    log "configuring nushell as default shell"
    sudo hostnamectl set-hostname "$HOSTNAME"
    local nu_path
    nu_path=$(command -v nu)
    grep -qxF "$nu_path" /etc/shells || echo "$nu_path" | sudo tee -a /etc/shells >/dev/null
    sudo chsh -s "$nu_path" "$USER"
  fi
}

install_git_hook_and_unstage_env_nix() {
  [ -d .git ] || return 0
  log "installing git precommit hook"
  mkdir -p .git/hooks
  ln -sf "$PWD/script/precommit.nu" .git/hooks/pre-commit
  log "cleaning up env.nix from staging"
  git reset HEAD env.nix >/dev/null 2>&1 || true
}

# ——— main flow (prose-like, minimal branching) ———
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
