#!/usr/bin/env bash
# Fedora compatibility installer for https://github.com/Blapples/SekaiPop
# Unofficial; not affiliated with the SekaiPop author.
# SPDX-License-Identifier: GPL-3.0-or-later
set -Eeuo pipefail

REPO_URL='https://github.com/Blapples/SekaiPop.git'
DRY=0 YES=0 FEATURES=1 FONTS=1 SERVICES=1
SOURCE='' HYPR_MODE=auto COPR='' NO_INSTALL=0

usage() {
  cat <<'HELP'
SekaiPop Fedora installer (unofficial)
Usage: ./install-sekaipop-fedora.sh [options]

  --dry-run                Show intended actions; make no changes
  --yes                    Pass -y to dnf and upstream installer
  --source DIR             Use an existing SekaiPop checkout instead of cloning
  --hypr auto|full|merge|skip
                           Auto: merge existing config, full on fresh install
  --enable-copr            Explicitly enable ashbuk/Hyprland-Fedora COPR
  --copr REPO              ashbuk/Hyprland-Fedora or nett00n/hyprland
  --no-features            Install only core dependencies (less functionality)
  --no-fonts               Do not download Google Sans Flex / Material Symbols
  --no-services            Do not enable systemd services
  --no-packages            Install/copy SekaiPop only; don't use dnf
  --help                   Print this help

Requirements: Fedora 44/45, non-root sudo user, network access (unless --source),
Hyprland >= 0.55 for the upstream full Lua config, Quickshell, Qt >= 6.7.
No third-party COPR is enabled without an explicit --enable-copr/--copr.
HELP
}

error() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
info() { printf '\n==> %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
run() {
  if (( DRY )); then printf '    [dry-run]'; printf ' %q' "$@"; printf '\n';
  else "$@"; fi
}
ver_ge() { [[ $(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1) == "$2" ]]; }

while (($#)); do
  case "$1" in
    --dry-run) DRY=1 ;;
    --yes|-y) YES=1 ;;
    --source) (($# >= 2)) || error '--source needs a path'; SOURCE=$2; shift ;;
    --hypr) (($# >= 2)) || error '--hypr needs a mode'; HYPR_MODE=$2; shift
      ;;
    --enable-copr) COPR='ashbuk/Hyprland-Fedora' ;;
    --copr) (($# >= 2)) || error '--copr needs a repository'; COPR=$2; shift ;;
    --no-features) FEATURES=0 ;;
    --no-fonts) FONTS=0 ;;
    --no-services) SERVICES=0 ;;
    --no-packages) NO_INSTALL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) error "Unknown argument: $1 (see --help)" ;;
  esac
  shift
done
case "$HYPR_MODE" in auto|full|merge|skip) ;; *) error 'Invalid --hypr mode' ;; esac
case "$COPR" in ''|ashbuk/Hyprland-Fedora|nett00n/hyprland) ;; *) error 'Unsupported COPR; use one of the two documented repositories' ;; esac

[[ "$(id -u)" != 0 ]] || error 'Run as your normal desktop user, not root.'
[[ -n "${HOME:-}" ]] || error 'HOME is not set.'
[[ "$HOME" != /root ]] || error 'Do not use sudo to invoke this installer.'
if [[ ! -r /etc/fedora-release ]]; then
  (( DRY )) && warn 'Not on Fedora; simulated dry-run only.' || error 'Only Fedora is supported.'
fi
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ ${ID:-} == fedora && ${VERSION_ID:-} =~ ^[0-9]+$ ]]; then
    if (( VERSION_ID < 44 )); then
      (( DRY )) && warn 'Fedora older than 44 may not have Quickshell in official repos.' || error 'Fedora 44+ required by this helper.'
    fi
  fi
fi
have sudo || { (( DRY )) && warn 'sudo unavailable (dry-run continues)' || error 'sudo is required'; }
have dnf || { (( DRY )) && warn 'dnf unavailable (dry-run continues)' || error 'dnf is required'; }

CFG=${XDG_CONFIG_HOME:-$HOME/.config}
HYPR_DIR="$CFG/hypr"
CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/sekaipop-fedora
QS_DIR="$CFG/quickshell/sekaipop"
TS=$(date +%Y%m%d-%H%M%S)
DNF=(sudo dnf)
(( YES )) && DNF+=(-y)

if [[ $HYPR_MODE == auto ]]; then
  if [[ -f "$HYPR_DIR/hyprland.lua" || -f "$HYPR_DIR/hyprland.conf" ]]; then
    HYPR_MODE=merge
  else
    HYPR_MODE=full
  fi
fi
info "Fedora SekaiPop: Hyprland mode=$HYPR_MODE; features=$FEATURES; dry-run=$DRY"
# Existing-Hyprland safe mode: check compatibility before touching packages.
# This prevents a good Fedora 44 desktop from being modified when the installed
# compositor cannot meet the documented upstream requirement.
if [[ $HYPR_MODE == skip ]]; then
  info 'Preserve the existing Hyprland configuration (--hypr skip)'
  if (( DRY )); then
    info 'Would verify installed Hyprland >= 0.55 before making changes'
  else
    have Hyprland || error 'Hyprland was not found. Do not use --hypr skip for a fresh install.'
    existing_hv=$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)
    [[ -n $existing_hv ]] || error 'Cannot determine the installed Hyprland version.'
    ver_ge "$existing_hv" '0.55' || error "Installed Hyprland $existing_hv is older than SekaiPop's requirement (0.55). Do not enable a COPR blindly: plan the compositor upgrade first."
    info "Existing Hyprland $existing_hv: version requirement met"
  fi
fi
[[ -z $COPR ]] || info "Requested third-party COPR: $COPR (not an official Fedora repository)"

# Core packages have concrete Fedora package names. A missing core package stops setup.
CORE=(
  quickshell qt6-qtbase qt6-qtdeclarative qt6-qtmultimedia qt6-qtsvg
  qt6-qtimageformats qt6-qtwayland qt6-qtshadertools qt6-qt5compat
  dbus-daemon polkit mesa-dri-drivers pipewire pipewire-pulseaudio wireplumber
  NetworkManager bluez upower libnotify wl-clipboard
  jq curl git xdg-utils xdg-user-dirs fontconfig python3 python3-numpy
)
# Noncritical desktop features: absent packages are reported and skipped.
FEATURE_PACKAGES=(
  matugen dconf glib2 cava easyeffects playerctl
  grim slurp swappy tesseract tesseract-langpack-eng ImageMagick
  wf-recorder cliphist wtype brightnessctl ddcutil zenity kitty blueman
  libcanberra sound-theme-freedesktop
  xorg-x11-server-Xwayland xdg-desktop-portal xdg-desktop-portal-gtk
  gvfs adwaita-icon-theme google-noto-sans-fonts google-noto-sans-cjk-fonts
  google-noto-emoji-fonts gnome-keyring libsecret pipewire-alsa
  thunar qt6ct
)
# Some packages may be available only in a third-party COPR or newer releases.
EXTRA_PACKAGES=(hypridle hyprlock hyprsunset hyprpicker xdg-desktop-portal-hyprland)

if (( ! NO_INSTALL )); then
  info 'Install Fedora core dependencies'
  if (( DRY )); then
    run "${DNF[@]}" install "${CORE[@]}"
  else
    "${DNF[@]}" install "${CORE[@]}" || error 'Core dependency installation failed. Check dnf output above.'
  fi

  if [[ -n $COPR ]]; then
    info "Enable third-party COPR $COPR (explicitly requested)"
    run "${DNF[@]}" install dnf5-plugins
    run "${DNF[@]}" copr enable "$COPR"
  fi

  # Fedora 44 may lack Hyprland entirely in the official repositories.
  if [[ $HYPR_MODE != skip ]]; then
    info 'Install or verify Hyprland'
    if (( DRY )); then
      run "${DNF[@]}" install hyprland
    elif ! have Hyprland; then
      if [[ -z $COPR ]]; then
        error 'Hyprland is absent. Re-run with --enable-copr (third-party) or install >=0.55 yourself.'
      fi
      "${DNF[@]}" install hyprland || error 'Hyprland install failed.'
    elif [[ -n $COPR ]]; then
      "${DNF[@]}" upgrade hyprland || warn 'Hyprland upgrade did not succeed; version check follows.'
    fi
  fi

  if (( FEATURES )); then
    info 'Install common optional desktop tools (missing packages will be skipped)'
    if (( DRY )); then
      run "${DNF[@]}" install "${FEATURE_PACKAGES[@]}" "${EXTRA_PACKAGES[@]}"
    else
      # Install noncritical packages individually so a package name missing in
      # a given Fedora release never prevents unrelated features from working.
      for pkg in "${FEATURE_PACKAGES[@]}" "${EXTRA_PACKAGES[@]}"; do
        rpm -q "$pkg" >/dev/null 2>&1 && continue
        "${DNF[@]}" install "$pkg" >/dev/null 2>&1 || warn "Not available/installable: $pkg"
      done
    fi
  fi
fi

if [[ $HYPR_MODE != skip ]]; then
  if (( ! DRY )); then
    have Hyprland || error 'Hyprland missing.'
    # Prefer compositor version output, not an unrelated library's version.
    hv=$(Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)
    [[ -n $hv ]] || error 'Cannot determine Hyprland version. Requires >=0.55.'
    ver_ge "$hv" '0.55' || error "Hyprland $hv is too old; requires >=0.55."
    info "Hyprland $hv (compatible config version)"
    have qs || error 'Quickshell executable qs is missing.'
  else
    info 'Would check Hyprland >= 0.55 and Quickshell executable qs'
  fi
fi

if [[ -n $SOURCE ]]; then
  SOURCE=${SOURCE%/}
  [[ -f "$SOURCE/install.sh" && -f "$SOURCE/sekaipop/shell.qml" ]] || error "Invalid SekaiPop checkout: $SOURCE"
  SOURCE=$(cd "$SOURCE" && pwd)
else
  SOURCE="$CACHE/SekaiPop"
  info "Fetch source: $REPO_URL"
  if (( DRY )); then
    info "Would clone/pull in $SOURCE"
  else
    have git || error 'git is unavailable.'
    mkdir -p "$CACHE"
    if [[ -d "$SOURCE/.git" ]]; then
      git -C "$SOURCE" pull --ff-only || error 'Cannot fast-forward existing checkout; local edits are preserved.'
    elif [[ -e $SOURCE ]]; then
      error "Source destination exists and isn't a git clone: $SOURCE"
    else
      git clone --depth 1 "$REPO_URL" "$SOURCE" || error 'Could not clone SekaiPop.'
    fi
  fi
fi

if (( FONTS )); then
  info 'Install fonts for SekaiPop (per-user, no root required)'
  FONTPATH="$HOME/.local/share/fonts/sekaipop"
  SYMBOLS_URL='https://raw.githubusercontent.com/google/material-design-icons/master/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf'
  if (( DRY )); then
    run mkdir -p "$FONTPATH"
    run curl -fL --retry 2 "$SYMBOLS_URL" -o "$FONTPATH/MaterialSymbolsRounded.ttf"
    info 'Would clone end-4/google-sans-flex and copy its TTF/OTF files'
  else
    mkdir -p "$FONTPATH"
    if ! fc-list 2>/dev/null | grep -qi 'Material Symbols Rounded'; then
      curl -fL --retry 2 "$SYMBOLS_URL" -o "$FONTPATH/MaterialSymbolsRounded.ttf.part" \
        && mv "$FONTPATH/MaterialSymbolsRounded.ttf.part" "$FONTPATH/MaterialSymbolsRounded.ttf" \
        || { rm -f "$FONTPATH/MaterialSymbolsRounded.ttf.part"; warn 'Could not download Material Symbols Rounded font.'; }
    fi
    if ! fc-list 2>/dev/null | grep -qi 'Google Sans Flex'; then
      font_tmp=$(mktemp -d)
      if git clone --depth 1 https://github.com/end-4/google-sans-flex.git "$font_tmp/repo"; then
        font_count=0
        while IFS= read -r -d '' font; do
          cp "$font" "$FONTPATH/$(basename "$font")" && ((font_count+=1))
        done < <(find "$font_tmp/repo" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0)
        ((font_count > 0)) || warn 'Google Sans Flex repository contained no TTF/OTF files.'
      else
        warn 'Google Sans Flex download failed; using system font fallback.'
      fi
      rm -rf -- "$font_tmp"
    fi
    fc-cache -f >/dev/null || warn 'fc-cache failed.'
  fi
fi

if (( SERVICES )); then
  info 'Enable baseline system services (failures are non-fatal)'
  for svc in NetworkManager bluetooth; do
    run sudo systemctl enable --now "$svc" || warn "Could not enable $svc"
  done
  if (( DRY )); then
    run systemctl --user enable --now pipewire pipewire-pulse wireplumber
  elif [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} || -S ${XDG_RUNTIME_DIR:-/nonexistent}/bus ]]; then
    systemctl --user enable --now pipewire pipewire-pulse wireplumber \
      || warn 'Could not activate PipeWire user services; retry after login.'
  else
    warn 'No user systemd bus; PipeWire user services can be enabled after login.'
  fi
fi

info "Install SekaiPop shell and Hyprland files (mode: $HYPR_MODE)"
UPSTREAM=(bash "$SOURCE/install.sh" --no-deps)
(( YES )) && UPSTREAM+=(--yes)
# 'merge' is done by this wrapper: upstream --no-deps intentionally skips its
# session merge, which is why we invoke its safe copy-only mode instead.
if [[ $HYPR_MODE == merge ]]; then UPSTREAM+=(--hypr skip)
else UPSTREAM+=(--hypr "$HYPR_MODE"); fi
if (( DRY )); then
  run "${UPSTREAM[@]}" --dry-run
else
  [[ -f "$SOURCE/install.sh" ]] || error 'Missing upstream install.sh'
  "${UPSTREAM[@]}" || error 'Upstream install.sh failed.'
fi

merge_config() {
  local config marker session
  if [[ -f "$HYPR_DIR/hyprland.lua" ]]; then
    config="$HYPR_DIR/hyprland.lua"
    session="$HYPR_DIR/sekaipop_session.lua"
    marker='pcall(require, "sekaipop_session")'
    if (( DRY )); then
      info "Would back up $config and append $marker"
      info "Would write $session to start qs -c sekaipop on hyprland.start"
      return
    fi
    if grep -Fq "$marker" "$config"; then
      info 'Lua config already includes the SekaiPop session loader.'
      return
    fi
    if grep -Eq '(qs|quickshell)[[:space:]]+-c[[:space:]]+sekaipop' "$HYPR_DIR"/*.lua 2>/dev/null; then
      warn 'SekaiPop autostart already found in Lua config; merge not needed.'
      return
    fi
    [[ -e $session ]] && cp -p "$session" "$session.sekaipop-backup-$TS"
    cat > "$session" <<'LUA'
-- Fedora SekaiPop session glue; remove loader from hyprland.lua to disable.
hl.env('ELECTRON_OZONE_PLATFORM_HINT', 'auto')
hl.on('hyprland.start', function()
    hl.exec_cmd('dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP')
    hl.exec_cmd('qs -c sekaipop')
end)
LUA
  elif [[ -f "$HYPR_DIR/hyprland.conf" ]]; then
    config="$HYPR_DIR/hyprland.conf"
    session="$HYPR_DIR/sekaipop_session.conf"
    marker="source = $HYPR_DIR/sekaipop_session.conf"
    if (( DRY )); then
      info "Would back up $config and append $marker"
      info "Would write $session with exec-once = qs -c sekaipop"
      return
    fi
    if grep -Fq "$marker" "$config"; then
      info 'Hyprlang config already includes the SekaiPop session loader.'
      return
    fi
    if grep -Eq '(qs|quickshell)[[:space:]]+-c[[:space:]]+sekaipop' "$config"; then
      warn 'SekaiPop autostart already found in Hyprlang config; merge not needed.'
      return
    fi
    [[ -e $session ]] && cp -p "$session" "$session.sekaipop-backup-$TS"
    cat > "$session" <<'CONF'
# Fedora SekaiPop session glue; remove source line to disable.
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = qs -c sekaipop
CONF
  else
    error "--hypr merge requested but neither hyprland.lua nor hyprland.conf exists under $HYPR_DIR"
  fi
  cp -p "$config" "$config.sekaipop-backup-$TS"
  printf '\n# Added by unofficial SekaiPop Fedora installer (%s)\n%s\n' "$TS" "$marker" >> "$config"
  info "Kept backup: $config.sekaipop-backup-$TS"
}
[[ $HYPR_MODE == merge ]] && merge_config

# Upstream only detects Qt via `pacman -Q qt6-base`, so Fedora needs to do this.
info 'Check Fedora Qt shader compatibility'
if (( DRY )); then
  info 'Would rebuild shaders if Fedora Qt < 6.12 (qsb-qt6/qt6-qtshadertools)'
else
  qtver=$(rpm -q --qf '%{VERSION}\n' qt6-qtbase 2>/dev/null | head -1 || true)
  if [[ -n $qtver ]] && ! ver_ge "$qtver" '6.12'; then
    if [[ -f "$QS_DIR/shaders/compile-shaders.sh" ]]; then
      PATH="/usr/lib64/qt6/bin:/usr/bin:$PATH" \
        bash "$QS_DIR/shaders/compile-shaders.sh" \
        || error 'Qt shader recompilation failed; wallpapers may not work.'
      info "Rebuilt shaders using Fedora Qt $qtver"
    else
      warn 'Installed shell has no compile-shaders.sh; cannot rebuild shaders.'
    fi
  fi
fi

info 'Finished'
if (( DRY )); then
  echo 'Dry-run complete; nothing was modified.'
else
  echo "Installed shell: $QS_DIR"
  echo 'Log out and select the plain Hyprland session (not uwsm).'
  echo 'Manual start inside Hyprland: qs -c sekaipop'
  echo 'Diagnostics: qs -c sekaipop log; hyprctl configerrors'
  echo 'NOTE: the upstream Arch check-deps.sh output is not a Fedora package audit.'
  echo 'NOTE: Arch-only update commands and some optional widgets may still need porting.'
fi
