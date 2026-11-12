# 3D Parkour Game (Godot 4)

A fast-paced, responsive 3D first-person parkour game built in Godot 4 with native GDScript, procedural sound effects, and stylized visual feedback.

---

## 🎮 Controls

| Action | Key / Input |
|---|---|
| **Move** | `W` `A` `S` `D` (or Arrow keys) |
| **Look** | Mouse (Click window to capture mouse, `Esc` to release/pause) |
| **Jump** | `Space` |
| **Double Jump** | `Space` in mid-air |
| **Sprint** | `Shift` (Hold while moving forward) |
| **Slide / Crouch** | `Ctrl` or `C` (Hold while sprinting to slide under low obstacles) |
| **Wall Run** | Jump and press against a vertical wall while in the air |
| **Wall Jump** | Press `Space` while wall running to kick off |
| **Ledge Vault** | Jump towards a waist/chest-high ledge to automatically mantle over |
| **Quick Respawn**| `R` (Respawns instantly at current active checkpoint) |
| **Pause / Menu** | `Esc` |

---

## 🚀 Game Features & Mechanics

1. **Responsive Movement Controller (`scripts/player.gd`)**:
   - **Coyote Time & Jump Buffering**: Generous 0.15s windows for crisp, forgiving platforming feel.
   - **Double Jump**: Mid-air propulsion for recovering or extending jump lines.
   - **Wall Running & Wall Jumping**: Fluid wall grip with camera tilt (12°) and perpendicular launch kicks.
   - **Sliding System**: Slide with lowered camera, reduced collision capsule, and initial speed boost decay.
   - **Ledge Vaulting (Mantling)**: Three-raycast detection (chest, head clearance, and surface probe) to vault over obstacles.
   - **Dynamic FOV & Head Bob**: FOV expands dynamically from 75° up to 92° during sprints, slides, and speed boosts.
   - **Landing Impact Feedback**: Camera dip scaling with landing velocity.

2. **Interactive Course Elements**:
   - **Checkpoints (`scenes/checkpoint.tscn`)**: Glowing pads with spinning markers that save progress and turn cyan upon activation.
   - **Jump Pads (`scenes/jump_pad.tscn`)**: Bounce pads with squash & stretch physics launching the player high into the air.
   - **Speed Boost Pads (`scenes/boost_pad.tscn`)**: High-velocity accelerator pads for clearing massive sky gaps.
   - **Moving Platforms (`scenes/moving_platform.tscn`)**: `AnimatableBody3D` synchronized platforms with smooth sinusoidal easing (horizontal and vertical).
   - **Crumbling Platforms (`scenes/falling_platform.tscn`)**: Platforms that shake upon landing, drop away, and respawn after 3 seconds.
   - **Collectibles (`scenes/collectible.tscn`)**: Floating golden tokens placed along rewarding and high-risk parkour paths.
   - **Finish Goal (`scenes/finish_goal.tscn`)**: A rotating energy portal marking course completion with victory fanfare and statistics.

3. **Procedural Audio Synthesizer (`scripts/sound_manager.gd`)**:
   - Zero external audio files required! Synthesizes 11 custom 16-bit PCM sound effects in memory on startup:
	 - Jump, Double Jump, Land, Wall Jump, Slide, Checkpoint Chime, Coin Ding, Speed Boost, Platform Crumble, Respawn, and Victory Fanfare.

4. **HUD & UI System (`scenes/hud.tscn`)**:
   - Real-time speedometer (m/s).
   - Live MM:SS.ms timer.
   - Checkpoint tracker and collectible counter.
   - Minimalist crosshair and control hints.
   - Victory overlay with summary stats (Time, Tokens, Respawns) and Play Again button.
   - Pause menu with Resume and Restart options.

---

## 🗺️ Parkour Course Layout (`scenes/main.tscn`)

The course is divided into 5 progressive sections:
- **Tutorial Area**: Basic movement, low vault wall (mantling test), and a low overhead barrier (slide test).
- **Stage 1 (Stepping Stones & Moving Platform)**: Precision jumps and a horizontally oscillating platform leading to **Checkpoint 1**.
- **Stage 2 (Vertical Ascent & Jump Pad)**: High-power bounce pad leap into an airborne token, leading to a vertical elevator platform and **Checkpoint 2**.
- **Stage 3 (Wall Running Canyon)**: High-altitude floating walls requiring alternating left and right wall runs to reach **Checkpoint 3**.
- **Stage 4 (Crumbling Platforms & Narrow Beam)**: Timed jumps across collapsing platforms and a narrow balance beam leading to **Checkpoint 4**.
- **Stage 5 (Speed Boost & Victory Summit)**: High-speed runway launching across a canyon into a secondary jump pad, reaching the **Summit Portal**!

---

## 🕹️ How to Run in Godot

1. Open **Godot 4** and choose **Import** or select this project folder (`GroupProject` / `3D Parkour Game`).
2. Press **F5** (or click the **Play** button in the top-right corner) to run the game!
3. Alternatively, open `scenes/main.tscn` and press **F6** to test the scene directly.
