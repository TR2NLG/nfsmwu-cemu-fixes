# Need for Speed Most Wanted U on Cemu: fixes by TR2N

Four graphic packs and one small tool for Need for Speed Most Wanted U (Wii U) in Cemu 2.6. They fix or work around the problems that made the game unpleasant to play on Cemu: a washed-out daylight image, broken foliage, a distorted noise on every gear shift, slow motion at 60 FPS, and a crash on start that appears from one day to the next.

Each folder has its own README with the details: what was measured, how it works, what was tested and what was not.

## Overview

| Folder | Type | What it does | Works with | Status |
|---|---|---|---|---|
| [`NeedForSpeedMostWantedU_ExposureFoliageFix`](NeedForSpeedMostWantedU_ExposureFoliageFix) | Graphic pack (shaders) | Fixes the far too bright daylight image and the white, pink or striped foliage | All regions (tested: EU) | In daily use |
| [`NeedForSpeedMostWantedU_AudioFix`](NeedForSpeedMostWantedU_AudioFix) | Graphic pack (code patch) | Removes the distorted buzzing and hissing noise on gear shifts and while braking | EU version with update v32 only | In daily use |
| [`NeedForSpeedMostWantedU_60FPS`](NeedForSpeedMostWantedU_60FPS) | Graphic pack (code patch) | Up to 60 FPS with correct game speed, with frame pacing tiers for systems that cannot hold 60 | EU version with update v32 only | Experimental, tested on one system |
| [`NeedForSpeedMostWantedU_ShaderCacheCrashFix`](NeedForSpeedMostWantedU_ShaderCacheCrashFix) | Graphic pack (code patch) | Meant to prevent the crash on start ("Compiling shaders") that appears from one day to the next | EU version with update v32 only | New, not yet proven over time |
| [`NeedForSpeedMostWantedU_ShaderCacheRepair`](NeedForSpeedMostWantedU_ShaderCacheRepair) | PowerShell script | Repairs a shader cache that already makes Cemu crash on start | Cemu 2.6, Windows | Works |

## Installation

1. Download this repository (Code > Download ZIP) and unpack it.
2. Copy the four pack folders (not the repair tool) into Cemu's `graphicPacks` folder.
3. In Cemu, open Options > Graphic packs > Need for Speed Most Wanted U and enable the packs under Workaround and Mods.
4. Disable the community "Bloom Fix" pack if you use the Exposure and Foliage Fix. Both replace the same shader.
5. Restart the game. Graphic pack changes only take effect on the next game start.

The packs are independent of each other and can be used in any combination. On a game version other than EU with update v32 the three code patches are simply not applied, because Cemu matches them against the checksum of the game executable (`0xfc370b5b`).

## What is behind the problems

Three of the four packs work around things that Cemu 2.6 does not do for this game. They are described here because the proper fix for each would be in the emulator.

- **Exposure.** The game renders a 64x64 luminance image every frame and adapts its exposure on the CPU from it. In a captured frame that image is written once and never read on the GPU, and Cemu does not copy it back into guest memory. The exposure therefore never reacts to the image and stays far too high in daylight.
- **Sound.** The game mixes its sound in software and unpacks DSP ADPCM sound effects with `AXDecodeAdpcmData` from `snd_core`. Cemu 2.6 does not implement that function. The call returns without writing anything, and the game plays the old contents of its buffer, repeated every 8 ms.
- **Shader cache.** The game reuses the memory of its fetch shaders many times a second. Cemu reads a fetch shader from guest memory when its graphics thread gets to the draw, with the size the game declared earlier, and stores it in the shader cache with that size. If the memory holds a longer fetch shader by then, the stored one is cut off, and loading it on the next start runs past its end (`Exception 0x80000003` at `Cemu.exe+0x48994e`). In an affected cache, 207 of 208 vertex shader entries were complete and one was stored with 48 bytes while its control instruction announces 64.

The foliage problem and the 60 FPS pack are about the game itself: the foliage shaders leave two of four render targets untouched, and the engine runs exactly one simulation step per frame while driving.

## Test system

Cemu 2.6, Vulkan, Windows 10, Ryzen 9 3900X, GeForce RTX 5070, 2560x1440 at 120 Hz, EU version of the game with update v32, together with the community "Resolution" pack at 3840x2160. Everything was tested on this one system only.

## Credits

By TR2N. The foliage detection in the Exposure and Foliage Fix builds on the idea of the community "Bloom Fix" pack for this game.
