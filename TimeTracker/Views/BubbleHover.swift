import SwiftUI

// The app-wide hover feel: elements bubble out slightly under the cursor
// with a springy pop, and settle back when it leaves
private struct BubbleHover: ViewModifier {
    let scale: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false
    @State private var pendingPop: DispatchWorkItem?

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering && !reduceMotion ? scale : 1)
            // Popped elements must render above their neighbors
            .zIndex(isHovering ? 1 : 0)
            .animation(.spring(duration: 0.3, bounce: 0.45), value: isHovering)
            .onHover { hovering in
                pendingPop?.cancel()
                if hovering {
                    // Pop only when the cursor RESTS here. Without this delay,
                    // scrolling makes every element passing under the cursor
                    // spring, which reads as glitching.
                    let work = DispatchWorkItem { isHovering = true }
                    pendingPop = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
                } else {
                    isHovering = false
                }
            }
    }
}

extension View {
    func bubbleHover(scale: CGFloat = 1.03) -> some View {
        modifier(BubbleHover(scale: scale))
    }
}
