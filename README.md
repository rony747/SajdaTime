# Sajda Time

A native macOS menu bar app for Muslim prayer times: live times for your
location, a countdown in the menu bar, and per-prayer reminders you control.

## What it does

- **Real prayer times** fetched from the [Aladhan API](https://aladhan.com/prayer-times-api),
  cached per day so the app opens instantly and keeps working offline.
- **Offline calculation** built in — if the network is unavailable the app
  computes the times on-device from solar geometry, and says so in the UI.
- **Menu bar countdown** — icon, prayer name and time remaining, configurable.
- **Reminders per prayer** — automatic or manual, e.g. 10 minutes before, at the
  time, and 10 minutes after, set independently for each prayer.
- **Settings** across General, Location & Time, Calculation, Notifications and
  Focus Mode.
- **Focus Mode** — a full-screen overlay during prayer, exitable with ⌘⎋.

## Building

```bash
./build.sh            # release build
./build.sh debug      # debug build
open "dist/Sajda Time.app"
```

Requires Xcode (tested with Xcode 27 / Swift 6.4) and **macOS 26 or later**,
because the interface is built on Liquid Glass (`.glassEffect`, `GlassEffectContainer`).

The result is an ad-hoc signed `.app` that runs locally. It is **not** signed
with a Developer ID and **not** notarised, so it cannot be distributed to other
machines as-is; that needs your own signing certificate.

### Why `build.sh` instead of `swift build`

`Package.swift` is maintained and the project opens normally in Xcode, but the
build script invokes `swiftc` directly. That is deliberate: in a sandboxed or
restricted environment SwiftPM's build systems (both XCBuild and llbuild) cannot
write their state files, and `swiftc` normally wraps macro plugin servers in
`sandbox-exec`, which cannot nest inside another sandbox. `build.sh` therefore
passes `-disable-sandbox` and manages the module cache itself, which makes the
build reproducible under those conditions.

## Verifying it

The app ships a verification CLI rather than relying on unit tests alone:

```bash
./.build/bin/sajdactl selftest   # engine invariants, no network
./.build/bin/sajdactl methods    # every calculation method vs the live API
./.build/bin/sajdactl compare    # a fixed set of cities vs the live API
./.build/bin/sajdactl matrix     # polar and edge-case latitudes
./.build/bin/sajdactl store      # the app's exact fetch/cache path
./.build/bin/sajdactl countdown 23.8103 90.4125 Asia/Dhaka --method KARACHI  # menu bar across a day
./.build/bin/sajdactl show 51.5072 -0.1276 Europe/London --method MWL
```

`selftest` and the XCTest target run the *same* assertions, which live in
`SajdaCoreSelfTest` so there is only one copy.

### Current accuracy against Aladhan

Measured over 132 samples covering all 22 shipped methods:

| metric | value |
| --- | --- |
| mean absolute difference | **0.15 min** |
| within 1 minute | 130 / 132 |
| within 2 minutes | 132 / 132 |
| worst case | 2 min |

Reproduce with `sajdactl methods`.

## Project layout

```
Sources/
  SajdaCore/          pure logic, no UI, testable
    Astronomy.swift        solar position (declination, equation of time)
    PrayerCalculator.swift on-device prayer time computation
    CalculationMethod.swift the 22 method definitions and madhabs
    AladhanClient.swift    live API client
    PrayerTimesStore.swift decides live / cached / calculated
    PrayerTimesCache.swift per-day disk cache
    AppSettings.swift      every user preference, as data
    SelfTest.swift         executable specification
  SajdaTimeApp/        the SwiftUI menu bar application
  SajdaTimeCtl/        the verification CLI
Tests/SajdaCoreTests/ XCTest wrapper around the shared self-test
```

## Brand assets

`Resources/Assets/` holds the master artwork, all with transparent backgrounds:

| file | used for |
| --- | --- |
| `appicon.png` | the app icon, the menu bar-adjacent mark and the panel header |
| `logo.png` / `logo-dark.png` | the wordmark, per colour scheme |
| `banner.png` | the artwork behind the next-prayer banner and the General summary. It **fills** its band edge to edge and is clipped, so it reads as a background rather than a picture floating in the middle of the card. |

`AppIcon.icns` is generated from `appicon.png` by `build.sh` rather than
committed, so the icon has one source of truth. The icon master sits on Apple's
macOS grid (824pt of artwork inside a 1024pt canvas). Each view falls back to a
drawn mosque if an asset is missing, so the UI cannot end up blank.

## Design

Built on Liquid Glass, in green with a warm amber for the sun prayers:

- **App mark** — a mosque drawn as a `Shape`, so one glyph serves the sidebar,
  the panel header and the menu bar at any size.
- **Panel** — app mark and place header with a live clock, a gradient
  next-prayer banner over a drawn skyline, one row per prayer (the open window
  tinted green with a live countdown pill), four action tiles, and a footer
  showing the calculation method and madhab.
- **Calendar** is a real page, not decoration: the month with Umm al-Qura day
  numbers alongside the Gregorian ones.
- **Qibla is hidden unless the machine has a magnetometer.** Macs do not —
  `CLLocationManager.headingAvailable` is false — so a compass could not know
  which way it was pointing. Where a heading *is* available the page behaves like
  a physical compass: the bezel turns so its north marks true north, a marker
  sits on the bezel at the Qibla bearing, and a fixed pointer at the top shows
  the direction you face, with a turn instruction.

  The earlier version never rotated the bezel at all and drew the needle against
  a fixed dial, which is why the direction read wrong.
- **Settings** — sidebar with the app identity, and cards with icon headers.

## Prayer windows, start to end

Every prayer is shown as a span rather than a single instant — "5:24 – 6:43 AM",
with what ends it underneath — because a prayer's time is a window with a length
(Fajr ends at sunrise, Isha at Islamic midnight). The same detail appears in
`Prayer Times › Prayer windows`, with each window's duration.

## Window translucency

Both surfaces are translucent, which is what lets the glass read as glass:

- The **popover** gets its material from `NSPopover`.
- The **settings window** is an `NSWindow` with `isOpaque = false` and a clear
  background, hosting an `NSGlassEffectView`. Without that the cards sat on an
  opaque `windowBackgroundColor` and rendered as flat rectangles — which is why
  settings did not look like Liquid Glass while the popover did.

## Following Apple's Liquid Glass guidance

Applied from [Landmarks: Building an app with Liquid Glass](https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass)
and *Applying Liquid Glass to custom views*:

- **Glass belongs to the control layer.** The settings window used to be one big
  `NSGlassEffectView` with glass cards inside it — glass on glass, which is what
  made everything mushy and low-contrast. The window is now a standard
  translucent `NSVisualEffectView`, and glass is reserved for the surfaces
  floating above it.
- **`GlassEffectContainer` around groups of effects**, which the documentation
  calls for both rendering performance and shape blending. The settings detail is
  one container; the panel's action tiles are another.
- **Container spacing must sit *below* the interior spacing.** The documentation
  warns that a larger container spacing makes separate effects blend into one
  shape at rest. The first attempt used 18 against 14pt card spacing, which would
  have merged the cards; it is 8 against 14 now, and 4 against 8 for the tiles.
- **`.buttonStyle(.glass)`** for the action tiles, replacing hand-rolled glass
  backgrounds, so they get the system's interactive behaviour.
- `glassEffect` is applied **after** the appearance modifiers, as required.

## Inspecting the interface without a screen

Screen capture is unavailable on this machine, so the app can render its own
views: `SAJDA_RENDER=<dir>` writes the panel and every settings page, in light
and dark, to PNGs and exits. This is how the artwork-over-text bug and the
washed-out card were found.

Development hooks, all environment-gated:

| variable | effect |
| --- | --- |
| `SAJDA_RENDER=<dir>` | render every view to PNGs and exit |
| `SAJDA_OPEN_POPOVER=1` | open the panel at launch |
| `SAJDA_OPEN_SETTINGS=1` | open settings at launch |
| `SAJDA_CYCLE_APPEARANCE=1` | cycle dark then light after launch |
| `SAJDA_DEBUG=1` | log popover geometry, appearance and the menu bar label |
| `SAJDA_FAKE_HEADING=<deg>` | pretend a magnetometer exists at a fixed heading |

`sajdactl seed-appearance <system\|light\|dark>` writes the preference directly
into the app's domain so a specific theme can be exercised.

Two limits worth knowing:

- `ImageRenderer` does not draw materials, so these renders verify **layout**,
  not the glass appearance. Cards appear flat in them.
- `Toggle`, `Menu` and `ScrollView` are AppKit-backed and render as placeholders
  or blanks offscreen. `SettingsChrome(scrolls: false)` exists for this reason.

## Appearance

`Appearance › Theme` switches between **System**, **Light** and **Dark**.

It is applied in two places, on purpose. `NSApp.appearance` covers the settings
window, but it does **not** reliably reach the popover's own window, so the menu
bar panel kept its previous look until the app restarted. `StatusItemController`
therefore sets `popover.appearance` and the hosting view's appearance as well,
and re-applies both whenever the preference changes — so an open panel follows a
theme change immediately.

With **System**, the popover is left to AppKit (nil appearance), which tracks the
macOS setting live.

Three things had to change for dark mode to be readable:

- **Cards were plain `.regular` glass**, which is fully see-through; over a dark
  or busy desktop the text inside lost contrast. Cards now use a scheme-aware
  tint — a dark tint in dark mode, a light one in light — plus a hairline
  border.
- **The settings window** backs its glass with a scrim of the window background
  colour, keeping translucency without letting the desktop dominate.
- **The banner artwork is pale in both schemes**, so its text is pinned to the
  light colour scheme. Otherwise it turned white in dark mode and disappeared
  into the cream background.

The wordmark is dark green and vanished on dark backgrounds, so
`logo-dark.png` is generated from `logo.png`: the dome and the wordmark are
separated *spatially* (the dome is saturated and occupies the left ~30% of the
image), the wordmark and tagline are recoloured to a light mint, and the dome is
brightened with its hue intact. `BrandLogo` picks the variant from the colour
scheme.

## Clock format

`Appearance › Clock` switches every time in the app between 12-hour
("5:24 PM") and 24-hour ("17:24"). All formatting goes through
`TimeFormatting` in the core module, so the panel, the settings preview and the
menu bar cannot drift apart, and the preference is asserted in the self-test.

## Design decisions worth knowing

**Times come from three places, in order:** a cached day fetched earlier from
Aladhan, a fresh Aladhan fetch, then on-device calculation. The panel always
shows which one you are looking at, so a value is never silently stale.

**Method offsets are real.** Several conventions (Diyanet, Morocco, Dubai,
Lisbon, Jordan) apply fixed minute offsets internally, and Lisbon and Jordan
define Maghrib/Isha as intervals rather than solar angles. These were measured
against the live API and encoded, which is what brings the worst case down from
7 minutes to 2. They are applied to the offline calculation only — Aladhan
applies its own.

**Computed times match fetched times**, so switching between them does not move
the times. That includes the high-latitude rule: `Automatic` follows Aladhan's
angle-based default, because using "middle of the night" instead made Fajr and
Isha jump by over an hour at polar latitudes.

**First launch seeds the location from the system timezone.** A hard-coded
default city is wrong for almost everyone: the first build shipped with
Istanbul's coordinates, so a user in Dhaka saw Istanbul's prayer times rendered
on the Dhaka clock. Settings are now seeded from a timezone-to-city table, marked
as *estimated*, and the app asks CoreLocation for the real position right away.
The panel says when a position is only an estimate.

```swift
let settings = AppSettings.fresh(for: .current)   // Asia/Dhaka -> Dhaka, BD
```

**The popover is given an explicit content size.** Handing `NSPopover` a
`NSHostingController` without `sizingOptions = [.preferredContentSize]` left it
positioning itself from a stale fitting size, which placed the panel over the menu
bar and clipped its top. The panel now reports 320x445 and the popover matches it
exactly, with a guard that pushes the panel back under the bar if AppKit ever
places it too high.

**The whole app lifecycle is AppKit, not SwiftUI.** SwiftUI's scene machinery
failed twice on this shape of app: a `MenuBarExtra` label that would not render
its countdown, and a `Settings` scene that would not open for an accessory
(`LSUIElement`) app — `showSettingsWindow:` resolved without a window appearing.
The status item and the settings window are now created and shown explicitly, and
SwiftUI is used only for view content inside `NSHostingController`. The settings
window also promotes the app to `.regular` while it is open, because a pure
accessory app is refused key-window status and the window would not take clicks.

**The menu bar item is AppKit, not SwiftUI.** `MenuBarExtra`'s label did not
render the countdown — the item showed the icon and nothing else. A status item
whose `button.title` we set ourselves is both reliable and *verifiable*: with
`SAJDA_DEBUG=1` the app logs the exact string it sets, and
`MenuBarComposer` is asserted in the self-test, so a countdown that stops
appearing fails a test instead of failing silently on screen.

**Remaining time is the prayer's own window, not the gap to the next prayer.**
Fajr's valid time ends at sunrise — roughly an hour — not at Dhuhr, and Isha's
chosen time ends at Islamic midnight, with midnight to Fajr reported separately
as the time of necessity (darurah). Both of those come from the classical
boundaries, and getting the first one wrong overstated Fajr's remaining time by
several hours. Between sunrise and Dhuhr, and between midnight and Fajr, no
prayer is in its chosen time, so the app counts down to the next one instead.

```
prayer    starts   ends     duration  ends at
Fajr      04:37    05:53     75 min   sunrise
Dhuhr     11:45    15:59    254 min   Asr
Asr       15:59    17:37     98 min   Maghrib
Maghrib   17:37    18:53     75 min   Isha
Isha      18:53    23:45    292 min   Islamic midnight
          (time of necessity until 04:38)
```

Use `sajdactl countdown <lat> <lng> <tz>` to print what the menu bar would
show at every half hour of the day.

**The cache stores prayer names, not array positions**, so reordering the
`Prayer` enum cannot silently mis-decode old cache entries.

## Settings storage

Preferences live under `app.local.sajda.settings.v2`. The key is versioned
because a schema change makes an older blob undecodable, and silently keeping it
would carry forward a wrong location; bumping the key starts from timezone-seeded
defaults instead.

## Known limitations

- **Moonsighting Committee Worldwide is not offered.** It applies a seasonal
  correction table this engine does not implement, and it produced times 15–30
  minutes out. Shipping it would have been worse than omitting it. Use MWL, or
  enable live fetching to get Aladhan's own values.
- **Asr at extreme latitudes can differ by ~20 minutes.** At places like
  Svalbard in early winter the sun barely clears the Asr altitude, so the result
  is inherently ill-conditioned: a tenth of a degree of declination is worth
  many minutes. Everywhere the sun actually climbs, agreement is within a
  minute.
- **Polar day and night use a mid-latitude reference (45°).** When there is no
  sunrise or sunset, the angle-based times are substituted from a mid-latitude
  day and the panel says so. Aladhan collapses these to a single repeated value
  instead.
- **Notification sounds must live in the app bundle**, so prayer-time audio uses
  the standard macOS alert sounds plus an optional audio file you choose for the
  full adhan. No adhan recording is bundled.
- **"Check for Updates" is not implemented** — there is no update feed for this
  build, so the panel offers "Refresh Times" instead of a menu item that would
  do nothing.
- **Launch at login** uses `SMAppService` and works best when the app lives in
  `/Applications`.
