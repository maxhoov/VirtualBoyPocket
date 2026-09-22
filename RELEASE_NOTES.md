# VirtualBoyPocket 0.1.0

Experimental Virtual Boy core for Analogue Pocket, ported by maxhoov from Jamie Blanks' VirtualBoy_MiSTer RTL using Analogue core-template 1.3.0.

## Installation

Download the attached `maxhoov.VirtualBoy_0.1.0_2026-09-22.zip`, not GitHub's automatic source archive. Merge its contents into the SD card root, or drag the ZIP into Pocket Sync. Supply your own legally obtained, unmodified ROMs in `Assets/virtualboy/common/`. No game ROMs are included.

Back up saves and settings before upgrading. If upgrading from the old author identifier, rename `Cores/PocketVB.VirtualBoy` to `Cores/maxhoov.VirtualBoy` before merging the package; do not keep both folders. Settings migration has not been hardware verified.

## Features and hardware feedback

- Picture, sound and controls reported working on Pocket firmware 2.7 for Mario Clash, Mario's Tennis, Panic Bomber, SD Gundam - Dimension War, Tobidase! Panibon and Virtual Boy Wario Land.
- Opening/closing the Pocket menu now pauses/resumes the game and audio, confirmed on hardware.
- Display modes: left eye red (default), right eye red, red/cyan anaglyph, and left eye white.
- Standard and dual-pad input mappings; complete controls require a compatible Dock controller.
- Virtual Boy platform image and Console category; core identifier `maxhoov.VirtualBoy`.

## Limitations

This is an experimental diagnostic release, not a claim of full compatibility. Save persistence, long sessions, Dock operation and display-mode edge cases need further hardware testing. No save states, sleep, cheats or link support. Diagnostic version remains 5; menu-paused CPU activity 5 is normal. Keep Output test off for gameplay. Use original ROMs, not halfword-swapped diagnostic copies.

Public release numbering starts at 0.1.0. The FPGA bitstream is unchanged from the hardware-tested development build 0.1.5-diag. This package updates repository metadata and documentation only; Diagnostic version remains 5.

Source and issue reports: https://github.com/maxhoov/VirtualBoyPocket

Please include firmware, game name, symptoms and diagnostic values in bug reports; do not attach copyrighted ROMs. Original RTL copyright notices and the included license are retained.
