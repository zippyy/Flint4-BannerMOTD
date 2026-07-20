# Flint 4 Banner and MOTD

Complete login banner and dynamic MOTD setup for a GL.iNet Flint 4 (`GL-BE14000`) running OpenWrt and zsh/Oh My Zsh.

The login display contains:

1. Tech Relay ASCII banner
2. `TECH RELAY COMPUTER NETWORK - FLINT 4 MAIN`
3. A side-by-side Tailscale, ZeroTier, and AstroWarp IP row
4. System Status
5. Network Verification
6. Oh My Zsh `pygmalion` prompt and terminal-title handling

## Install

SSH into the Flint 4 as root and run:

```sh
opkg update
opkg install ca-certificates ca-bundle curl zsh git-http

rm -rf /tmp/Flint4-BannerMOTD
git clone https://github.com/zippyy/Flint4-BannerMOTD.git /tmp/Flint4-BannerMOTD
chmod +x /tmp/Flint4-BannerMOTD/install.sh
/tmp/Flint4-BannerMOTD/install.sh
```

Then disconnect and reconnect:

```sh
exit
ssh -t root@192.168.80.1 -p 42
```

## Installed files

| Repository file | Router destination |
|---|---|
| `files/etc/banner` | `/etc/banner` |
| `files/usr/sbin/techrelay-top-network` | `/usr/sbin/techrelay-top-network` |
| `files/usr/sbin/techrelay-motd` | `/usr/sbin/techrelay-motd` |
| `files/root/.techrelay-zsh` | `/root/.techrelay-zsh` |
| `files/root/.zshrc` | `/root/.zshrc` |

The installer backs up every existing destination before replacing it.

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
