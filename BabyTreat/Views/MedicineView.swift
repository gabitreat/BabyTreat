import SwiftUI
import SwiftData

struct MedicineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medicine.createdAt, order: .reverse) private var medicines: [Medicine]

    @State private var showingAddSheet = false
    @State private var selectedMedicine: Medicine?

    var body: some View {
        ZStack {
            Color.red
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Medicine")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 60)

                ScrollView {
                    VStack(spacing: 12) {
                        // Temperature Option
                        NavigationLink(destination: TemperatureView()) {
                            HStack {
                                Image(systemName: "thermometer")
                                    .font(.title2)
                                    .foregroundColor(.red)
                                Text("Temperature")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.title3)
                                    .foregroundColor(.red.opacity(0.7))
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(15)
                        }

                        // Custom Medicines
                        ForEach(medicines) { medicine in
                            Button {
                                selectedMedicine = medicine
                            } label: {
                                HStack {
                                    Image(systemName: "pills.fill")
                                        .font(.title2)
                                        .foregroundColor(.red)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(medicine.name)
                                            .font(.title2)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.red)
                                        if !medicine.details.isEmpty {
                                            Text(medicine.details)
                                                .font(.caption)
                                                .foregroundColor(.red.opacity(0.6))
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.title3)
                                        .foregroundColor(.red.opacity(0.7))
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(15)
                            }
                        }

                        // Add Medicine Button
                        Button {
                            showingAddSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                Text("Add Medicine")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(15)
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSheet) {
            AddMedicineSheet { name, details in
                let medicine = Medicine(name: name, details: details)
                modelContext.insert(medicine)
            }
        }
        .sheet(item: $selectedMedicine) { medicine in
            MedicineDetailSheet(medicine: medicine) {
                modelContext.delete(medicine)
            }
        }
    }
}

struct AddMedicineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var details = ""

    var onSave: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Medicine Name") {
                    TextField("e.g. Tylenol", text: $name)
                }
                Section("Details") {
                    TextField("Dosage, frequency, notes...", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Medicine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespaces), details.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct MedicineDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let medicine: Medicine
    var onDelete: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    Text(medicine.name)
                }
                if !medicine.details.isEmpty {
                    Section("Details") {
                        Text(medicine.details)
                    }
                }
                Section {
                    Button("Delete Medicine", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .navigationTitle(medicine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
