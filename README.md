# Flint 4 Banner and MOTD

Complete login banner and dynamic MOTD setup for a GL.iNet Flint 4 (`GL-BE14000`) running OpenWrt and zsh/Oh My Zsh.

The login display contains:

1. Tech Relay ASCII banner
2. `TECH RELAY COMPUTER NETWORK - FLINT 4 MAIN`
3. A side-by-side Tailscale, ZeroTier, and AstroWarp IP row
4. System Status
5. Network Verification
6. Oh My Zsh `pygmalion` prompt and terminal-title handling

## Package-manager support

The installer automatically detects the package manager:

- OpenWrt 25+ / current GL.iNet builds: `apk`
- Older OpenWrt / GL.iNet builds: `opkg`

If required packages are missing, the installer uses the detected package manager to install zsh, Git HTTP support, curl, and CA certificates.

## Install

If `git` is already available, SSH into the Flint 4 as root and run:

```sh
rm -rf /tmp/Flint4-BannerMOTD
git clone https://github.com/zippyy/Flint4-BannerMOTD.git /tmp/Flint4-BannerMOTD
chmod +x /tmp/Flint4-BannerMOTD/install.sh
/tmp/Flint4-BannerMOTD/install.sh
```

If a firmware upgrade also removed `git`, bootstrap it first with the package manager present on the router:

```sh
if command -v apk >/dev/null 2>&1; then
    apk update
    apk add ca-certificates ca-bundle curl zsh git-http
else
    opkg update
    opkg install ca-certificates ca-bundle curl zsh git-http
fi
```

Then disconnect and reconnect:

```sh
exit
ssh -t root@192.168.80.1 -p 42
```

## Firmware-upgrade SSH safety

The installer adds an idempotent recovery guard to `/etc/rc.local` before it changes root's login shell to zsh.

Firmware upgrades can preserve `/etc/passwd` while removing user-installed packages. If root is still configured to use zsh but that binary no longer exists, the recovery guard automatically changes root's login shell to `/bin/ash` on boot. This prevents the router from becoming inaccessible over SSH simply because zsh was removed.

After logging in with ash, restore the packages and rerun this installer. The installer will set root back to the detected zsh binary only after confirming that zsh exists and is executable.

## Installed files

| Repository file | Router destination |
|---|---|
| `files/etc/banner` | `/etc/banner` |
| `files/usr/sbin/techrelay-top-network` | `/usr/sbin/techrelay-top-network` |
| `files/usr/sbin/techrelay-motd` | `/usr/sbin/techrelay-motd` |
| `files/root/.techrelay-zsh` | `/root/.techrelay-zsh` |
| `files/root/.zshrc` | `/root/.zshrc` |

The installer backs up every existing destination before replacing it. It also backs up `/etc/passwd` and `/etc/rc.local` when modifying them.

## Manual tests

```sh
cat /etc/banner
/usr/sbin/techrelay-top-network
/usr/sbin/techrelay-motd
```

Restart the login shell:

```sh
exec zsh -l
```

## Network interfaces

The IP row and verification section discover addresses dynamically:

- Tailscale: `tailscale0`
- ZeroTier: first interface beginning with `zt`
- AstroWarp: `mptun0`
- LAN/WAN: OpenWrt `ubus` interface status

Missing overlay interfaces display `No IP` in the top row and `Offline` in Network Verification.
