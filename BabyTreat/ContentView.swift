import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            GridView()
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Home")
                }

            // Meals is its own tab rather than a grid tile: it is a section with
            // five sub-tabs, and as a tile it collided with this tab bar.
            NavigationStack {
                MealsView()
            }
            .tabItem {
                Image(systemName: "fork.knife")
                Text("Meals")
            }

            HistoryView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("History")
                }
        }
    }
}
