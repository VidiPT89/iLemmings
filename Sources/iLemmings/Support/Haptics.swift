#if os(iOS)
import UIKit

enum Haptics {
    static func skillAssigned() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func levelComplete() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func levelFailed() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
#else
enum Haptics {
    static func skillAssigned() {}
    static func levelComplete() {}
    static func levelFailed() {}
}
#endif
