import SwiftUI

struct AppBackgroundView: View {
    var body: some View {
        Image("AppBackground")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .opacity(0.5)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
