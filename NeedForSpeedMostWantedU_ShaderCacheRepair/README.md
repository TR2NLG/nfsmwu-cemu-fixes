# Need for Speed Most Wanted U: Shader Cache Repair

By TR2N.

A small PowerShell script for a start-up crash of Need for Speed Most Wanted U in Cemu 2.6. This is not a graphic pack.

## Symptom

The game no longer starts. Cemu closes while it shows "Compiling shaders" (loading the shader cache), and `log.txt` ends with

```
Exception 0x80000003 at ... (+0x48994e) in module Cemu.exe
```

The crash happens with and without graphic packs. It appears from one day to the next, after a session in which the game used one particular shader for the first time.

## Cause

Cemu stores every shader the game uses in `shaderCache\transferable\<titleId>_shaders.bin`. One vertex shader of this game (base hash `b95e9a31ea76e5f5`) works while playing, but Cemu 2.6 crashes when it loads that entry from the cache on the next start. With the entry removed, the game starts again. All other entries stay valid.

What is wrong with the entry: its stored fetch shader is 48 bytes long, which is room for two vertex fetch instructions, but its own control instruction announces three (64 bytes). Cemu stores a fetch shader with the size the game declared and reads it back by its instruction count, so the loader runs past the end of the stored data. The crash location in Cemu is a loop over 16 byte instructions that stops on an unexpected instruction type. This was checked by unpacking the stored fetch shaders of all 208 vertex shader entries of the affected cache: 207 are complete, only this one is too short.

Where the mismatch comes from is not proven. The game keeps its fetch shaders in a ring with room for 512 of them and overwrites old ones when the ring is full, so an object can end up drawing with the size of its own fetch shader and the contents of another one.

The game creates the shader again whenever it needs it, and Cemu writes it into the cache again. The crash can therefore return. On the test system it came back once within a day.

For the EU version with update v32 there is also the graphic pack "Shader Cache Crash Fix" by the same author, which is meant to stop the damaged entry from being created in the first place. This script is still needed once if the cache is already damaged.

## Usage

Close Cemu, then run the script:

```
powershell -ExecutionPolicy Bypass -File Repair-ShaderCache.ps1
```

It looks for the cache in `%APPDATA%\Cemu` and, for a portable Cemu, in the folder the script is in. A different location can be passed with `-CachePath <file>`. With `-ReportOnly` it only reports what it would do.

Before the script changes a cache file it writes a backup next to it (`..._shaders.bin.bak-<date>-<time>`). If the entry is not present it changes nothing.

### Running it before every start

Copy `Repair-ShaderCache.ps1` and `Start-Cemu-With-Repair.cmd` next to `Cemu.exe` and start Cemu with the `.cmd` file. It runs the repair, which takes a fraction of a second, and then starts Cemu. That way the crash never shows.

## What was tested

- Cemu 2.6, Windows 10, EU version of the game (title ID `0005000010128400`) with update v32
- The crash disappears when only this one entry is removed (535 instead of 536 shaders at the time), and returns when the entry is put back

Not tested: other regions (their caches are searched as well, but whether the shader has the same hash there is unknown), other Cemu versions.

## File format, for the curious

The file starts with the magic `96 b6 71 83`. The data starts at the offset stored at byte 8, the file table at that offset plus the value at byte 16, the table size in bytes is at byte 24. Each table entry has 32 bytes: name 1 (base hash with the top three bits replaced by the shader type), name 2 (auxiliary hash), offset, size and flags. An entry filled with zeros counts as free. The entry data starts with a version byte and the full base hash in big endian.

## Credits

Script by TR2N.
