# Cascade

Cascade is a free, open-source Jellyfin player for iPhone and Apple TV. It uses SwiftUI, Liquid Glass, and Apple’s built-in video player so browsing and playback feel familiar on both devices. On Apple TV, posters use the system focus effect, so the artwork moves as you slide your thumb across the Siri Remote.

## What you can do

- Browse your movies and shows, search by title, or see what was added recently. Cascade caches the posters you’ve already loaded so they don’t have to download again every time you scroll back.
- Pick up a movie or episode from Continue Watching. On Apple TV, you can also hit Play from a show’s page and let Jellyfin pick the episode to start or resume.
- Choose audio and subtitles before starting a movie. If you’re curious about the file itself, File Info shows what Jellyfin knows about it, including the filename, resolution, bitrate, and codecs.
- Set a bitrate limit for new streams when you’re on a slower connection, or leave quality on Original to allow direct playback when the file is compatible.
- Save more than one server or user so you can switch between libraries without entering the address and login again.

## How it works

You sign in with your existing Jellyfin account, and Cascade talks directly to the server you enter. Jellyfin supplies the library, artwork, and watch history. When you hit Play, Cascade asks Jellyfin for a stream and hands it to Apple’s player. If the file needs to be transcoded, Jellyfin does that on the server. Cascade reports your progress back to Jellyfin so you can pick up where you left off on another device.

## Getting started

Enter the full address of your Jellyfin server, including `http://` or `https://` and the port if you use one, then sign in. If your server is on Tailscale, the device running Cascade needs to be able to reach it over Tailscale too. If you just want to look around, you can use [Jellyfin’s public demo server](https://demo.jellyfin.org/stable/) with the username `demo` and a blank password.

To build it yourself, open [cascade.xcodeproj](cascade.xcodeproj) in Xcode 27 and select the `cascade` scheme for iPhone or `cascade-tvOS` for Apple TV. The targets require iOS or tvOS 26.5 or later. If you’re running on a physical device, select your development team under Signing & Capabilities.
