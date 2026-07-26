import SwiftUI
import SwiftData

struct NursingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var leftIsRunning = false
    @State private var rightIsRunning = false
    @State private var leftElapsedTime: TimeInterval = 0
    @State private var rightElapsedTime: TimeInterval = 0
    @State private var leftTimer: Timer?
    @State private var rightTimer: Timer?
    @State private var showingAddSheet = false
    @State private var showingSavedConfirmation = false

    private var hasAnyTime: Bool {
        leftElapsedTime > 0 || rightElapsedTime > 0
    }

    private var eitherRunning: Bool {
        leftIsRunning || rightIsRunning
    }

    var body: some View {
        ZStack {
            Color.blue
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Text("Nursing")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Left and Right Timer Sections
                HStack(spacing: 20) {
                    // Left Breast
                    VStack(spacing: 15) {
                        Text("Left")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        Text(timeString(leftElapsedTime))
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(height: 60)

                        Button(action: toggleLeftTimer) {
                            Text(leftIsRunning ? "PAUSE" : (leftElapsedTime > 0 ? "RESUME" : "START"))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(width: 120, height: 50)
                                .background(Color.white)
                                .cornerRadius(15)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    // Right Breast
                    VStack(spacing: 15) {
                        Text("Right")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        Text(timeString(rightElapsedTime))
                            .font(.system(size: 40, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(height: 60)

                        Button(action: toggleRightTimer) {
                            Text(rightIsRunning ? "PAUSE" : (rightElapsedTime > 0 ? "RESUME" : "START"))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                                .frame(width: 120, height: 50)
                                .background(Color.white)
                                .cornerRadius(15)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Save & Reset Buttons
                HStack(spacing: 20) {
                    Button(action: resetAll) {
                        Text("Reset")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    }

                    Button(action: saveSession) {
                        Text("Save")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color.white)
                            .cornerRadius(12)
                    }
                    .disabled(!hasAnyTime || eitherRunning)
                    .opacity(!hasAnyTime || eitherRunning ? 0.5 : 1)
                }
                .padding(.horizontal)

                // Add Manual Entry Button
                Button {
                    showingAddSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Entry")
                    }
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(15)
                }

                Spacer()
            }
            .padding()

            if showingSavedConfirmation {
                VStack {
                    Spacer()
                    Text("Nursing saved!")
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
        .sheet(isPresented: $showingAddSheet) {
            AddNursingEntrySheet { timestamp, leftDuration, rightDuration in
                let record = NursingRecord(timestamp: timestamp, leftDuration: leftDuration, rightDuration: rightDuration)
                modelContext.insert(record)
                withAnimation { showingSavedConfirmation = true }
            }
        }
    }

    private func saveSession() {
        let record = NursingRecord(leftDuration: leftElapsedTime, rightDuration: rightElapsedTime)
        modelContext.insert(record)
        withAnimation { showingSavedConfirmation = true }
        resetAll()
    }

    private func resetAll() {
        pauseLeftTimer()
        pauseRightTimer()
        leftElapsedTime = 0
        rightElapsedTime = 0
    }

    private func toggleLeftTimer() {
        if leftIsRunning {
            pauseLeftTimer()
        } else {
            startLeftTimer()
        }
    }

    private func toggleRightTimer() {
        if rightIsRunning {
            pauseRightTimer()
        } else {
            startRightTimer()
        }
    }

    private func startLeftTimer() {
        leftIsRunning = true
        leftTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            leftElapsedTime += 1
        }
    }

    private func startRightTimer() {
        rightIsRunning = true
        rightTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            rightElapsedTime += 1
        }
    }

    private func pauseLeftTimer() {
        leftIsRunning = false
        leftTimer?.invalidate()
        leftTimer = nil
    }

    private func pauseRightTimer() {
        rightIsRunning = false
        rightTimer?.invalidate()
        rightTimer = nil
    }

    private func timeString(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct AddNursingEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var timestamp = Date()
    @State private var leftMinutes: Int = 0
    @State private var rightMinutes: Int = 0

    var onSave: (Date, TimeInterval, TimeInterval) -> Void

    private var hasAnyDuration: Bool {
        leftMinutes > 0 || rightMinutes > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Time", selection: $timestamp)
                        .labelsHidden()
                }
                Section("Left (minutes)") {
                    Picker("Left duration", selection: $leftMinutes) {
                        ForEach(0...120, id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }
                Section("Right (minutes)") {
                    Picker("Right duration", selection: $rightMinutes) {
                        ForEach(0...120, id: \.self) { min in
                            Text("\(min) min").tag(min)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.wheel)
                    .frame(height: 100)
                }
            }
            .navigationTitle("Add Nursing Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(timestamp, Double(leftMinutes) * 60, Double(rightMinutes) * 60)
                        dismiss()
                    }
                    .disabled(!hasAnyDuration)
                }
            }
        }
    }
}
