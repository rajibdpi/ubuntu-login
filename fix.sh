#!/usr/bin/env bash
set -euo pipefail

# Ubuntu 24.04 login-loop fixer
# Usage:
#   sudo bash fix.sh [--user rajib] [--reset-gnome]
#
# Safe: makes backups before changing user files.

RESET_GNOME=0
USER_NAME="${SUDO_USER:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      USER_NAME="${2:-}"; shift 2;;
    --reset-gnome)
      RESET_GNOME=1; shift;;
    -h|--help)
      echo "Usage: sudo bash $0 [--user <username>] [--reset-gnome]"; exit 0;;
    *)
      echo "Unknown arg: $1"; exit 1;;
  esac
done

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: run as root (use sudo)"
  exit 1
fi

detect_user() {
  # 1) Most reliable when invoked via sudo from the target account.
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]] && id "${SUDO_USER}" >/dev/null 2>&1; then
    echo "${SUDO_USER}"
    return 0
  fi

  # 2) Fallback to current login name if available.
  local ln=""
  ln="$(logname 2>/dev/null || true)"
  if [[ -n "${ln}" && "${ln}" != "root" ]] && id "${ln}" >/dev/null 2>&1; then
    echo "${ln}"
    return 0
  fi

  # 3) Last fallback: first regular local user account.
  getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $1 != "nobody" && $7 !~ /(nologin|false)$/ {print $1; exit}'
}

if [[ -z "${USER_NAME}" ]]; then
  USER_NAME="$(detect_user)"
  if [[ -z "${USER_NAME}" ]]; then
    echo "ERROR: could not auto-detect target user. Use --user <username>"
    exit 1
  fi
  echo "==> Auto-detected user: ${USER_NAME}"
fi

HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
if [[ -z "${HOME_DIR}" || ! -d "${HOME_DIR}" ]]; then
  echo "ERROR: cannot find home for user: ${USER_NAME}"
  exit 1
fi

echo "==> Fixing Ubuntu login loop for user: ${USER_NAME} (home: ${HOME_DIR})"

# 1) Ensure a sane PATH for this session
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 2) Quick disk cleanup (harmless, helps when disk is full)
echo "==> Quick cleanup (apt + journald)"
apt-get clean || true
journalctl --vacuum-time=3d || true

# 3) Fix user authority files that often cause login loop
echo "==> Fixing Xauthority/ICEauthority"
for f in ".Xauthority" ".ICEauthority"; do
  if [[ -e "${HOME_DIR}/${f}" ]]; then
    mv -f "${HOME_DIR}/${f}" "${HOME_DIR}/${f}.broken.$(date +%F_%H%M%S)" || true
  fi
done
chown -R "${USER_NAME}:${USER_NAME}" "${HOME_DIR}" || true

# 4) Backup + repair user shell PATH (common cause: PATH overwritten)
echo "==> Repairing user shell PATH files (.profile/.bashrc) with backups"
TS="$(date +%F_%H%M%S)"
for f in ".profile" ".bashrc" ".bash_profile" ".zprofile" ".zshrc"; do
  if [[ -f "${HOME_DIR}/${f}" ]]; then
    cp -a "${HOME_DIR}/${f}" "${HOME_DIR}/${f}.bak.${TS}"
  fi
done

# Ensure ~/.profile contains a safe PATH line (append; does not delete your custom lines)
grep -q 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' "${HOME_DIR}/.profile" 2>/dev/null \
  || echo 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH' >> "${HOME_DIR}/.profile"

# Ensure ~/.bashrc also has safe PATH (interactive shells)
grep -q 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' "${HOME_DIR}/.bashrc" 2>/dev/null \
  || echo 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH' >> "${HOME_DIR}/.bashrc"

chown "${USER_NAME}:${USER_NAME}" "${HOME_DIR}/.profile" "${HOME_DIR}/.bashrc" 2>/dev/null || true

# 5) Fix broken packages + reinstall GDM + GNOME session components
echo "==> Repairing packages + reinstalling gdm3/gnome-shell"
apt-get update
apt-get -f install -y || true
dpkg --configure -a || true
apt-get install --reinstall -y gdm3 gnome-shell ubuntu-session xorg

systemctl enable gdm3 || true

# 6) Optional: reset GNOME user settings (fixes bad gsettings/extensions causing loop)
if [[ "${RESET_GNOME}" -eq 1 ]]; then
  echo "==> Resetting GNOME user config (backed up)"
  for d in ".config" ".local/share" ".cache"; do
    if [[ -d "${HOME_DIR}/${d}" ]]; then
      mv "${HOME_DIR}/${d}" "${HOME_DIR}/${d}.old.${TS}"
    fi
  done
  mkdir -p "${HOME_DIR}/.cache" "${HOME_DIR}/.config" "${HOME_DIR}/.local/share"
  chown -R "${USER_NAME}:${USER_NAME}" "${HOME_DIR}"
fi

# 7) Fix PATH globally (backup first)
echo "==> Fixing global PATH (/etc/environment) with backup"
if [[ -f /etc/environment ]]; then
  cp -a /etc/environment "/etc/environment.bak.${TS}"
fi
# Keep it simple and safe:
cat > /etc/environment <<'EOF'
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF

echo "==> Done."
echo "Now reboot: sudo reboot"
