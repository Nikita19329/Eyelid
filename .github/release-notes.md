## Install

1. Download the `Eyelid-*.zip` below and unzip it.
2. Move `Eyelid.app` to your Applications folder.
3. Eyelid isn't notarized yet, so macOS blocks the first launch. Open **System Settings → Privacy & Security** and click **Open Anyway**, or run:

   ```sh
   xattr -dr com.apple.quarantine /Applications/Eyelid.app
   ```

Requires macOS 14 or later, on Apple silicon or Intel. The `.sha256` file holds the zip's SHA-256 checksum.
