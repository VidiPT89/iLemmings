import Foundation

/// The raw pixel art for every lemming pose, kept apart from the texture
/// building in `LemmingSprites` so neither file turns into a wall of
/// strings with logic buried in it.
///
/// Each frame is a 14x14 grid. The body only ever occupies the middle
/// columns and the bottom twelve rows; the margin is there for the things
/// that stick out — the floater's umbrella, the basher's arm, the miner's
/// pickaxe, the builder's brick — so every pose shares one canvas size and
/// one sprite size in the scene.
///
/// Legend: `.` transparent, `g` hair, `s` skin, `b` overalls, `d` shoes,
/// `k` eye, `y` umbrella, `t` tool head, `n` tool handle, `o` brick.
enum LemmingArt {

    /// The four-frame walk cycle: stride, pass, stride, pass, with the
    /// body dropping a pixel on the pass frames so the head bobs.
    static let walk1: [String] = [
        "..............",
        "..............",
        ".....gggg.....",
        "....gggggg....",
        "....ggssss....",
        "....ggssks....",
        "....gsssss....",
        ".....bbbbb....",
        "....bbbbbb....",
        "....bbbbbb....",
        ".....bbbb.....",
        "....b....b....",
        "...b......b...",
        "..dd......dd..",
    ]

    static let walk2: [String] = [
        "..............",
        "..............",
        "..............",
        ".....gggg.....",
        "....gggggg....",
        "....ggssss....",
        "....ggssks....",
        "....gsssss....",
        ".....bbbbb....",
        "....bbbbbb....",
        "....bbbbbb....",
        ".....b..b.....",
        ".....b..b.....",
        "....dd..dd....",
    ]

    static let walk3: [String] = [
        "..............",
        "..............",
        ".....gggg.....",
        "....gggggg....",
        "....ggssss....",
        "....ggssks....",
        "....gsssss....",
        ".....bbbbb....",
        "....bbbbbb....",
        "....bbbbbb....",
        ".....bbbb.....",
        ".....b..b.....",
        "....b....b....",
        "...dd....dd...",
    ]

    static let walk4: [String] = [
        "..............",
        "..............",
        "..............",
        ".....gggg.....",
        "....gggggg....",
        "....ggssss....",
        "....ggssks....",
        "....gsssss....",
        ".....bbbbb....",
        "....bbbbbb....",
        "....bbbbbb....",
        "......b.b.....",
        "......b..b....",
        ".....dd..dd...",
    ]

    /// Falling with both arms up, the classic "this is going to hurt" pose.
    static let fall1: [String] = [
        "..............",
        "...s......s...",
        "...s.gggg.s...",
        "...sggggggs...",
        "...sggsssss...",
        "...sggsskss...",
        "...sgsssss....",
        ".....bbbbb....",
        "....bbbbbb....",
        "....bbbbbb....",
        ".....bbbb.....",
        "....b....b....",
        "....b....b....",
        "...dd....dd...",
    ]

    static let fall2: [String] = [
        "..s........s..",
        "..s........s..",
        "...s.gggg.s...",
        "...sggggggs...",
        "....ggsssss...",
        "....ggsskss...",
        "....gsssss....",
        ".....bbbbb....",
        "....bbbbbb....",
        "....bbbbbb....",
        ".....bbbb.....",
        ".....b..b.....",
        "....b....b....",
        "...dd....dd...",
    ]

    /// Umbrella open. The canopy is why the canvas has two spare rows on top.
    static let float1: [String] = [
        "..............",
        "...yyyyyyyy...",
        "..yyyyyyyyyy..",
        "......nn......",
        ".....gggg.....",
        "....gggggg....",
        "....ggssss....",
        "....ggssks....",
        "....gsssss....",
        ".....bbbbb....",
        "....bbbbbb....",
        ".....bbbb.....",
        ".....b..b.....",
        "....dd..dd....",
    ]

    static let float2: [String] = [
        "..............",
        "..............",
        "...yyyyyyyy...",
        "..yy.yyyy.yy..",
        "......nn......",
        ".....gggg.....",
        "....gggggg....",
        "....ggssss....",
        "....ggssks....",
        "....gsssss....",
        ".....bbbbb....",
        "....bbbbbb....",
        ".....b..b.....",
        "....dd..dd....",
    ]

    /// Flat against the wall, arms reaching over it.
    static let climb1: [String] = [
        "........ss....",
        "........ss....",
        "......gggg....",
        ".....ggggg....",
        ".....ggsss....",
        ".....ggssk....",
        "......ssss....",
        "......bbbb....",
        ".....bbbbb....",
        ".....bbbbb....",
        "......bbbb....",
        "......b.bb....",
        "......b..b....",
        ".....dd..d....",
    ]

    static let climb2: [String] = [
        "..............",
        "........ss....",
        "........ss....",
        "......gggg....",
        ".....ggggg....",
        ".....ggsss....",
        ".....ggssk....",
        "......ssss....",
        "......bbbb....",
        ".....bbbbb....",
        "......bbbb....",
        "......bb.b....",
        "......b..b....",
        "......dd.d....",
    ]

    /// Digging straight down: crouched, both arms between the feet.
    static let dig1: [String] = [
        "..............",
        "..............",
        "..............",
        "..............",
        ".....gggg.....",
        "....gggggg....",
        "....ggssss....",
        "....ggssks....",
        "....gsssss....",
        "...bbbbbbb....",
        "...bbbbbbb....",
        "....bssssb....",
        "....b.ss.b....",
        "...dd....dd...",
    ]

    static let dig2: [String] = [
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        ".....gggg.....",
        "....gggggg....",
        "....ggssss....",
        "....ggssks....",
        "....gsssss....",
        "...bbbbbbb....",
        "...bbbbbbb....",
        "...bss..ssb...",
        "...dd....dd...",
    ]

    /// Bashing sideways: the arm and tool punch out past the body.
    static let bash1: [String] = [
        "..............",
        "..............",
        ".....gggg.....",
        "....gggggg....",
        "....ggssss....",
        "....ggssks....",
        "....gsssss....",
        ".....bbbbb....",
        "....bbbbbbsstt",
        "....bbbbbb....",
        ".....bbbb.....",
        ".....b..b.....",
        ".....b..b.....",
        "....dd..dd....",
    ]

    static let bash2: [String] = [
        "..............",
        "..............",
        ".....gggg.....",
        "....gggggg....",
        "....ggssss....",
        "....ggssks....",
        "....gsssss....",
        ".....bbbbbss..",
        "....bbbbbb.tt.",
        "....bbbbbb....",
        ".....bbbb.....",
        ".....b..b.....",
        ".....b..b.....",
        "....dd..dd....",
    ]

    /// Mining down-forward, pickaxe on the diagonal.
    static let mine1: [String] = [
        "..............",
        "..............",
        "..............",
        "....gggg......",
        "...gggggg.....",
        "...ggssss.....",
        "...ggsskss....",
        "...gsssssn....",
        "....bbbbbbn...",
        "...bbbbbb.tt..",
        "...bbbbbb..tt.",
        "....b..b......",
        "....b..b......",
        "...dd..dd.....",
    ]

    static let mine2: [String] = [
        "..............",
        "..............",
        "..............",
        "....gggg......",
        "...gggggg.....",
        "...ggssss.....",
        "...ggsskss....",
        "...gsssss.....",
        "....bbbbbbn...",
        "...bbbbbbb.n..",
        "...bbbbbb...tt",
        "....b..b....tt",
        "....b..b......",
        "...dd..dd.....",
    ]

    /// Laying a brick at the feet, which is what the staircase is made of.
    static let build1: [String] = [
        "..............",
        "..............",
        "..............",
        "....gggg......",
        "...gggggg.....",
        "...ggssss.....",
        "...ggsskss....",
        "...gsssss.....",
        "....bbbbbss...",
        "...bbbbbb.oo..",
        "...bbbbbb.....",
        "....b..b......",
        "....b..b......",
        "...dd..dd.....",
    ]

    static let build2: [String] = [
        "..............",
        "..............",
        "..............",
        "..............",
        "....gggg......",
        "...gggggg.....",
        "...ggssss.....",
        "...ggsskss....",
        "...gsssss.....",
        "....bbbbbs....",
        "...bbbbbbb....",
        "...bbbbbb.....",
        "....b..b......",
        "...dd..dd.oooo",
    ]

    /// Arms out on both sides. Deliberately the widest pose in the set.
    static let block1: [String] = [
        "..............",
        "..............",
        ".....gggg.....",
        "....gggggg....",
        "....gssssg....",
        "....gsksks....",
        ".....sssss....",
        "...sbbbbbs....",
        "...sbbbbbbs...",
        "...sbbbbbbs...",
        "....bbbbbb....",
        ".....b..b.....",
        ".....b..b.....",
        "....dd..dd....",
    ]

    static let block2: [String] = [
        "..............",
        "..............",
        ".....gggg.....",
        "....gggggg....",
        "....gssssg....",
        "....gsksks....",
        ".....sssss....",
        "..sbbbbbbs....",
        "..sbbbbbbbs...",
        "...bbbbbbs....",
        "....bbbbbb....",
        ".....b..b.....",
        ".....b..b.....",
        "....dd..dd....",
    ]

    /// Out of bricks: the builder's shrug before going back to walking.
    static let shrug1: [String] = [
        "..............",
        "..............",
        ".....gggg.....",
        "....gggggg....",
        "....ggssss....",
        "....ggssks....",
        "....gsssss....",
        "...sbbbbbs....",
        "...sbbbbbbs...",
        "....bbbbbb....",
        ".....bbbb.....",
        ".....b..b.....",
        ".....b..b.....",
        "....dd..dd....",
    ]

    static let shrug2: [String] = [
        "..............",
        "...s......s...",
        "...s.gggg.s...",
        "...sggggggs...",
        "....ggssss....",
        "....ggssks....",
        "....gsssss....",
        ".....bbbbb....",
        "....bbbbbb....",
        "....bbbbbb....",
        ".....bbbb.....",
        ".....b..b.....",
        ".....b..b.....",
        "....dd..dd....",
    ]

    /// The Oh-No panic before the crater.
    static let ohno1: [String] = [
        "..s........s..",
        "..s........s..",
        "...s.gggg.s...",
        "...sggggggs...",
        "....gssssg....",
        "....gskksg....",
        ".....sssss....",
        ".....bbbbb....",
        "....bbbbbb....",
        "....bbbbbb....",
        ".....bbbb.....",
        "....b....b....",
        "....b....b....",
        "...dd....dd...",
    ]

    static let ohno2: [String] = [
        "..............",
        "..s........s..",
        "..s..gggg..s..",
        "...sggggggs...",
        "....gssssg....",
        "....gskksg....",
        ".....sssss....",
        ".....bbbbb....",
        "....bbbbbb....",
        "....bbbbbb....",
        ".....bbbb.....",
        ".....b..b.....",
        "....b....b....",
        "...dd....dd...",
    ]

    /// Flattened on impact — drawn against the bottom of the canvas.
    static let splat1: [String] = [
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "....gggg......",
        "..ggssssgg....",
        ".sbbbbbbbbs...",
        ".sbbbbbbbbs...",
        ".dd.dddd.dd...",
    ]

    /// Sinking: only what is still above the waterline is drawn.
    static let drown1: [String] = [
        "..............",
        "..............",
        "..s........s..",
        "..s........s..",
        "...s.gggg.s...",
        "...sggggggs...",
        "....ggssss....",
        "....ggsskss...",
        ".....sssss....",
        ".....bbbbb....",
        "..............",
        "..............",
        "..............",
        "..............",
    ]

    static let drown2: [String] = [
        "..............",
        "..............",
        "..............",
        "...s......s...",
        "...s.gggg.s...",
        "...sggggggs...",
        "....ggssss....",
        "....ggsskss...",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
        "..............",
    ]

}
