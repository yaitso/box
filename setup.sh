#!/usr/bin/env bash
set -euo pipefail
set -o pipefail

start_time=$(date +%s)

log() { echo "[setup] $*"; }

if [[ "$(uname)" == "Darwin" ]]; then
  OS="macos"
  HOSTNAME="${1:-macos}"
  if ! xcode-select -p >/dev/null 2>&1; then
    log "installing xcode command line tools"
    xcode-select --install >/dev/null 2>&1 || true
    until xcode-select -p >/dev/null 2>&1; do
      sleep 5
    done
    log "xcode command line tools installed"
  fi
else
  OS="linux"
  HOSTNAME="${1:-linux}"
fi

[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] &&
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

if ! command -v nix &>/dev/null; then
  log "installing nix"
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install --no-confirm
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  log "nix installed"
fi

[ -f .env ] && source .env
# shellcheck disable=SC1090
[ -f .env.$OS ] && source .env.$OS

export BOX_ROOT="${BOX_ROOT:-$PWD}"
export BOX_USERNAME="${BOX_USERNAME:-yaitso}"
export BOX_FULLNAME="${BOX_FULLNAME:-Yai Tso}"
export BOX_EMAIL="${BOX_EMAIL:-root@yaitso.com}"

log "building system configuration for $OS"

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

if [ "$OS" = "macos" ]; then
  # shellcheck disable=SC2024
  if ! sudo -E nix --extra-experimental-features 'nix-command flakes' \
    run nix-darwin -- switch --flake ".#macos" --impure &>"$tmpfile"; then
    cat "$tmpfile"
    exit 1
  fi
else
  # shellcheck disable=SC2024
  if ! nix --extra-experimental-features 'nix-command flakes' \
    run home-manager -- switch --flake ".#linux" --impure &>"$tmpfile"; then
    cat "$tmpfile"
    exit 1
  fi

  if command -v nu &>/dev/null; then
    log "configuring nushell as default shell"
    sudo hostnamectl set-hostname "$HOSTNAME"
    nu_path=$(command -v nu)
    grep -qxF "$nu_path" /etc/shells || echo "$nu_path" | sudo tee -a /etc/shells >/dev/null
    sudo chsh -s "$nu_path" "$USER"
  fi
fi

elapsed=$(($(date +%s) - start_time))
log "system configuration applied in ${elapsed}s"

if [ -d .git ]; then
  log "installing git precommit hook"
  mkdir -p .git/hooks
  ln -sf "$BOX_ROOT/script/precommit.nu" .git/hooks/pre-commit
fi
