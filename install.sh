#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="/root/Flint4-BannerMOTD-backup-$TIMESTAMP"

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

echo "Installing Flint 4 Tech Relay banner and MOTD for OpenWrt 25..."
echo "Backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

if ! command -v apk >/dev/null 2>&1; then
    echo "ERROR: apk package manager was not found."
    echo "This op25 branch is intended for OpenWrt 25 APK-based builds."
    exit 1
fi

echo "Installing required packages with apk..."
apk update
apk add ca-certificates ca-bundle curl zsh git git-http

ZSH_BIN="$(command -v zsh || true)"

if [ -z "$ZSH_BIN" ] || [ ! -x "$ZSH_BIN" ]; then
    echo "ERROR: zsh is not installed."
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is not installed."
    exit 1
fi

if [ ! -d /root/.oh-my-zsh ]; then
    git clone --depth=1 \
        https://github.com/ohmyzsh/ohmyzsh.git \
        /root/.oh-my-zsh
fi

install_file "files/etc/banner" "/etc/banner" 644
install_file "files/usr/sbin/techrelay-top-network" "/usr/sbin/techrelay-top-network" 755

# OpenWrt 25 can invoke the MOTD through a different login path than older builds.
# Keep the status body separate and use a wrapper so the overlay IP row is always
# printed immediately before System Status regardless of which shell path calls it.
backup_file /usr/sbin/techrelay-motd
install_file "files/usr/sbin/techrelay-motd" "/usr/sbin/techrelay-motd-body" 755
cat >/usr/sbin/techrelay-motd <<'EOF'
#!/bin/sh

[ -x /usr/sbin/techrelay-top-network ] &&
    /usr/sbin/techrelay-top-network

exec /usr/sbin/techrelay-motd-body "$@"
EOF
chmod 755 /usr/sbin/techrelay-motd

install_file "files/root/.techrelay-zsh" "/root/.techrelay-zsh" 644
install_file "files/root/.zshrc" "/root/.zshrc" 644

# Suppress OpenWrt 25's OPKG-to-APK login cheatsheet so the custom MOTD stays clean.
if [ -f /etc/profile.d/apk-cheatsheet.sh ]; then
    backup_file /etc/profile.d/apk-cheatsheet.sh
    rm -f /etc/profile.d/apk-cheatsheet.sh
fi

# Set the expected Flint 4 hostname.
uci set system.@system[0].hostname='Flint4-Main'
uci commit system
printf '%s\n' 'Flint4-Main' >/proc/sys/kernel/hostname

# Register zsh as a valid login shell.
touch /etc/shells
grep -qxF "$ZSH_BIN" /etc/shells ||
    printf '%s\n' "$ZSH_BIN" >>/etc/shells

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

cat >"$BACKUP_DIR/RESTORE.txt" <<EOF
Restore previous files where backups exist:

[ -f "$BACKUP_DIR/etc/banner" ] && cp -a "$BACKUP_DIR/etc/banner" /etc/banner
[ -f "$BACKUP_DIR/usr/sbin/techrelay-top-network" ] && cp -a "$BACKUP_DIR/usr/sbin/techrelay-top-network" /usr/sbin/techrelay-top-network
[ -f "$BACKUP_DIR/usr/sbin/techrelay-motd" ] && cp -a "$BACKUP_DIR/usr/sbin/techrelay-motd" /usr/sbin/techrelay-motd
[ -f "$BACKUP_DIR/usr/sbin/techrelay-motd-body" ] && cp -a "$BACKUP_DIR/usr/sbin/techrelay-motd-body" /usr/sbin/techrelay-motd-body
[ -f "$BACKUP_DIR/root/.techrelay-zsh" ] && cp -a "$BACKUP_DIR/root/.techrelay-zsh" /root/.techrelay-zsh
[ -f "$BACKUP_DIR/root/.zshrc" ] && cp -a "$BACKUP_DIR/root/.zshrc" /root/.zshrc
[ -f "$BACKUP_DIR/etc/passwd" ] && cp -a "$BACKUP_DIR/etc/passwd" /etc/passwd
[ -f "$BACKUP_DIR/etc/profile.d/apk-cheatsheet.sh" ] && cp -a "$BACKUP_DIR/etc/profile.d/apk-cheatsheet.sh" /etc/profile.d/apk-cheatsheet.sh
EOF

echo
echo "Installed files:"
echo "  /etc/banner"
echo "  /usr/sbin/techrelay-top-network"
echo "  /usr/sbin/techrelay-motd"
echo "  /usr/sbin/techrelay-motd-body"
echo "  /root/.techrelay-zsh"
echo "  /root/.zshrc"
echo
echo "Package manager: apk"
echo "Root login shell: $ZSH_BIN"
echo "Backup: $BACKUP_DIR"
echo
echo "Disconnect and reconnect to see the complete login display."
