# iLemmings 🐹

> A native iOS & macOS puzzle game: guide a crowd of lemmings to safety by assigning them skills before time runs out.

[![Report Bug](https://img.shields.io/badge/Report-Bug-red)](https://github.com/VidiPT89/iLemmings/issues)
[![Request Feature](https://img.shields.io/badge/Request-Feature-blue)](https://github.com/VidiPT89/iLemmings/issues)

## ✨ Features

- ✅ Classic Lemmings gameplay: walking, falling, digging and building lemmings on destructible terrain
- ✅ Eight assignable skills — Climber, Floater, Bomber, Blocker, Builder, Basher, Miner and Digger
- ✅ Rules taken from the 1991 original: the hatch opens before the first lemming drops, the release rate follows the original curve, lemmings walking off the map or falling through its floor are lost, skills can be switched mid-job, and a falling Bomber goes off without its Oh-No
- ✅ A level briefing before every level (lemmings, % to be saved, release rate, time, rating) and a "you rescued / you needed" result screen
- ✅ Release rate, fast-forward, Nuke, a clickable minimap with a viewport box, and a single bottom control panel with OUT / IN / TIME
- ✅ Hand-drawn pixel-art lemmings (green hair, blue overalls) with a distinct animation for every job — walking, falling, climbing, floating, digging, bashing, mining, building, blocking, shrugging, the Oh-No panic, splatting and drowning
- ✅ Tile-based terrain that reacts in real time as lemmings dig, bash and build through it, each material drawn with its own pattern — dithered dirt, grass tufts, Builder brick staircases, riveted steel plates, spikes and animated water
- ✅ Particle effects — dust while tunnelling, an explosion flash on the Bomber, confetti on victory
- ✅ Eight built-in levels across Fun, Tricky, Taxing and Mayhem, including water that drowns (floaters do not save you)
- ✅ SFX and haptic feedback on skill assignment, rescued lemmings, level win and level loss, with a one-tap mute
- ✅ Pause, retry and win/lose flows with level unlocking
- ✅ Bilingual PT-PT / English in-app language switch backed by real `.lproj` bundles, no need to change your device language
- ✅ Dark, Light and System appearance, with iVidi.dev orange, burnt yellow and black
- ✅ Animated splash screen with developer credits, then straight into the main menu
- ✅ Shared SwiftUI codebase running natively on both iPhone/iPad and Mac

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Simulation & Rendering | SpriteKit |
| Audio | AVFoundation (synthesized SFX) |
| Project | XcodeGen |
| Min. iOS | 17.0 |
| Min. macOS | 14.0 |

## 🚀 Quick Start

### Prerequisites

- Xcode 15+ on macOS
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you change the file structure (`brew install xcodegen`)

### Installation

```bash
git clone https://github.com/VidiPT89/iLemmings.git
cd iLemmings
open iLemmings.xcodeproj
```

Pick the `iLemmings-iOS` or `iLemmings-macOS` scheme and run (`⌘R`).

> The Xcode project is generated with XcodeGen from `project.yml`. If you add or move Swift files, regenerate it with `xcodegen generate`.

## 📖 Usage

1. Watch the splash screen, then choose **Play** or **Levels** from the main menu
2. Pick an unlocked level from one of the four packs, read the briefing and tap (or press any key) to start — the hatch opens and the lemmings start walking
3. Tap a skill in the control panel at the bottom, then tap a lemming to assign it (the skill stays selected so you can assign it again)
4. Use **Builder** to bridge gaps, **Digger**/**Basher**/**Miner** to tunnel through terrain, **Blocker** to redirect the crowd, **Climber**/**Floater** to survive walls and long falls, and **Bomber** to blast an obstacle clear
5. **− / +** change how fast new lemmings spawn. **Fast-forward** speeds the whole level up. Stuck? **Nuke** arms the Bomber countdown one lemming at a time
6. Keyboard: `1`–`8` skills, `−`/`=` release rate, `F` fast-forward, `Space` pause. Move the pointer to a screen edge, drag the level, or click the minimap to scroll
7. Save enough lemmings through the exit before time runs out to earn stars and unlock the next level
8. Switch language, appearance and sound any time from **Settings**

## 🧪 Testing

```bash
xcodebuild -project iLemmings.xcodeproj -scheme iLemmings-macOS -destination 'platform=macOS' test
xcodebuild -project iLemmings.xcodeproj -scheme iLemmings-iOS -destination 'generic/platform=iOS Simulator' build
xcodebuild -project iLemmings.xcodeproj -scheme iLemmings-macOS -destination 'platform=macOS' build
```

The suite covers the original's rules one by one, checks every built-in level is winnable, plays each level hundreds of times with random skills to check nothing is ever miscounted or buried in the ground, and renders the playfield off-screen. To save those renders as PNGs:

```bash
TEST_RUNNER_ILEMMINGS_SNAPSHOT_DIR=/tmp/ilemmings xcodebuild -project iLemmings.xcodeproj \
  -scheme iLemmings-macOS -destination 'platform=macOS' \
  -only-testing:iLemmingsTests/SceneSnapshotTests test
```

## 📄 License

Distributed under the MIT License. See [LICENSE](LICENSE) for details.

## 👨‍💻 Author

**David Arsénio Martins**

- 🌐 Website: [ividi.dev](https://ividi.dev)
- 🐙 GitHub: [@VidiPT89](https://github.com/VidiPT89)

## 🤝 Contributing

Contributions, issues and feature requests are welcome. Feel free to check the [issues page](https://github.com/VidiPT89/iLemmings/issues).

---

<p align="center">Developed by <a href="https://ividi.dev">David Arsénio Martins</a></p>
<p align="center">⭐ If you like this project, give it a star!</p>
