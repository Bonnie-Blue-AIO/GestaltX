# Dialer Themer (this fork)

This fork of [huamidev/GestaltX](https://github.com/huamidev/GestaltX) ports **Dialer Themer** from [jailbreakdotparty/Erosion](https://github.com/jailbreakdotparty/Erosion) (GPL-3) into GestaltX so you can theme the Phone app keypad without running a second app.

## Where to find it

**Tools → Customization → Dialer Themer**

## What it does

- Import a `TelephonyUI-8` / `TelephonyUI-9` / `TelephonyUI-10` theme zip
- Preview the 12 dial pad keys
- Apply / reset keys written into `com.apple.mobilephone` → `Library/Caches/TelephonyUI-10`
- Open the Phone app afterward (toggle light/dark until keys appear; do not force-quit Phone)

The green call button cannot be themed (same limitation as Erosion).

## Build

GitHub Actions (`.github/workflows/build.yml`) builds an **ad-hoc** IPA on pushes to `dialer-themer` / `main`, tags `v*`, and `workflow_dispatch`. Re-sign with AltStore / SideStore / TrollStore while preserving App Group `group.com.huami.gestultx`.

## License / credit

GestaltX and the Dialer Themer port are GPL-3. Dialer Themer algorithm © lunginspector / jailbreak.party (Erosion). See `THIRD_PARTY_NOTICES.md` and `GestaltX/Licenses/Erosion-GPL-3.0.txt`.
