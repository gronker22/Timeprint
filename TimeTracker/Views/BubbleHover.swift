import SwiftUI

// The app-wide hover feel: elements bubble out slightly under the cursor
// with a springy pop, and settle back when it leaves
private struct BubbleHover: ViewModifier {
    let scale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering && !reduceMotion ? scale : 1)
            // Popped elements must render above their neighbors
            .zIndex(isHovering ? 1 : 0)
            .animation(.spring(duration: 0.3, bounce: 0.45), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension View {
    func bubbleHover(scale: CGFloat = 1.03) -> some View {
        modifier(BubbleHover(scale: scale))
    }
}
