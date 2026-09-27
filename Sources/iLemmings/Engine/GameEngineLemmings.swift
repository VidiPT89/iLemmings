import Foundation

/// What each lemming does on one tick, job by job.
///
/// Split out of `GameEngine` so that file is about the level as a whole
/// (spawning, skills, the clock, winning and losing) and this one is about
/// a single lemming walking, falling, digging and dying on the terrain.
extension GameEngine {

    func stepLemming(_ lem: inout Lemming) {
        guard lem.isAlive else { return }
        let col = Int(lem.x.rounded())

        // Walked off either side or fell through the bottom of the level.
        if col < 0 || col >= width || lem.y >= height {
            lem.state = .dead
            lem.countdownTicks = 0
            countDeath()
            return
        }

        switch lem.state {
        case .drowning(let ticksLeft):
            lem.state = ticksLeft <= 0 ? .dead : .drowning(ticksLeft: ticksLeft - 1)
            return
        case .splatting(let ticksLeft):
            lem.state = ticksLeft <= 0 ? .dead : .splatting(ticksLeft: ticksLeft - 1)
            return
        case .ohNo(let ticksLeft):
            if ticksLeft <= 0 {
                explode(&lem, col: col)
                return
            }
            lem.state = .ohNo(ticksLeft: ticksLeft - 1)
            // An Oh-No lemming still falls if the ground goes from under it.
            lem.actionProgress += 1
            if lem.actionProgress >= GameTuning.fallTicksPerStep {
                lem.actionProgress = 0
                if !tile(lem.y + 1, col).isSolid { lem.y += 1 }
            }
            return
        default:
            break
        }

        if lem.countdownTicks > 0 {
            lem.countdownTicks -= 1
            if lem.countdownTicks == 0 {
                // A bomber whose fuse runs out in mid-air goes off at once;
                // anyone else stops for the Oh-No first (Lemmix `baExploding`).
                switch lem.state {
                case .falling, .floating:
                    explode(&lem, col: col)
                default:
                    lem.state = .ohNo(ticksLeft: GameTuning.ohNoTicks)
                    lem.actionProgress = 0
                }
                return
            }
        }

        if case .shrugging(let ticksLeft) = lem.state {
            lem.state = ticksLeft <= 0 ? .walking : .shrugging(ticksLeft: ticksLeft - 1)
            return
        }

        if tile(lem.y, col) == .water {
            drown(&lem)
            return
        }
        if tile(lem.y, col) == .trap {
            splat(&lem)
            return
        }
        if tile(lem.y, col) == .exit {
            lem.state = .saved
            lem.countdownTicks = 0
            countSaved()
            return
        }

        let dir = lem.facingRight ? 1 : -1
        let frontCol = col + dir

        switch lem.state {
        case .falling:
            lem.actionProgress += 1
            guard lem.actionProgress >= GameTuning.fallTicksPerStep else { break }
            lem.actionProgress = 0
            let below = lem.y + 1
            if tile(below, col).isSolid {
                if lem.fallDistance > GameTuning.maxSafeFall && !lem.hasFloater {
                    splat(&lem)
                } else {
                    lem.state = .walking
                    lem.fallDistance = 0
                }
            } else {
                lem.y = below
                lem.fallDistance += 1
                lem.state = lem.hasFloater && lem.fallDistance > 1 ? .floating : .falling
            }

        case .floating:
            lem.actionProgress += 1
            guard lem.actionProgress >= GameTuning.floatTicksPerStep else { break }
            lem.actionProgress = 0
            let below = lem.y + 1
            if tile(below, col).isSolid {
                lem.state = .walking
                lem.fallDistance = 0
            } else {
                lem.y = below
            }

        case .walking:
            lem.actionProgress += 1
            if lem.actionProgress >= GameTuning.walkTicksPerStep {
                lem.actionProgress = 0
                walk(&lem)
            }

        case .blocking:
            // Stands still indefinitely, acting as an obstacle in walk() — but
            // only while it still has ground under it.
            if !tile(lem.y + 1, col).isSolid {
                startFalling(&lem)
            }

        case .building(let steps):
            lem.actionProgress += 1
            guard lem.actionProgress >= GameTuning.workTicksPerStep else { break }
            lem.actionProgress = 0
            // Each step lays a brick at (lem.y, frontCol) — the footing of
            // the spot one tile forward and one row up — and moves there,
            // so brick and lemming stay locked together.
            let brick = tile(lem.y, frontCol)
            if steps <= 0 {
                lem.state = .shrugging(ticksLeft: 16)
            } else if tile(lem.y - 1, frontCol).isSolid || tile(lem.y - 1, col).isSolid {
                // Head hit terrain: the original turns the builder around and
                // walks it away, it doesn't stand there shrugging.
                lem.facingRight.toggle()
                lem.state = .walking
            } else if !brick.isSolid && brick != .empty {
                // Never lay a brick over the exit, water, spikes or the hatch.
                lem.state = .walking
            } else {
                if brick == .empty { setTile(lem.y, frontCol, .brick) }
                lem.y -= 1
                lem.x = Double(frontCol)
                lem.state = .building(stepsLeft: steps - 1)
            }

        case .basher:
            lem.actionProgress += 1
            guard lem.actionProgress >= GameTuning.workTicksPerStep else { break }
            lem.actionProgress = 0
            let front = tile(lem.y, frontCol)
            if !front.isDiggable {
                // Nothing left to bash, or steel: back to walking (a walker
                // then turns around at the steel).
                lem.state = .walking
            } else {
                setTile(lem.y, frontCol, .empty)
                lem.x = Double(frontCol)
                if !tile(lem.y + 1, frontCol).isSolid { startFalling(&lem) }
            }

        case .miner:
            lem.actionProgress += 1
            guard lem.actionProgress >= GameTuning.workTicksPerStep else { break }
            lem.actionProgress = 0
            let front = tile(lem.y, frontCol)
            let frontBelow = tile(lem.y + 1, frontCol)
            if front == .steel || frontBelow == .steel {
                lem.state = .walking
            } else {
                // Only earth is dug away — the exit, water and spikes stay put.
                if front.isDiggable { setTile(lem.y, frontCol, .empty) }
                if frontBelow.isDiggable { setTile(lem.y + 1, frontCol, .empty) }
                lem.x = Double(frontCol)
                lem.y += 1
                // Tunnelled out into open air: fall, don't keep mining the sky.
                if !tile(lem.y + 1, frontCol).isSolid { startFalling(&lem) }
            }

        case .digger:
            lem.actionProgress += 1
            guard lem.actionProgress >= GameTuning.walkTicksPerStep else { break }
            lem.actionProgress = 0
            let below = tile(lem.y + 1, col)
            if below == .steel {
                lem.state = .walking
            } else if !below.isDiggable {
                startFalling(&lem)
            } else {
                setTile(lem.y + 1, col, .empty)
                lem.y += 1
            }

        case .climbing:
            lem.actionProgress += 1
            guard lem.actionProgress >= GameTuning.climbTicksPerStep else { break }
            lem.actionProgress = 0
            let above = lem.y - 1
            if tile(above, col).isSolid {
                // Hit its head on an overhang (or the top of the level): the
                // original lets go, turns round and drops.
                lem.facingRight.toggle()
                startFalling(&lem)
            } else if tile(above, frontCol).isSolid {
                lem.y = above
            } else {
                lem.y = above
                lem.x = Double(frontCol)
                lem.state = .walking
            }

        case .shrugging, .splatting, .drowning, .ohNo, .saved, .dead:
            break
        }
    }

    private func startFalling(_ lem: inout Lemming) {
        lem.state = .falling
        lem.actionProgress = 0
        lem.fallDistance = 0
    }

    private func drown(_ lem: inout Lemming) {
        guard lem.isAlive else { return }
        if case .drowning = lem.state { return }
        if case .splatting = lem.state { return }
        lem.state = .drowning(ticksLeft: 16)
        lem.countdownTicks = 0
        countDeath()
    }

    private func splat(_ lem: inout Lemming) {
        guard lem.isAlive else { return }
        if case .splatting = lem.state { return }
        lem.state = .splatting(ticksLeft: 16)
        lem.countdownTicks = 0
        countDeath()
    }

    /// The lemming dies and takes a crater of diggable ground with it.
    /// Steel, exits, hatches and traps stay, matching LemmingsJS
    /// `clearGroundWithMask` (only terrain is ever removed).
    private func explode(_ lem: inout Lemming, col: Int) {
        for dr in -1...1 {
            for dc in -1...1 where tile(lem.y + dr, col + dc).isDiggable {
                setTile(lem.y + dr, col + dc, .empty)
            }
        }
        lem.state = .dead
        lem.exploded = true
        lem.countdownTicks = 0
        countDeath()
    }

    private func walk(_ lem: inout Lemming) {
        let col = Int(lem.x.rounded())
        let dir = lem.facingRight ? 1 : -1
        let frontCol = col + dir

        // A blocker turns round anyone about to step into its tile, whether
        // on the level or stepping up to it. One already on the same tile
        // (it fell there, or the blocker was placed on top of it) walks out
        // instead of flipping back and forth on the spot for ever.
        let blockedByLemming = lemmings.contains { other in
            guard other.id != lem.id, other.state == .blocking else { return false }
            return Int(other.x.rounded()) == frontCol && (other.y == lem.y || other.y == lem.y - 1)
        }
        if blockedByLemming {
            lem.facingRight.toggle()
            return
        }

        if !tile(lem.y + 1, col).isSolid {
            startFalling(&lem)
            return
        }

        if tile(lem.y, frontCol).isSolid {
            if tile(lem.y - 1, frontCol).isSolid {
                if lem.hasClimber {
                    lem.state = .climbing
                    lem.actionProgress = 0
                } else {
                    lem.facingRight.toggle()
                }
                return
            }
            lem.y -= 1
        }
        lem.x += Double(dir)

        // Check the footing of the tile just stepped onto, on this same tick,
        // so a lemming never stands in the walking pose over thin air.
        if !tile(lem.y + 1, Int(lem.x.rounded())).isSolid {
            startFalling(&lem)
        }
    }
}
