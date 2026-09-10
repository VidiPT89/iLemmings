# iLemmings 🐹

> A native iOS & macOS puzzle game: guide a crowd of lemmings to safety by assigning them skills before time runs out.

[![Report Bug](https://img.shields.io/badge/Report-Bug-red)](https://github.com/VidiPT89/iLemmings/issues)
[![Request Feature](https://img.shields.io/badge/Request-Feature-blue)](https://github.com/VidiPT89/iLemmings/issues)

## ✨ Features

- ✅ Classic Lemmings gameplay: walking, falling, digging and building lemmings on destructible terrain
- ✅ Eight assignable skills — Climber, Floater, Bomber, Blocker, Builder, Basher, Miner and Digger
- ✅ Tile-based terrain that reacts in real time as lemmings dig, bash and build through it
- ✅ Three hand-built levels teaching each skill, with more room to grow
- ✅ SpriteKit-powered simulation with smooth per-lemming animation and live terrain redraw
- ✅ Pause, retry and win/lose flows with level unlocking
- ✅ Bilingual PT-PT / English in-app language switch (no need to change your device language)
- ✅ Dark, Light and System appearance, with iVidi.dev orange, burnt yellow and black
- ✅ Animated splash screen with developer credits, then straight into the main menu
- ✅ Shared SwiftUI codebase running natively on both iPhone/iPad and Mac

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Simulation & Rendering | SpriteKit |
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
2. Pick an unlocked level — lemmings spawn from the entrance and start walking
3. Tap a skill in the tray at the bottom, then tap a lemming to assign it
4. Use **Builder** to bridge gaps, **Digger**/**Basher**/**Miner** to tunnel through terrain, **Blocker** to redirect the crowd, **Climber**/**Floater** to survive walls and long falls, and **Bomber** to blast an obstacle clear
5. Save enough lemmings through the exit before time runs out to unlock the next level
6. Switch language and appearance any time from **Settings**

## 🧪 Testing

```bash
xcodebuild -project iLemmings.xcodeproj -scheme iLemmings-iOS -destination 'generic/platform=iOS Simulator' build
xcodebuild -project iLemmings.xcodeproj -scheme iLemmings-macOS -destination 'platform=macOS' build
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
