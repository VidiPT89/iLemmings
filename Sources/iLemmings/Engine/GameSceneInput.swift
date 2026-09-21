import SpriteKit

/// Everything that turns a click, a touch or a key into a game action.
///
/// Split out of `GameScene` because the scene was well past the size where
/// the rendering and the input handling stop being one subject — and this
/// half is the one that is almost entirely `#if os(...)`.
extension GameScene {

    // MARK: - Input: tap assigns a skill, drag pans the camera

    #if os(iOS) || os(tvOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        dragStart = t.location(in: self)
        lastPointer = dragStart
        didDrag = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let start = dragStart else { return }
        let location = t.location(in: self)
        lastPointer = location
        let delta = start.x - location.x
        if abs(delta) > 2 {
            didDrag = true
            pan(bySceneDelta: delta)
            dragStart = location
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        if !didDrag { handleTap(at: t.location(in: self)) }
        endTouch()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouch()
    }

    /// Edge-scroll and the hover ring follow the pointer, which on a touch
    /// screen only exists while a finger is down. Leaving the last touch
    /// position behind made a tap near either edge scroll the camera forever
    /// and kept a hover ring stuck on a lemming nobody was pointing at.
    private func endTouch() {
        dragStart = nil
        lastPointer = nil
        didDrag = false
    }
    #elseif os(macOS)
    override func mouseDown(with event: NSEvent) {
        dragStart = event.location(in: self)
        lastPointer = dragStart
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let location = event.location(in: self)
        lastPointer = location
        let delta = start.x - location.x
        if abs(delta) > 2 {
            didDrag = true
            pan(bySceneDelta: delta)
            dragStart = location
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !didDrag { handleTap(at: event.location(in: self)) }
        dragStart = nil
    }

    override func mouseMoved(with event: NSEvent) {
        lastPointer = event.location(in: self)
    }

    override func scrollWheel(with event: NSEvent) {
        pan(bySceneDelta: -event.scrollingDeltaX)
    }
    #endif

    // MARK: - Keyboard
    //
    // `1`-`8` pick a skill in panel order, `-`/`=` trim the release rate,
    // `F` toggles fast-forward and Space pauses — the same set the original
    // bound to the function keys.

    /// Returns false for keys this scene doesn't use, so they fall through to
    /// the rest of the responder chain (menu shortcuts, ⌘Q, and so on).
    private func handleKey(_ characters: String) -> Bool {
        guard let key = characters.lowercased().first else { return false }
        switch key {
        case " ":
            onTogglePause?()
        case "f":
            engine.toggleFastForward()
        case "-", "_":
            engine.changeReleaseRate(-1)
        case "=", "+":
            engine.changeReleaseRate(1)
        case "1"..."8":
            guard let slot = key.wholeNumberValue, LemSkill.allCases.indices.contains(slot - 1) else {
                return false
            }
            engine.selectSkill(LemSkill.allCases[slot - 1])
        default:
            return false
        }
        return true
    }

    #if os(macOS)
    override func keyDown(with event: NSEvent) {
        guard let characters = event.charactersIgnoringModifiers, handleKey(characters) else {
            return super.keyDown(with: event)
        }
    }
    #else
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let unhandled = presses.filter { press in
            guard let characters = press.key?.charactersIgnoringModifiers else { return true }
            return !handleKey(characters)
        }
        if !unhandled.isEmpty { super.pressesBegan(Set(unhandled), with: event) }
    }
    #endif

    private func handleTap(at point: CGPoint) {
        if let id = nearestLiving(to: point) {
            onLemmingTapped?(id)
        }
    }

    private func nearestLiving(to point: CGPoint) -> Int? {
        let radius = tileSize * 1.15
        var best: (Int, CGFloat)?
        for lem in engine.lemmings where lem.canReceiveSkill {
            let p = CGPoint(x: CGFloat(lem.x) * tileSize + tileSize / 2, y: flipRow(lem.y) + tileSize * 0.35)
            let d = hypot(p.x - point.x, p.y - point.y)
            if d <= radius, best == nil || d < best!.1 {
                best = (lem.id, d)
            }
        }
        return best?.0
    }

    func edgeScroll() {
        guard !isEnginePaused, let p = lastPointer else { return }
        let half = size.width * gameCamera.xScale / 2
        let left = gameCamera.position.x - half
        let right = gameCamera.position.x + half
        let band = tileSize * 1.4
        if p.x < left + band {
            pan(bySceneDelta: -2.4)
        } else if p.x > right - band {
            pan(bySceneDelta: 2.4)
        }
    }

    func updateHover() {
        guard let p = lastPointer, let id = nearestLiving(to: p),
              let lem = engine.lemmings.first(where: { $0.id == id }) else {
            hoverRing.isHidden = true
            return
        }
        hoverRing.isHidden = false
        hoverRing.position = CGPoint(x: CGFloat(lem.x) * tileSize + tileSize / 2, y: flipRow(lem.y))
    }
}
