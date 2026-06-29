# Xasu — DPI Bypass for iOS

Dark minimal iOS app that routes all traffic (Wi-Fi + LTE) through a local byedpi VPN tunnel to bypass DPI restrictions.

## Features
- One-button connect
- Wi-Fi and LTE (via NEPacketTunnelProvider + includeAllNetworks)
- Seamless network switching without reconnection
- Presets: YouTube, TikTok, Discord, Instagram
- Liquid Glass dark UI

## Install (IPA from GitHub Actions)

1. Go to **Actions** tab → latest run → **Artifacts** → download `Xasu-unsigned.zip`
2. Extract `Xasu.ipa`
3. Open **Sideloadly**, connect iPhone via USB
4. Drag `Xasu.ipa` into Sideloadly → enter Apple ID → click **Start**
5. On iPhone: **Settings → General → VPN & Device Management** → trust your developer certificate
6. Open Xasu, allow VPN configuration when prompted
7. Enable services in **Services** screen, tap the shield button to connect

## Architecture

```
Xasu/                    ← SwiftUI app (HomeView, SettingsView)
  Core/VPN/VPNManager    ← manages NETunnelProviderManager
XasuTunnel/              ← Network Extension
  PacketTunnelProvider   ← starts byedpi SOCKS5 + PAC proxy settings
```

Traffic flow:
```
iOS App → System Proxy (PAC) → byedpi SOCKS5 (127.0.0.1:10800) → Internet
```
byedpi applies TCP Split on TLS ClientHello to bypass DPI at the ISP level.
