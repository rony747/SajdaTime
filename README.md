# PrayerBar

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
open "dist/PrayerBar.app"
```

Requires Xcode (tested with Xcode 27 / Swift 6.4) and macOS 14 or later.

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
./.build/bin/prayerbarctl selftest   # engine invariants, no network
./.build/bin/prayerbarctl methods    # every calculation method vs the live API
./.build/bin/prayerbarctl compare    # a fixed set of cities vs the live API
./.build/bin/prayerbarctl matrix     # polar and edge-case latitudes
./.build/bin/prayerbarctl store      # the app's exact fetch/cache path
./.build/bin/prayerbarctl countdown 23.8103 90.4125 Asia/Dhaka --method KARACHI  # menu bar across a day
./.build/bin/prayerbarctl show 51.5072 -0.1276 Europe/London --method MWL
```

`selftest` and the XCTest target run the *same* assertions, which live in
`PrayerCoreSelfTest` so there is only one copy.

### Current accuracy against Aladhan

Measured over 132 samples covering all 22 shipped methods:

| metric | value |
| --- | --- |
| mean absolute difference | **0.15 min** |
| within 1 minute | 130 / 132 |
| within 2 minutes | 132 / 132 |
| worst case | 2 min |

Reproduce with `prayerbarctl methods`.

## Project layout

```
Sources/
  PrayerCore/          pure logic, no UI, testable
    Astronomy.swift        solar position (declination, equation of time)
    PrayerCalculator.swift on-device prayer time computation
    CalculationMethod.swift the 22 method definitions and madhabs
    AladhanClient.swift    live API client
    PrayerTimesStore.swift decides live / cached / calculated
    PrayerTimesCache.swift per-day disk cache
    AppSettings.swift      every user preference, as data
    SelfTest.swift         executable specification
  PrayerBarApp/        the SwiftUI menu bar application
  PrayerBarCtl/        the verification CLI
Tests/PrayerCoreTests/ XCTest wrapper around the shared self-test
```

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
`PRAYERBAR_DEBUG=1` the app logs the exact string it sets, and
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

Use `prayerbarctl countdown <lat> <lng> <tz>` to print what the menu bar would
show at every half hour of the day.

**The cache stores prayer names, not array positions**, so reordering the
`Prayer` enum cannot silently mis-decode old cache entries.

## Settings storage

Preferences live under `app.local.prayerbar.settings.v2`. The key is versioned
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
