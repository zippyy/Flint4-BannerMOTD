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

echo "Installing Flint 4 Tech Relay banner and MOTD..."

echo "Backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

if ! command -v zsh >/dev/null 2>&1; then
    opkg update
    opkg install ca-certificates ca-bundle curl zsh git-http
fi

ZSH_BIN="$(command -v zsh || true)"

if [ -z "$ZSH_BIN" ] || [ ! -x "$ZSH_BIN" ]; then
    echo "ERROR: zsh is not installed."
    exit 1
fi

if [ ! -d /root/.oh-my-zsh ]; then
    if ! command -v git >/dev/null 2>&1; then
        opkg update
        opkg install git-http ca-certificates ca-bundle
    fi

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
Restore the previous files with:

cp -a "$BACKUP_DIR/etc/banner" /etc/banner
cp -a "$BACKUP_DIR/usr/sbin/techrelay-top-network" /usr/sbin/techrelay-top-network
cp -a "$BACKUP_DIR/usr/sbin/techrelay-motd" /usr/sbin/techrelay-motd
cp -a "$BACKUP_DIR/root/.techrelay-zsh" /root/.techrelay-zsh
cp -a "$BACKUP_DIR/root/.zshrc" /root/.zshrc
cp -a "$BACKUP_DIR/etc/passwd" /etc/passwd
EOF

echo
echo "Installed files:"
echo "  /etc/banner"
echo "  /usr/sbin/techrelay-top-network"
echo "  /usr/sbin/techrelay-motd"
echo "  /root/.techrelay-zsh"
echo "  /root/.zshrc"
echo
echo "Root login shell: $ZSH_BIN"
echo "Backup: $BACKUP_DIR"
echo
echo "Disconnect and reconnect to see the complete login display."
