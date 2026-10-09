<div align="center">

<img src="Resources/Assets/appicon.png" width="120" alt="Sajda Time">

# Sajda Time

**A native macOS menu bar app for Muslim Prayer Time.**

<img src="docs/images/reminder.jpg" width="720" alt="The full-screen prayer reminder">
<img src="docs/images/panel.png" width="360" alt="The menu bar panel">
<img src="docs/images/settings.png" width="440" alt="Settings">

</div>

Sajda Time lives in your menu bar and counts down the current prayer window. When
a prayer begins, it covers the screen with a short reminder and a hadith.

## Features

- Counts down the prayer window you are in, not just the next start time
- A full-screen reminder at every prayer, with a backdrop for that hour and a
  short hadith on the merit of salah
- 22 calculation methods and both Asr madhabs
- Detects your location and timezone automatically
- Adjustable Hijri date
- Works offline
- Light, dark or system appearance; 12- or 24-hour clock
- Optional Focus Mode

## Install

Download **[SajdaTime-1.0.0.zip](https://github.com/rony747/SajdaTime/releases/latest)**,
unzip it, and move **Sajda Time.app** to your Applications folder. It appears in
the menu bar, not the Dock.

Requires **macOS 26 or later** on Apple silicon.

> The app is ad-hoc signed rather than notarised, so macOS may refuse the first
> launch. Right-click the app and choose **Open**, or clear the quarantine flag:
>
> ```bash
> xattr -d com.apple.quarantine "/Applications/Sajda Time.app"
> ```

To build it yourself:

```bash
git clone git@github.com:rony747/SajdaTime.git && cd SajdaTime && ./build.sh
```

## Credits

Prayer times come from the **Aladhan API**, with an on-device calculation as the
offline fallback. Hadith texts and their references are from **QuranExplorer**.

The interface follows Apple's Liquid Glass guidance. Design and implementation
notes are in [docs/ENGINEERING.md](docs/ENGINEERING.md).

## Licence

No licence has been chosen, so this repository is **all rights reserved** by
default.
