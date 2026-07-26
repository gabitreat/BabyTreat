import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            GridView()
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Home")
                }

            HistoryView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("History")
                }
        }
    }
}
