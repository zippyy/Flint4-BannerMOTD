#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/root/Flint4-BannerMOTD-backup-$TIMESTAMP"
SHELL_FALLBACK_BEGIN="# BEGIN Flint4-BannerMOTD shell fallback"
SHELL_FALLBACK_END="# END Flint4-BannerMOTD shell fallback"

backup_file()
{
    source_path="$1"

    if [ -e "$source_path" ]; then
        relative_path="${source_path#/}"
        mkdir -p "$BACKUP_DIR/$(dirname "$relative_path")"
        cp -a "$source_path" "$BACKUP_DIR/$relative_path"
    fi
}

install_file()
{
    repository_path="$1"
    destination_path="$2"
    mode="$3"

    backup_file "$destination_path"
    mkdir -p "$(dirname "$destination_path")"
    cp "$SCRIPT_DIR/$repository_path" "$destination_path"
    chmod "$mode" "$destination_path"
}

detect_package_manager()
{
    if command -v apk >/dev/null 2>&1; then
        printf '%s\n' apk
    elif command -v opkg >/dev/null 2>&1; then
        printf '%s\n' opkg
    else
        echo "ERROR: neither apk nor opkg was found." >&2
        exit 1
    fi
}

pkg_update()
{
    case "$PKG_MGR" in
        apk)
            apk update
            ;;
        opkg)
            opkg update
            ;;
    esac
}

pkg_install()
{
    case "$PKG_MGR" in
        apk)
            apk add "$@"
            ;;
        opkg)
            opkg install "$@"
            ;;
    esac
}

install_shell_fallback()
{
    rc_local=/etc/rc.local

    if [ ! -e "$rc_local" ]; then
        cat >"$rc_local" <<'EOF_RC_HEADER'
#!/bin/sh -e

exit 0
EOF_RC_HEADER
        chmod 755 "$rc_local"
    fi

    backup_file "$rc_local"

    # Keep all existing rc.local commands, remove any older copy of our guard
    # (including the original /usr/bin/zsh-specific recovery block), remove the
    # terminal exit 0, add the current guard, then restore exit 0 at the end.
    # This makes rerunning the installer both idempotent and self-updating.
    tmp_rc="/tmp/rc.local.flint4-banner.$$"
    awk -v begin="$SHELL_FALLBACK_BEGIN" -v end="$SHELL_FALLBACK_END" '
        $0 == begin { in_current = 1; next }
        in_current && $0 == end { in_current = 0; next }
        in_current { next }

        /^# Recover from missing zsh after firmware upgrade[[:space:]]*$/ {
            in_legacy = 1
            next
        }
        in_legacy && /^[[:space:]]*fi[[:space:]]*$/ {
            in_legacy = 0
            next
        }
        in_legacy { next }

        /^[[:space:]]*exit[[:space:]]+0[[:space:]]*$/ { next }
        { print }
    ' "$rc_local" >"$tmp_rc"

    cat >>"$tmp_rc" <<'EOF_SHELL_FALLBACK'

# BEGIN Flint4-BannerMOTD shell fallback
# Firmware upgrades can remove user-installed shells while preserving
# /etc/passwd. If root points to a missing shell, recover to BusyBox ash so
# SSH remains usable. Re-running the installer can then restore zsh safely.
ROOT_LOGIN_SHELL="$(awk -F: '$1 == "root" { print $7; exit }' /etc/passwd 2>/dev/null)"
if [ -n "$ROOT_LOGIN_SHELL" ] && \
   [ "$ROOT_LOGIN_SHELL" != "/bin/ash" ] && \
   [ ! -x "$ROOT_LOGIN_SHELL" ]; then
    cp -p /etc/passwd /etc/passwd.pre-shell-recovery 2>/dev/null || true
    logger -t flint4-shell-recovery \
        "root shell $ROOT_LOGIN_SHELL missing; reverting to /bin/ash"
    awk -F: -v OFS=: '
        $1 == "root" { $7 = "/bin/ash" }
        { print }
    ' /etc/passwd >/tmp/passwd.flint4-shell-recovery
    cat /tmp/passwd.flint4-shell-recovery >/etc/passwd
    rm -f /tmp/passwd.flint4-shell-recovery
    chmod 644 /etc/passwd
fi
# END Flint4-BannerMOTD shell fallback

exit 0
EOF_SHELL_FALLBACK

    cat "$tmp_rc" >"$rc_local"
    rm -f "$tmp_rc"
    chmod 755 "$rc_local"
}

echo "Installing Flint 4 Tech Relay banner and MOTD..."

echo "Backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

PKG_MGR="$(detect_package_manager)"
echo "Package manager: $PKG_MGR"

# Install only what is missing. apk is used on OpenWrt 25+; opkg remains
# supported for older GL.iNet/OpenWrt builds.
need_packages=0
command -v zsh >/dev/null 2>&1 || need_packages=1
command -v git >/dev/null 2>&1 || need_packages=1
command -v curl >/dev/null 2>&1 || need_packages=1

if [ "$need_packages" -eq 1 ]; then
    pkg_update
    pkg_install ca-certificates ca-bundle

    if ! command -v zsh >/dev/null 2>&1; then
        pkg_install zsh
    fi

    if ! command -v curl >/dev/null 2>&1; then
        pkg_install curl
    fi

    if ! command -v git >/dev/null 2>&1; then
        # OpenWrt normally exposes Git-over-HTTPS as git-http. Fall back to
        # the generic git package if a feed uses that package name instead.
        if ! pkg_install git-http; then
            pkg_install git
        fi
    fi
fi

ZSH_BIN="$(command -v zsh || true)"

if [ -z "$ZSH_BIN" ] || [ ! -x "$ZSH_BIN" ]; then
    echo "ERROR: zsh is not installed."
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is not installed after package installation."
    exit 1
fi

if [ ! -d /root/.oh-my-zsh ]; then
    git clone --depth=1 \
        https://github.com/ohmyzsh/ohmyzsh.git \
        /root/.oh-my-zsh
fi

install_file "files/etc/banner" "/etc/banner" 644
install_file "files/usr/sbin/techrelay-top-network" "/usr/sbin/techrelay-top-network" 755
install_file "files/usr/sbin/techrelay-motd" "/usr/sbin/techrelay-motd" 755
install_file "files/root/.techrelay-zsh" "/root/.techrelay-zsh" 644
install_file "files/root/.zshrc" "/root/.zshrc" 644

# Set the expected Flint 4 hostname.
uci set system.@system[0].hostname='Flint4-Main'
uci commit system
printf '%s\n' 'Flint4-Main' >/proc/sys/kernel/hostname

# Register zsh as a valid login shell.
touch /etc/shells
grep -qxF "$ZSH_BIN" /etc/shells ||
    printf '%s\n' "$ZSH_BIN" >>/etc/shells

# Install the boot-time safety net before changing root's login shell. If a
# later sysupgrade removes zsh but preserves /etc/passwd, the next boot will
# automatically recover root to /bin/ash instead of locking out SSH.
install_shell_fallback

# Set root's login shell to zsh without requiring chsh.
backup_file /etc/passwd
awk -F: -v OFS=: -v shell="$ZSH_BIN" '
    $1 == "root" {
        $7 = shell
    }

    {
        print
    }
' /etc/passwd >/tmp/passwd.flint4-banner

cat /tmp/passwd.flint4-banner >/etc/passwd
rm -f /tmp/passwd.flint4-banner
chmod 644 /etc/passwd

cat >"$BACKUP_DIR/RESTORE.txt" <<EOF_RESTORE
Restore the previous files with:

cp -a "$BACKUP_DIR/etc/banner" /etc/banner
cp -a "$BACKUP_DIR/usr/sbin/techrelay-top-network" /usr/sbin/techrelay-top-network
cp -a "$BACKUP_DIR/usr/sbin/techrelay-motd" /usr/sbin/techrelay-motd
cp -a "$BACKUP_DIR/root/.techrelay-zsh" /root/.techrelay-zsh
cp -a "$BACKUP_DIR/root/.zshrc" /root/.zshrc
cp -a "$BACKUP_DIR/etc/passwd" /etc/passwd
EOF_RESTORE

if [ -e "$BACKUP_DIR/etc/rc.local" ]; then
    cat >>"$BACKUP_DIR/RESTORE.txt" <<EOF_RESTORE_RC
cp -a "$BACKUP_DIR/etc/rc.local" /etc/rc.local
EOF_RESTORE_RC
fi

echo
echo "Installed files:"
echo "  /etc/banner"
echo "  /usr/sbin/techrelay-top-network"
echo "  /usr/sbin/techrelay-motd"
echo "  /root/.techrelay-zsh"
echo "  /root/.zshrc"
echo
echo "Root login shell: $ZSH_BIN"
echo "Package manager: $PKG_MGR"
echo "SSH shell fallback: enabled in /etc/rc.local"
echo "Backup: $BACKUP_DIR"
echo
echo "Disconnect and reconnect to see the complete login display."
