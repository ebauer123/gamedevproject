# Mirror's Edge Rooftop Parkour (Godot 4)

A grounded, physics-based first-person parkour game inspired by *Mirror's Edge*. Emphasizes momentum (flow), real-life human movement limits, ledge mantling, skill rolls, and the iconic stark white & Runner Red rooftop aesthetic.

---

## 🎮 Parkour Controls

| Action | Key / Input | Description |
|---|---|---|
| **Move** | <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd> | Ground movement. Running continuously forward builds **Momentum (Flow)**. |
| **Look** | Mouse | First-person camera with authentic Runner Dot to prevent motion sickness. |
| **Jump** | <kbd>Space</kbd> | Jump distance scales with forward momentum (no arcade double jumps!). |
| **Sprint** | Hold <kbd>Shift</kbd> | Accelerates your flow up to top sprint speed (10.2 m/s). |
| **Slide** | Press / Hold <kbd>Ctrl</kbd> or <kbd>C</kbd> | Slide under low ventilation ducts and pipes while sprinting. |
| **Ledge Grab & Hang** | Airborne towards a ledge | Player grabs the parapet edge with their hands. |
| **Mantle Up** | <kbd>W</kbd> or <kbd>Space</kbd> (while hanging) | Pulls up onto the roof ledge smoothly and continues running. |
| **Drop from Ledge** | <kbd>S</kbd> or <kbd>Ctrl</kbd> (while hanging) | Lets go of the ledge and drops down. |
| **Speed Vault** | <kbd>Space</kbd> near low obstacle | Clean one-handed speed vault over AC units without breaking stride. |
| **Skill Roll** | Press <kbd>Ctrl</kbd> before high drop impact | Performs a 360° forward roll, absorbing impact and preserving sprint momentum! |
| **Hard Landing** | Fail to roll from high drop | Impact slam and stumble: immobilizes player for 0.65s and resets momentum. |
| **Vertical Wall Climb (Tic-Tac)** | Run at a high wall + <kbd>Space</kbd> | Kicks off the wall upward to reach high ledges or grab parapets. |
| **Wallrun (Horizontal)** | Run along a vertical wall + jump | Wallruns along red panels with 14° camera tilt. Press <kbd>Space</kbd> to kick off! |
| **Restart Checkpoint** | <kbd>R</kbd> | Respawns instantly at the current rooftop checkpoint. |
| **Pause Menu** | <kbd>Esc</kbd> | Releases mouse and opens the pause menu. |

---

## 🔴 Runner Vision & Environmental Obstacles

True to *Mirror's Edge*, the environment features minimalist white/grey architecture with **Runner Red** objects indicating the flow path:

1. **Springboard AC Units (`scenes/ac_unit.tscn`)**:
   - Heavy industrial HVAC units with **Runner Red** rubber launch pads. Stepping on them propels you across long rooftop gaps.
2. **Slide Vents (`scenes/vent_duct.tscn`)**:
   - Industrial air ducts hovering 1m above the roof. Slide under at full sprint!
3. **Red Balance Pipes (`scenes/balance_pipe.tscn`)**:
   - Narrow steel conduits spanning between rooftop towers, requiring precise balance.
4. **Wallrun Billboards (`scenes/wallrun_panel.tscn`)**:
   - Red hoarding panels mounted along skyscraper alleyway gaps for horizontal wall running.
5. **Tic-Tac Parapet Walls**:
   - 3.2m tall red-topped walls that require a vertical kick climb to grab and mantle.
6. **Runner Messenger Bags (`scenes/collectible.tscn`)**:
   - 6 hidden yellow courier satchels scattered across the rooftops for thorough exploration.
7. **Extraction Door (`scenes/finish_goal.tscn`)**:
   - The iconic red exit doorway with an illuminated green sign marking the end of the run!

---

## 🎧 Procedural Sound Design (`scripts/sound_manager.gd`)

Zero external audio files required! Synthesizes 12 custom grounded audio effects in real-time:
- Rhythmic footsteps calibrated to ground speed
- Leg push jump take-offs
- Hand slaps on concrete ledges (`grab`)
- Effort pull-up sounds (`mantle`)
- 360° cloth whoosh for parkour rolls
- Heavy landing crunch & stun thuds
- Metal springboard thumps
- Clean runner checkpoint chimes and extraction completion fanfare

---

## 🏙️ Rooftop Course Progression (`scenes/main.tscn`)

- **Rooftop 1**: Warmup roof with an AC speed vault, low slide duct, Runner Bag #1, and an edge springboard.
- **Rooftop 2**: Rooftop gap leap + ledge mantle onto **Checkpoint 1**, followed by a tall 3.2m Tic-Tac wall climb up to the upper deck.
- **Rooftop 3**: Alleyway chasm with a Red Wallrun Billboard and floating Runner Bag #3, landing on the **Checkpoint 2** catwalk.
- **Rooftop 4**: Long Red Balance Pipe crossing, leading to a high 5m vertical drop requiring a **Timed Parkour Roll (<kbd>Ctrl</kbd>)** to reach **Checkpoint 3**.
- **Rooftop 5**: Second slide duct, hidden Runner Bag, and a high-velocity springboard launch over the final abyss.
- **Rooftop 6 (Summit Tower)**: Extraction helipad roof with Runner Bag #6 and the final Red Rooftop Extraction Door!
