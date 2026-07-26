import SwiftUI

struct DiaperView: View {
    var body: some View {
        ZStack {
            Color.orange
                .ignoresSafeArea()

            VStack {
                Text("Diaper")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Spacer()
            }
            .padding()
        }
    }
}