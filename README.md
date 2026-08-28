# Flint 4 Banner and MOTD — OpenWrt 25

Complete login banner and dynamic MOTD setup for a GL.iNet Flint 4 (`GL-BE14000`) running an OpenWrt 25 APK-based build with zsh/Oh My Zsh.

This `op25` branch is the OpenWrt 25 / `apk` version. The `main` branch remains the legacy `opkg` version.

The login display contains:

1. Tech Relay ASCII banner
2. `TECH RELAY COMPUTER NETWORK - FLINT 4 MAIN`
3. A side-by-side Tailscale, ZeroTier, and AstroWarp IP row
4. System Status
5. Network Verification
6. Oh My Zsh `pygmalion` prompt and terminal-title handling

The OpenWrt 25 OPKG-to-APK login cheatsheet is backed up and suppressed by the installer so it does not interrupt the custom login display.

## Install

SSH into the Flint 4 as root and run:

```sh
rm -rf /tmp/Flint4-BannerMOTD
git clone --branch op25 --single-branch \
    https://github.com/zippyy/Flint4-BannerMOTD.git \
    /tmp/Flint4-BannerMOTD
chmod +x /tmp/Flint4-BannerMOTD/install.sh
/tmp/Flint4-BannerMOTD/install.sh
```

The installer verifies that `apk` is available, runs `apk update`, and installs/verifies `ca-certificates`, `ca-bundle`, `curl`, `zsh`, `git`, and `git-http`. It does not call `opkg`.

Then disconnect and reconnect:

```sh
exit
ssh -t root@192.168.80.1 -p 42
```

## Installed files

| Repository/runtime component | Router destination |
|---|---|
| `files/etc/banner` | `/etc/banner` |
| `files/usr/sbin/techrelay-top-network` | `/usr/sbin/techrelay-top-network` |
| MOTD wrapper | `/usr/sbin/techrelay-motd` |
| `files/usr/sbin/techrelay-motd` status body | `/usr/sbin/techrelay-motd-body` |
| `files/root/.techrelay-zsh` | `/root/.techrelay-zsh` |
| `files/root/.zshrc` | `/root/.zshrc` |

On OpenWrt 25, `/usr/sbin/techrelay-motd` is a wrapper that always runs the side-by-side overlay IP row immediately before the MOTD status body. This avoids login-order differences between OpenWrt 25 and older builds.

The installer backs up existing destinations under:

```text
/root/Flint4-BannerMOTD-backup-YYYYMMDD-HHMMSS/
```

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
- DNS verification: lookup through the local resolver at `127.0.0.1`

Missing overlay interfaces display `No IP` in the top row and `Offline` in Network Verification.
