import SwiftUI
import SwiftData

struct SleepView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isRunning = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var startTime: Date?
    @State private var showingAddSheet = false
    @State private var showingSavedConfirmation = false

    var body: some View {
        ZStack {
            Color.purple
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Text("Sleep")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Timer Display
                Text(timeString(elapsedTime))
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                // Start/Stop Button
                Button(action: toggleTimer) {
                    Text(isRunning ? "STOP" : "START")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                        .frame(width: 200, height: 80)
                        .background(Color.white)
                        .cornerRadius(20)
                }

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
                    Text("Sleep saved!")
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
            AddSleepEntrySheet { start, stop in
                let record = SleepRecord(startTime: start, stopTime: stop)
                modelContext.insert(record)
                withAnimation { showingSavedConfirmation = true }
            }
        }
    }

    private func toggleTimer() {
        if isRunning {
            stopTimer()
        } else {
            startTimer()
        }
    }

    private func startTimer() {
        startTime = Date()
        elapsedTime = 0
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil

        if let start = startTime {
            let record = SleepRecord(startTime: start, stopTime: Date())
            modelContext.insert(record)
            withAnimation { showingSavedConfirmation = true }
        }

        startTime = nil
        elapsedTime = 0
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

struct AddSleepEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var startDate = Date()
    @State private var stopDate = Date()

    var onSave: (Date, Date) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Start Time") {
                    DatePicker("Start", selection: $startDate)
                        .labelsHidden()
                }
                Section("Stop Time") {
                    DatePicker("Stop", selection: $stopDate, in: startDate...)
                        .labelsHidden()
                }
            }
            .navigationTitle("Add Sleep Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(startDate, stopDate)
                        dismiss()
                    }
                    .disabled(stopDate <= startDate)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
