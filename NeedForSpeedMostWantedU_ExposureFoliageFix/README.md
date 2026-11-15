# Need for Speed Most Wanted U: Exposure and Foliage Fix

By TR2N.

A graphic pack for Cemu that fixes two rendering problems in Need for Speed Most Wanted U:

- **Daylight is far too bright.** The image is washed out and covered by a bright veil, the lens dirt effect is exaggerated.
- **Foliage is white, pink or striped,** and can flicker from frame to frame.

It replaces the community "Bloom Fix" pack. Keep that one disabled, both packs replace the same lighting shader.

## Installation

1. Copy the folder `NeedForSpeedMostWantedU_ExposureFoliageFix` into Cemu's `graphicPacks` folder.
2. In Cemu, open Options > Graphic packs > Need for Speed Most Wanted U > Workaround and enable "Exposure and Foliage Fix".
3. Disable "Bloom Fix".
4. Restart the game. Graphic pack changes only take effect on the next game start.

## Options

| Category | Preset | Effect |
|---|---|---|
| Exposure | Wii U Default | Daylight brightness tuned with screenshots from a real Wii U as reference |
| | Darker, Much darker, Brighter, Much brighter | Same behaviour with a different brightness target |
| | Fixed, 20 percent of game exposure | Constant factor, no adaptation at all |
| | Off (game exposure) | Exposure untouched, only the foliage fix is active |
| Adaptation | Standard (default) | Exposure follows the image brightness fairly closely |
| | Calmer | Weaker reaction, less brightness "pumping" when large dark objects enter the view |
| | Full | Keeps the average brightness constant |
| Highlights | Highlights original (default) | The game's tone curve unchanged |
| | Highlights slightly / strongly reduced | Darkens only very bright areas such as the sky. A matter of taste, not a correction |

The image never becomes brighter than what the game itself produces, so night scenes are essentially unchanged.

## What was tested

- Cemu 2.6, Vulkan, Windows 10, NVIDIA GeForce RTX 5070
- EU version, update v32, together with the community "Resolution" pack at 3840x2160
- Day, dusk, night, tunnels and tunnel exits

Not tested: OpenGL, the US and JP versions (their title IDs are listed because the shaders are normally identical across regions), other Cemu versions.

The default exposure was tuned with four screenshots from a real Wii U as reference. On a 0 to 1 scale their average image brightness is 0.28 (median 0.20). Four daytime test captures of city scenes in Cemu give 0.32 (median 0.27) with the "Wii U Default" preset and 0.27 (median 0.23) with "Darker". The scenes differ, so this is a rough match, not an exact calibration.

## Known limitations

- **No memory between frames.** A shader cannot remember the previous frame, so the adaptation is instant where the original is slow. The image brightness can change visibly when a large dark object (a bridge, a sign gantry) enters the view. The "Calmer" preset reduces this.
- **Other effects that use the game exposure.** The game passes its exposure value to many more shaders than this pack replaces (materials, particles, environment maps), and those cannot measure the image brightness themselves. No visible fault from this is known. Sparks are not affected: their shader (`054e33cd8fa5d3d6`) writes a fixed colour into the HDR image, so they follow the corrected scene exposure. Compared with a screenshot from a real Wii U their colour matches (average R231 G211 B165 on the Wii U, R234 G208 B160 with the pack). Without the pack they are broad white blobs.
- Only one tone mapping shader of the game is known and replaced. If the game uses another variant somewhere (for example in a cutscene), that scene will be as bright as without the pack.
- **Stylised race intros are left untouched.** Some intros use a negative look that is graded with a colour table tuned for the exposure the game sets there. With the correction they turned into a black image with a green sky. The pack recognises them by a neutral grey bloom colour together with a game exposure below 8.5 (5.8 to 6.6 in the captured intros, 9.9 to 14.7 while driving) and switches the correction off. Only one intro was captured. If another scene shows wrong colours, set Exposure to "Off (game exposure)" to check whether the pack is the cause.

## How it works

### Exposure

The game renders a 64x64 luminance image every frame (pixel shader `59fa46b6fd2d24a0`) and adjusts its exposure on the CPU from it. In a captured frame this render target is written once and never read by any draw or copy on the GPU, so the CPU is its only consumer. Cemu does not copy it back into guest memory, with or without a resolution pack. The exposure value therefore only changes with time of day and location and never reacts to the image. In daylight it sits at 11.54 where a far lower value would be needed.

The pack replaces three pixel shaders:

- `a638574ed895c2c1` (tone mapping, `y = 1 - 2^(-x)`): takes 32 samples of the blurred bloom texture, which already contains the game exposure, limits single outliers, and computes a factor `k = min(target * mean^-response, target * ceiling / mean)`. Scene exposure and bloom are multiplied by `k`. Optionally compresses highlights above a knee.
- `39fc1961106f4ba9` and `176a1cf8c8bf1ee5` (lens dirt): apply the same factor to the bloom part and to the sun part of the overlay. The sun part arrives already tone mapped with the game exposure from the vertex shader, so it is recomputed as `1 - (1 - y)^k`.

### Foliage

The foliage G-buffer shaders write only two of the four render targets (normals and albedo). Cemu binds only the targets a shader writes, so the other two keep old data at foliage pixels, and the game does not clear the full resolution G-buffer:

- The glow buffer holds the **finished image of the previous frame**, because the same memory is used as the target of the final composite. Glow is added to the lighting result, which creates a frame-to-frame feedback loop and turns trees white.
- The specular buffer holds the **bits of the depth buffer**, because the same memory is used for an R32F depth copy. This produces the pink and yellow stripes. The alpha channel is exactly 63/255 there, the exponent byte of a depth value.

The pack replaces both variants of the deferred lighting shader (`0265594cffa53eb8` and `3693ec2543b04fca`). A pixel counts as foliage if the specular alpha is exactly 63/255 and either the glow alpha lies strictly between 0 and 1 or the specular colour looks like depth bits. Glow and specular are set to zero for those pixels. The check on glow alpha alone, as used by the community "Bloom Fix" pack, also hits valid pixels of traffic cars, and specular alpha 63 alone hits parts of the player car, so both conditions are combined.

## Credits

Graphic pack by TR2N.

The foliage detection builds on the idea of the community "Bloom Fix" pack for this game.
