import SwiftUI

/// The app's backdrop: plain black, so the neon is the only light on screen.
struct LiquidBackground: View {
    var body: some View {
        Color.black
            .ignoresSafeArea()
    }
}

#Preview {
    LiquidBackground()
}
