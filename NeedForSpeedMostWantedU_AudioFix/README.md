# Need for Speed Most Wanted U: Audio Fix

By TR2N.

A graphic pack for Cemu that removes a distorted buzzing and hissing noise in Need for Speed Most Wanted U. The noise sounds like a broken horn mixed with white noise and appears for a fraction of a second on every gear shift and while braking.

**Only for the EU version with update v32.** The patch addresses belong to that executable (module checksum `0xfc370b5b`). On any other version Cemu does not apply the patch and the pack does nothing.

## Installation

1. Copy the folder `NeedForSpeedMostWantedU_AudioFix` into Cemu's `graphicPacks` folder.
2. In Cemu, open Options > Graphic packs > Need for Speed Most Wanted U > Workaround and enable "Audio Fix".
3. Restart the game. Graphic pack changes only take effect on the next game start.

The pack has no options. It does not depend on the audio API or latency selected in Cemu and works with or without other packs.

## Cause

The game mixes its sound in software. Sound effects that are stored as DSP ADPCM streams are unpacked in blocks of up to 256 samples at 32 kHz with the system function `AXDecodeAdpcmData` from `snd_core`. Cemu 2.6 does not implement this function: its name is missing from the executable, while the other AX functions the game imports are present. The call returns without writing anything, and the game mixes whatever is left in its buffer on the stack. The same block is then repeated every 8 ms for as long as the sound plays.

In a recording this shows as a comb of spectral lines exactly 125 Hz apart up to more than 15 kHz, and the signal repeats every 384 samples at 48 kHz (256 samples at 32 kHz). In a 35 second drive it appeared 26 times, on every gear shift and in many short bursts while braking.

## How it works

The pack adds a DSP ADPCM decoder to the game's code and redirects the two call sites of `AXDecodeAdpcmData` (`0x02C69714` and `0x031B65CC`, two copies of the same routine) to it.

Before each call the game itself writes the current nibble address (info + 24) and the predictor/scale byte (info + 62) into the `DSPADPCM` structure, and after the call it takes the history values yn1 and yn2 from the last two decoded samples. The decoder therefore only reads the structure (coefficients at info + 28, history at info + 64 and info + 66) and writes the 16 bit output.

At the start of its code cave the pack keeps four counters behind the marker `TR2ADPCM` (calls, decoded samples, sample count and nibble address of the last call). They were used to confirm that the decoder runs and have no effect on the game.

## What was tested

- Cemu 2.6, Vulkan, Windows 10, EU version with update v32
- The assembled routine was read back from Cemu's memory and compared with a reference DSP ADPCM decoder: 3000 runs with random data, 614467 samples, no difference, no writes outside the output buffer
- In game: the noise is gone, and the counters show the decoder being called with blocks of 256 samples while driving
- Together with the "60 FPS" and "Exposure and Foliage Fix" packs by the same author

Not tested: other regions and versions (the patch is not applied there), other Cemu versions. If a later Cemu version implements `AXDecodeAdpcmData`, the pack is no longer needed, but it should do no harm because it replaces the calls completely.

## Credits

Graphic pack by TR2N.
