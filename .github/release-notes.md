## Install

With [Homebrew](https://brew.sh):

```sh
brew install --cask nikita19329/tap/eyelid
```

Or by hand: download the `Eyelid-*.zip` below, unzip it, and move `Eyelid.app` to your Applications folder.

Eyelid isn't notarized yet, so macOS blocks the first launch. Open **System Settings → Privacy & Security** and click **Open Anyway**, or run:

```sh
xattr -dr com.apple.quarantine /Applications/Eyelid.app
```

If you use the volume and brightness HUD, remove Eyelid from **System Settings → Privacy & Security → Accessibility** after updating, and allow it again.

Requires macOS 14 or later, on Apple silicon or Intel. The `.sha256` file holds the zip's SHA-256 checksum.
