#!/usr/bin/env bash
# Link this repo into $HOME with GNU Stow. Does not install packages.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${HOME}"
STOW_FLAGS=(-d "$REPO" -t "$TARGET")

# Each directory is a Stow package. App configs live at <pkg>/.config/<pkg>.
# fonts → ~/.fonts   wallpaper → ~/.wallpaper
DEFAULT_PACKAGES=(
  alacritty
  btop
  fish
  fonts
  fuzzel
  hypr
  kitty
  matugen
  micro
  noctalia
  nvim
  wallpaper
)

LEGACY_PACKAGES=(hyprpanel)

usage() {
  cat <<'EOF'
Usage: ./stow.sh [-n] [-R] [-D] [-a] [package...]

  Link configs into $HOME with GNU Stow. No pacman/apt installs.

  (no args)   stow the default packages (nvim, hypr, fish, …)
  nvim fish   stow only those packages
  -R          restow (unstow + stow)
  -D          unstow / remove the links
  -n          dry run
  -a          include legacy packages (hyprpanel)

Packages live in this repo as:

  nvim/.config/nvim
  hypr/.config/hypr
  fonts/.fonts
  wallpaper/.wallpaper
EOF
}

need_stow() {
  if ! command -v stow >/dev/null 2>&1; then
    echo "stow not found. Install GNU Stow only (e.g. pacman -S stow). No other packages are required for linking." >&2
    exit 1
  fi
}

# Drop dangling or pre-stow whole-dir links so Stow can fold into ~/.config.
clear_stale_link() {
  local dest="$1"
  [[ -L "$dest" ]] || return 0
  if [[ ! -e "$dest" ]]; then
    rm "$dest"
  fi
}

ACTION=(-S)
PACKAGES=()
WITH_LEGACY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    -n | --no | --simulate)
      STOW_FLAGS+=(-n -v)
      shift
      ;;
    -v | --verbose)
      STOW_FLAGS+=(-v)
      shift
      ;;
    -R | --restow)
      ACTION=(-R)
      shift
      ;;
    -D | --delete | --unstow)
      ACTION=(-D)
      shift
      ;;
    -a | --all | --legacy)
      WITH_LEGACY=1
      shift
      ;;
    --)
      shift
      PACKAGES+=("$@")
      break
      ;;
    -*)
      echo "unknown flag: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      PACKAGES+=("$1")
      shift
      ;;
  esac
done

need_stow
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  PACKAGES=("${DEFAULT_PACKAGES[@]}")
  if [[ "$WITH_LEGACY" -eq 1 ]]; then
    PACKAGES+=("${LEGACY_PACKAGES[@]}")
  fi
fi

for pkg in "${PACKAGES[@]}"; do
  if [[ ! -d "$REPO/$pkg" ]]; then
    echo "not a stow package: $pkg" >&2
    exit 1
  fi
  clear_stale_link "$TARGET/.config/$pkg"
done
clear_stale_link "$TARGET/.fonts"
clear_stale_link "$TARGET/.wallpaper"

cd "$REPO"
stow "${STOW_FLAGS[@]}" "${ACTION[@]}" "${PACKAGES[@]}"
echo "stow ${ACTION[*]} → $TARGET: ${PACKAGES[*]}"
