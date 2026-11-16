# Wallpaper Settings: Clear Collections + Videos

Fork feature (branch `wallpaper-clear-videos`), ported from [Pocket Poster](https://github.com/leminlimez/Pocket-Poster) (GPL-3.0, leminlimez).

## Clear Collections
Tools → Customization → Wallpapers → **Clear Collections** (bottom section, red).
Equivalent to Pocket Poster's *Reset Collections*: calls `IPSettingsUtilities setLanguage:` with the current
system language so PosterBoard rebuilds its collections. Use when Apply fails because a file already exists or a
new wallpaper doesn't appear. Existing wallpapers are kept.

## Videos
Tools → Customization → Wallpapers → **Videos**.
- Pick up to 5 videos (PhotosPicker), 12 s each (toggle *Ignore 12-Second Limit* raises it to 60 s).
- Each row shows a muted looping preview, the duration and a *Loop Back and Forth* (autoreverse) toggle.
- **Create & Apply** generates one CollectionsPoster descriptor per video from the bundled `Resources/VideoCAML`
  template (JPEG frame per video frame, capped at 30 fps / 2796 px, `CAKeyframeAnimation` on `contents`),
  imports them as one pack named "Video Wallpaper <date>" and applies it through the normal worse_query pipeline.
- **Save to Wallpaper List** only creates the pack; apply it later from Wallpaper Settings.

`Resources/VideoCAML` is listed under `explicitFolders` in the project so its folder hierarchy is preserved in the app bundle.
