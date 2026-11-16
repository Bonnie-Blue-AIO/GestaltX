# Wallpaper Settings: Clear Collections, Videos, Restore Original

Fork feature on branch `pocket-poster-wallpapers`, ported from [Pocket Poster](https://github.com/leminlimez/Pocket-Poster) (GPL-3.0, leminlimez). Based on `wallet-card-skins` (Dialer Themer + Wallet Card Skins).

Marketing version: **1.1.1-wallpaper** (build 11140105).

## Where to find it

**Tools → Customization → Wallpaper Settings**

## Clear Collections

Pocket Poster's **Reset Collections** (labelled **Clear Collections** here, as the user called it).

It does **not** write PosterBoard files and does **not** need a Nugget/PosterBoard app hash or worse_query. On iOS 18+ it re-applies the current system language via `IPSettingsUtilities setLanguage:`, which makes PosterBoard rebuild Collections. Confirm before it runs.

If the API is unavailable, switch language in Settings → General → Language & Region and switch back, then wait a few minutes.

## Videos

**Wallpaper Settings → Videos**

- Phone-shaped preview card with a **+** button to pick a video (Photos), date/time overlay, delete, and ping-pong loop toggle.
- Up to 5 videos, 12 seconds each (toggle *Ignore 12-Second Limit* raises it to 60 seconds).
- **Create & Apply** builds one CollectionsPoster descriptor per video from the bundled `Resources/VideoCAML` template (JPEG frames, capped at 30 fps / 2796 px) and installs it through GestaltX's existing wallpaper pipeline (`acquirePath` / worse_query on `com.apple.PosterBoard`).
- **Save to Wallpaper List** only creates the pack so you can Apply later.
- After Apply, open PosterBoard and force-close it from the app switcher, then add the wallpaper from Collections.

This does **not** use Pocket Poster's app-hash symlink / `.Trash` primitive. If leasing the PosterBoard container fails, Apply reports the same error as other wallpaper packs.

## Restore Original

Backs up PosterBoard's unprotected defaults on the first GestaltX wallpaper write. **Restore Original** removes only descriptors GestaltX added and restores that first defaults backup. It does not delete your imported packs or system collections. Force-close PosterBoard afterward.

## License / credit

GestaltX and this port are GPL-3. Video CAML generation, the Videos UI, the VideoCAML template, and Reset Collections are © leminlimez / Pocket Poster contributors. See `THIRD_PARTY_NOTICES.md` and `GestaltX/Licenses/Pocket-Poster-GPL-3.0.txt`.
