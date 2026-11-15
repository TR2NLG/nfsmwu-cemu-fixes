# Need for Speed Most Wanted U: Shader Cache Crash Fix

By TR2N.

A graphic pack for Cemu that is meant to prevent a start-up crash of Need for Speed Most Wanted U in Cemu 2.6: from one day to the next the game no longer starts, Cemu closes while it shows "Compiling shaders", and `log.txt` ends with `Exception 0x80000003 at ... (+0x48994e) in module Cemu.exe`.

**Only for the EU version with update v32.** The patch addresses belong to that executable (module checksum `0xfc370b5b`). On any other version Cemu does not apply the patch and the pack does nothing.

**The pack prevents new damage, it does not repair.** If your cache already contains the damaged entry, run the Shader Cache Repair script once.

## Installation

1. Copy the folder `NeedForSpeedMostWantedU_ShaderCacheCrashFix` into Cemu's `graphicPacks` folder.
2. In Cemu, open Options > Graphic packs > Need for Speed Most Wanted U > Workaround and enable "Shader Cache Crash Fix".
3. Restart the game. Graphic pack changes only take effect on the next game start.

The pack has no options and works with or without other packs. The existing shader cache stays valid.

## Cause of the crash

A fetch shader is the small program that tells the graphics chip how to read the vertex data of a draw. The game passes it to the system with `GX2SetFetchShader`, as a pointer and a size. Cemu reads the program from the game's memory later, when its graphics thread gets to the draw, and stores it in the shader cache with the size the game declared.

The game reuses the memory of its fetch shaders all the time. Most of them live in a ring with room for 512 fetch shaders that is started again from the beginning many times a second. By the time Cemu reads a program, the memory can already hold the fetch shader of another object. If that one needs more instructions than the declared size covers, Cemu stores a fetch shader that is cut off.

This was verified on an affected cache: of 208 vertex shader entries 207 are complete, and one (`b95e9a31ea76e5f5`) is stored with 48 bytes although its own control instruction announces three fetch instructions, which need 64 bytes. On the next start Cemu reads the third instruction from behind the end of the stored data and stops there. That the reuse of the memory is what produces the mismatch is the likely explanation, but it was not proven.

## How it works

The pack replaces all eight calls of `GX2SetFetchShader` in the game. For every call it

1. works out from the control instructions of the program how many bytes the program really needs,
2. looks up or creates an unchanging copy of the program in memory of its own, one copy per distinct program,
3. passes Cemu a copy of the game's structure that points to this copy and carries the larger of the declared and the needed size.

Cemu therefore never sees a program that changes under it and never a size that is too small, whatever the game does with the original memory afterwards. If the size and the program agree, which is the normal case, the copy is byte for byte what Cemu would have read anyway, so all shader hashes stay the same.

If anything looks implausible (no program, an odd size, a control instruction that points outside the program), or if all 256 places for copies are in use, the original call is made unchanged.

The memory for the copies is the block of zeros at the end of the patch file, 70 KB. That is why the file is large.

At the start of its code cave the pack keeps counters behind the marker `TR2FSHDR` (calls, calls where the program needed more than the declared size, copies made, calls passed through unchanged). They were used for testing and have no effect on the game.

## What was tested

- Cemu 2.6, Vulkan, Windows 10, EU version with update v32
- The patch code as assembled by Cemu was read back from memory and run in a model of the processor against a description of the intended behaviour: 43000 calls with made-up fetch shaders, among them sizes that are too small, too large or odd, and damaged programs. No deviation
- In game while driving: about 630 calls per frame go through the patch, 55 distinct programs, none passed through unchanged, no visible change in image or frame rate
- Together with the "60 FPS", "Audio Fix" and "Exposure and Foliage Fix" packs by the same author

Not tested: other regions and versions (the patch is not applied there), other Cemu versions.

**Not shown yet: that the crash really stays away.** It appeared about once a day on the test system, so only time can tell. Keeping the Shader Cache Repair script as a safety net costs nothing.

## Credits

Graphic pack by TR2N.
