import SwiftUI

struct GridView: View {
    /// Rows are sized from this, so adding a tile below does not need the
    /// layout touched. Keep it in step with the tiles in `body`.
    private static let tileCount = 6

    var body: some View {
        NavigationView {
            ZStack {
                // Was a hardcoded 3×2 stack of HStacks, which a seventh tile
                // broke. The grid sizes its rows to fill exactly the space the
                // tab bar leaves, so nothing ends up hidden behind it.
                GeometryReader { geo in
                    let rows = CGFloat((Self.tileCount + 1) / 2)
                    let height = geo.size.height / rows

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 0), GridItem(.flexible(), spacing: 0)],
                        spacing: 0
                    ) {
                        GridButton(title: "Sleep", color: .purple, height: height, destination: SleepView())
                        GridButton(title: "Playtime", color: .green, height: height, destination: PlaytimeView())
                        GridButton(title: "Diaper", color: .orange, height: height, destination: DiaperView())
                        GridButton(title: "Medicine", color: .red, height: height, destination: MedicineView())
                        GridButton(title: "Nursing", color: .blue, height: height, destination: NursingView())
                        GridButton(title: "Formula", color: .teal, height: height, destination: FormulaView())
                    }
                }
                .ignoresSafeArea(edges: .top)

                // Settings gear icon
                VStack {
                    HStack {
                        Spacer()
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 8)
                    }
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct GridButton<Destination: View>: View {
    let title: String
    let color: Color
    var height: CGFloat?
    let destination: Destination

    var body: some View {
        NavigationLink(destination: destination) {
            Rectangle()
                .fill(color)
                .overlay(
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }
}
