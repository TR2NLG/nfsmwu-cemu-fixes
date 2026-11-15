# Need for Speed Most Wanted U: 60 FPS

By TR2N.

A graphic pack for Cemu that lets Need for Speed Most Wanted U run at up to 60 frames per second instead of 30 and keeps the game speed correct when the system cannot hold 60.

**Only for the EU version with update v32.** The patch addresses belong to that executable (module checksum `0xfc370b5b`). On any other version Cemu does not apply the patch and the pack does nothing.

**Experimental.** It was tested on one system only.

## Why the pack has modes

While driving, the engine runs exactly one simulation step per frame. With a fixed step of 1/60 s the game turns into slow motion as soon as the frame rate drops below 60. The simulation step is the expensive part of a frame and runs on a single thread, so even a fast CPU does not hold 60 FPS everywhere. On the test system (Ryzen 9 3900X) the game reaches 60 in menus and about 30 to 40 while driving, with the graphics card far from its limit.

The pack therefore changes frame time and step length together. The camera reacts badly to a step length that changes from frame to frame (the world seems to "pump"), which is why the default mode keeps the step constant and only switches between a few fixed tiers.

## Installation

1. Copy the folder `NeedForSpeedMostWantedU_60FPS` into Cemu's `graphicPacks` folder.
2. In Cemu, open Options > Graphic packs > Need for Speed Most Wanted U > Mods and enable "60 FPS".
3. Pick the mode that fits your display (see below).
4. Restart the game. Graphic pack changes only take effect on the next game start.

## Options

| Category | Preset | Effect |
|---|---|---|
| Mode | Frame pacing 60/40/30 (default) | Every frame lasts exactly 1/60, 1/40 or 1/30 s and is simulated with a step of the same length. The tier follows the measured work time per frame. For 120 Hz and variable refresh rate displays |
| | Frame pacing 60/40/30/24 | Adds a 24 FPS tier for scenes that cannot hold 30 |
| | Frame pacing 60/30 | Only the two tiers that fit a 60 Hz display |
| | Variable step (smoothed) | No fixed frame times. The step follows the average frame time in increments of 1/300 s. Some pumping remains, most visible while accelerating |
| | Variable step (direct) | The step is doubled after a late frame. Strong pumping |
| | Frame skip | The engine runs two steps in a frame that follows a late one. Only for very fast CPUs, on the test system it fell to 20 FPS in heavy scenes |
| | Fixed time step | Always 1/60 s. Slow motion below 60 FPS |
| Cutscenes | Cutscenes paced (default) | Cutscenes and the crash camera are treated like driving, one step per frame |
| | Cutscenes original | The game runs up to three steps of 1/60 s per frame there, which was 15 to 24 FPS on the test system. Always used in the frame skip and fixed time step modes |

Which mode for which display:

- **120 Hz or variable refresh rate:** Frame pacing 60/40/30. All three tiers divide 120 evenly.
- **60 Hz:** Frame pacing 60/30.
- **144 Hz without variable refresh rate:** none of the tiers fits evenly. Not tested.

## What was tested

- Cemu 2.6, Vulkan, VSync on, Windows 10, Ryzen 9 3900X, GeForce RTX 5070, 2560x1440 at 120 Hz
- EU version, update v32, together with the community "Resolution" pack at 3840x2160
- Mode "Frame pacing 60/40/30": game time against real time 0.996 to 1.000 over several drives, the race clock advances 20.00 s per 20 s of video, exactly 40.0 or 30.0 FPS inside a tier
- "Cutscenes paced": race intros and the crash camera run at exactly 40 or 30 FPS with game time 1.000

Not tested: other regions and versions (the patch is not applied there), 60 Hz and 144 Hz displays, other CPUs, other Cemu versions.

## Known limitations

- **Below the slowest tier the game slows down,** as it does without the pack. On the test system this happens in circuit races with many opponents (about 28 FPS, speed 0.95).
- **A tier change is visible as a small jump.** The pack switches reluctantly: on the test system about one to two changes per minute.
- **Paced cutscenes do not catch up.** A cutscene that cannot hold 30 FPS runs slower instead of skipping ahead, so picture and sound could drift apart. This was not observed in testing. "Cutscenes original" restores the game's own behaviour.
- Videos such as the intro are not changed.
- At the start of its code cave the pack keeps a statistics block (marker `TR2FPSv7`: frames, steps, tier, late frames and so on) that was used for measuring. It has no effect on the game.

## How it works

- `0x03288C5C`: the game sets swap interval 2, changed to 1.
- `0x10007B04`: the initial timer step 1/30 s, changed to 1/60 s.
- `0x020C469C`, right after the engine's step control (`0x02CA22F8`): measures real time with `OSGetSystemTime`, chooses the tier from a smoothed work time per frame (slower from 15.0, 24.0 and 32.0 ms, faster below 12.5, 21.5 and 29.0 ms, with hold times that grow when a change has to be taken back), writes the step for this frame into the game object (+268) and, in the tiers below 60, waits until the frame is due on a fixed schedule.
- `0x020C4684`: time stamp before the step control, used for the work time.
- `0x020C0470` and `0x020C0448`: the two places where the game selects the step control mode every frame (normal play, cutscenes and crash camera).
- `0x023AAE2C`: a counter in units of 1/300 s that only knew steps of 1/25, 1/30, 1/50 and 1/60 s and stood still for any other step. Replaced by one that accumulates any step length.

A constant 1/30 s at `0x10000200` belongs to the video player and must stay as it is, otherwise videos play at double speed.

## Credits

Graphic pack by TR2N.
