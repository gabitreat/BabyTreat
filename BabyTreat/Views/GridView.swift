import SwiftUI

struct GridView: View {
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Top row
                    HStack(spacing: 0) {
                        GridButton(title: "Sleep", color: .purple, destination: SleepView())
                        GridButton(title: "Playtime", color: .green, destination: PlaytimeView())
                    }

                    // Middle row
                    HStack(spacing: 0) {
                        GridButton(title: "Diaper", color: .orange, destination: DiaperView())
                        GridButton(title: "Medicine", color: .red, destination: MedicineView())
                    }

                    // Bottom row
                    HStack(spacing: 0) {
                        GridButton(title: "Nursing", color: .blue, destination: NursingView())
                        GridButton(title: "Formula", color: .teal, destination: FormulaView())
                    }

                    // Meals spans the full width — it is a whole section, not a
                    // single logging action like the tiles above.
                    GridButton(title: "Meals", color: MealTheme.malachite, destination: MealsView())
                        .frame(maxHeight: .infinity)
                }
                .ignoresSafeArea()

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
