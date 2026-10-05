# Eyelid

[![Build](https://github.com/Nikita19329/Eyelid/actions/workflows/build.yml/badge.svg)](https://github.com/Nikita19329/Eyelid/actions/workflows/build.yml)

An open-source, Dynamic Island–style notch for your MacBook.

Eyelid sits on top of the notch and blends in with it. Hover over the notch and it opens up to show what's playing; move the pointer away and it tucks back in.

> **Status:** early prototype. Expect rough edges and breaking changes.

## Features

- **Blends into the notch.** The closed notch matches the hardware cutout, so you don't notice Eyelid until you need it.
- **Hover to open.** It opens when the pointer reaches the notch (with a haptic tick on Force Touch trackpads) and closes when the pointer leaves.
- **Now Playing from any app.** Apple Music, Spotify, Yandex Music, YouTube in a browser: anything that reports to the macOS Now Playing widget shows up with artwork, progress, and playback controls.
- **Live activity.** While something plays, the closed notch shows the artwork on one side and an equalizer on the other.
- **Battery.** Plugging in or unplugging the charger shows the charge next to the notch for a few seconds, and so does the battery dropping to 20% and 10%. The open notch always shows the battery level.
- **Volume and brightness.** The volume, mute and brightness keys show their level next to the notch instead of the system HUD, in the closed notch and in the open one. The volume HUD shows the output device: AirPods, Beats, headphones, the MacBook speaker and more. You can pick the icon for each device and one of five level styles: bar, thick bar, segments, percentage or ring. Option-Shift changes the level in quarter steps, as in macOS. This is off by default, since it needs Accessibility access.
- **Stays out of the way.** No Dock icon, works on every Space and over full-screen apps, and clicks pass through to the menu bar while the notch is closed.
- **Settings.** Choose how long the pointer rests on the notch before it opens, turn on the volume and brightness HUD, turn off haptics, the live activity or battery activity, pick the display, and launch Eyelid at login.
- **Macs without a notch** get a virtual one at the top of the main display.

## Install

Download the latest `Eyelid-*.zip` from [Releases](https://github.com/Nikita19329/Eyelid/releases/latest), unzip it, and move `Eyelid.app` to Applications. Eyelid runs on macOS 14 Sonoma or later, on Apple silicon and Intel Macs.

Eyelid isn't notarized yet, so macOS blocks the first launch. Allow it in **System Settings → Privacy & Security** with **Open Anyway**, or remove the quarantine flag:

```sh
xattr -dr com.apple.quarantine /Applications/Eyelid.app
```

The eye icon in the menu bar opens Settings and quits Eyelid.

## Build from source

### Requirements

- macOS 14 Sonoma or later (developed on macOS 27)
- Xcode
- CMake: `brew install cmake`

The Command Line Tools alone are not enough: on the macOS 27 SDK, SwiftUI's `@State` is a macro whose compiler plugin ships only with Xcode.

### Build and run

```sh
git clone --recurse-submodules https://github.com/Nikita19329/Eyelid.git
cd Eyelid
make run
```

`make run` builds `build/Eyelid.app`, quits a running copy, and launches the new one. Other targets:

| Command      | What it does                                   |
|--------------|------------------------------------------------|
| `make app`   | Release build of `build/Eyelid.app`            |
| `make debug` | Debug build of `build/Eyelid.app`              |
| `make test`  | Runs the unit tests (`swift test`)             |
| `make clean` | Removes `.build` and `build`                   |

After `make app` has run once, `swift run` from the repository root works too, which is handy for quick iterations. To work in Xcode, open `Package.swift`.

The version comes from git: builds show the latest `vX.Y.Z` tag and the commit count as the build number. `UNIVERSAL=1 make app` builds for both Apple silicon and Intel.

## Branches and releases

- **`main`** is the latest release.
- **`develop`** collects finished work for the next release. It is the default branch, so pull requests target it.
- **Every feature or fix** gets its own short-lived branch, such as `feat/battery`, merged into `develop` through a pull request.

To release:

1. Open a pull request from `develop` to `main` titled `Release X.Y.Z`. Merge it with a merge commit once the checks pass.
2. Tag the merge commit on `main`:

   ```sh
   git switch main && git pull
   git tag -a v0.2.0 -m "Eyelid 0.2.0"
   git push origin v0.2.0
   ```

3. Bring the release back into `develop`, so development builds pick up the new version:

   ```sh
   git switch develop && git pull
   git merge main
   git push
   ```

The Release workflow runs the tests and builds a universal app stamped with the tag's version. It checks the version, the architectures, the minimum macOS version and the signature. Then it publishes a GitHub release with the zip, its SHA-256 checksum, and notes generated from the merged pull requests. Tags with a suffix, such as `v0.2.0-beta.1`, become prereleases.

## How it works

**The notch window.** A borderless, non-activating `NSPanel` floats just above the menu bar on every Space. Its size comes from `NSScreen.safeAreaInsets` and the `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` next to the notch. The panel ignores mouse events while closed, so the menu bar under it stays clickable. A global mouse monitor opens it when the pointer enters the notch. Mouse events, unlike key events, don't need the Accessibility permission.

**Now Playing.** Since macOS 15.4, MediaRemote (the private framework behind the Now Playing widget) only answers Apple's own entitled processes. Eyelid uses [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter). The adapter loads a small framework into Apple's signed `/usr/bin/perl`, which is still allowed to query MediaRemote, and streams updates as JSON lines. Eyelid runs `mediaremote-adapter.pl … stream` as a child process and decodes its output.

**Volume and brightness.** With the setting on, an event tap intercepts the volume, mute and brightness keys, which needs Accessibility access. Eyelid changes the level itself, so macOS never sees the press and never shows its HUD. Volume goes through CoreAudio. macOS has no public API for display brightness, so Eyelid calls the private DisplayServices framework, as MonitorControl and similar utilities do. If a key can't be handled, for example on an output without volume control, it's passed on to macOS as usual.

The volume HUD picks the device icon from what CoreAudio reports about the output: the connection type, whether wired headphones are plugged in, and for Bluetooth the model UID, which holds the vendor and product ID. That's enough for AirPods and Beats, even after renaming them. Other Bluetooth devices all look like headphones to macOS, so Settings lets you pick an icon for each device.

Since Eyelid is signed ad hoc, macOS ties the Accessibility permission to one exact build. After an update or a rebuild, remove Eyelid from **System Settings → Privacy & Security → Accessibility** and allow it again. Eyelid shows the system prompt for it on launch.

## Project layout

```
Sources/Eyelid/
  App/          App entry point, menu bar item, app delegate
  Notch/        Notch geometry, panel, shape, hover handling, root view
  NowPlaying/   mediaremote-adapter client, now playing model and views
  Battery/      IOKit battery reading, battery events and views
  HUD/          Media key tap, volume (CoreAudio) and brightness (DisplayServices), HUD view
  Settings/     Preferences, Settings window, launch at login
Tests/          Unit tests (Swift Testing) for the logic that needs no screen
Resources/      Info.plist
scripts/        build-app.sh: assembles and signs Eyelid.app without an Xcode project
Vendor/         mediaremote-adapter (git submodule)
```

## Roadmap

- [x] Settings window: hover delay, haptics, live activity, choice of display
- [x] Launch at login (`SMAppService`)
- [x] Battery and charging activity
- [x] Volume and brightness HUD
- [ ] Calendar: upcoming events
- [ ] File shelf: drop files onto the notch
- [ ] Notches on several displays at once
- [x] Universal (arm64 + x86_64) release builds from version tags
- [ ] Sparkle updates, Homebrew cask, notarization

## Contributing

Issues and pull requests are welcome. For anything bigger than a small fix, please open an issue first so we can agree on the approach. Branch off `develop` and open your pull request against it.

GitHub Actions builds and tests every pull request and every push to `main` and `develop` on macOS 26 with the runner's default Xcode. The built app is attached to each run as a zip for 14 days, so you can try a change without building it yourself.

The tests cover what can be checked without a screen: decoding the adapter's output, playback time, battery readings and events, media key decoding and level steps, notch layout and hover areas, and settings. Behavior on screen, such as hovering, haptics and the look of the notch, still needs a try on a real Mac. Mention what you checked in your pull request.

## License

Eyelid is licensed under the [GNU General Public License v3.0](LICENSE).

It bundles [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) by Jonas van den Berg and contributors, licensed under the BSD 3-Clause License. Its license text is included in the app bundle under `Contents/Resources/Licenses`.

Eyelid is inspired by Dynamic Island and by notch apps such as Alcove and boring.notch. It is an independent project and is not affiliated with Apple or with any of those apps.
