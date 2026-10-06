# Security policy

## Supported versions

Only the [latest release](https://github.com/Satis-ku/Eyelid/releases/latest) gets fixes. Please check that a problem is still there in it before reporting.

## Reporting a vulnerability

Please don't open a public issue. Report it privately instead, through [GitHub's private vulnerability reporting](https://github.com/Satis-ku/Eyelid/security/advisories/new).

Include what you can of:

- what an attacker could do, and what they need for it, such as a program already running on the Mac;
- the steps to reproduce it, or a proof of concept;
- the Eyelid version, from **Settings → About**, and the macOS version;
- which settings are on, especially the volume and brightness HUD, the clipboard history, and the equalizer that follows the sound.

Eyelid is made in spare time by one person, so expect a reply within a week. Once a fix is out, the advisory is published with credit to you, unless you'd rather not be named.

## What counts

Eyelid can hold Accessibility access, read the clipboard, and listen to system audio, each only if you turn it on. So the most serious problems are ones that let other code use those:

- loading code into Eyelid, or into the mediaremote-adapter it starts;
- getting Eyelid to act on input it shouldn't, such as keys other than volume, mute and brightness;
- the clipboard history or the equalizer keeping or sending what they handle;
- crafted now playing data, such as artwork, crashing Eyelid or doing worse.

The [Security](README.md#security) section of the README lists what Eyelid already does against these.

## Out of scope

- Gatekeeper blocking the first launch, and permissions resetting after updates. Releases aren't notarized and are signed ad hoc, which the README explains.
- Problems that need an attacker who can already run code as you with the same permissions, or who has root.
- Bugs in macOS itself. Please report those to Apple.
