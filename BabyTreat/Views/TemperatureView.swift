import SwiftUI
import SwiftData

struct TemperatureView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("temperatureUnit") private var temperatureUnit: String = "celsius"
    @State private var temperature: Double = 37.0
    @State private var showingSavedConfirmation = false

    private var isCelsius: Bool { temperatureUnit == "celsius" }

    private var minTemp: Double { isCelsius ? 35.0 : 95.0 }
    private var maxTemp: Double { isCelsius ? 42.2 : 108.0 }
    private var normalTemp: Double { isCelsius ? 37.0 : 98.6 }
    private var lowThreshold: Double { isCelsius ? 36.1 : 97.0 }
    private var feverThreshold: Double { isCelsius ? 38.0 : 100.4 }

    private var unitLabel: String { isCelsius ? "°C" : "°F" }
    private var secondaryUnitLabel: String { isCelsius ? "°F" : "°C" }

    private var secondaryTemperature: Double {
        isCelsius ? celsiusToFahrenheit(temperature) : fahrenheitToCelsius(temperature)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background - changes based on temperature status
                temperatureStatusColor.opacity(0.15)
                    .ignoresSafeArea()
                    .animation(.easeInOut, value: temperature)

                VStack(spacing: 30) {
                    // Title
                    Text("Temperature")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.top, 60)

                    // Temperature Display
                    VStack(spacing: 10) {
                        Text("\(temperature, specifier: "%.1f")\(unitLabel)")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)

                        Text("\(secondaryTemperature, specifier: "%.1f")\(secondaryUnitLabel)")
                            .font(.title2)
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .padding(.bottom, 20)

                    Spacer()

                    // Vertical Slider Container
                    VStack(spacing: 0) {
                        Text("\(maxTemp, specifier: "%.0f")\(unitLabel)")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.7))

                        Slider(value: $temperature, in: minTemp...maxTemp, step: 0.1)
                            .rotationEffect(.degrees(-90))
                            .frame(width: 300, height: 60)
                            .accentColor(.red)

                        Text("\(minTemp, specifier: "%.0f")\(unitLabel)")
                            .font(.caption)
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .frame(height: 320)

                    // Save Button
                    Button {
                        let reading = TemperatureReading(
                            value: temperature,
                            unit: temperatureUnit
                        )
                        modelContext.insert(reading)
                        showingSavedConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save")
                        }
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(15)
                    }
                    .padding(.horizontal, 40)

                    Spacer()
                }
                .padding()

                // Saved confirmation overlay
                if showingSavedConfirmation {
                    VStack {
                        Spacer()
                        Text("Temperature saved!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                            .padding(.bottom, 40)
                    }
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showingSavedConfirmation = false
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            temperature = normalTemp
        }
    }

    private var temperatureStatusColor: Color {
        if temperature < lowThreshold {
            return .blue
        } else if temperature > feverThreshold {
            return .orange
        } else {
            return .green
        }
    }

    private func fahrenheitToCelsius(_ fahrenheit: Double) -> Double {
        return (fahrenheit - 32) * 5 / 9
    }

    private func celsiusToFahrenheit(_ celsius: Double) -> Double {
        return celsius * 9 / 5 + 32
    }
}
