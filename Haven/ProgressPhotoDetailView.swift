import SwiftUI
import SwiftData

struct ProgressPhotoDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let photo: ProgressPhoto
    
    @State private var showingDeleteAlert = false
    @State private var showingEditSheet = false
    @State private var editedWeight: String = ""
    @State private var editedDate: Date = Date()
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Photo
                if let uiImage = UIImage(data: photo.photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Info Bar
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(photo.date.formatted(date: .long, time: .omitted))
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            if let weight = photo.weight {
                                Text("\(String(format: "%.1f", weight)) lbs")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        Spacer()
                        
                        // Edit Button
                        Button(action: { 
                            editedWeight = photo.weight != nil ? String(format: "%.1f", photo.weight!) : ""
                            editedDate = photo.date
                            showingEditSheet = true 
                        }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.atlasAccent)
                        }
                        
                        // Delete Button
                        Button(action: { showingDeleteAlert = true }) {
                            Image(systemName: "trash.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                }
                .padding(20)
                .background(Color.atlasBackground)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.atlasAccent)
            }
        }
        .alert("Delete Photo?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deletePhoto()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This photo will be permanently deleted.")
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPhotoDetailsView(
                photo: photo,
                weight: $editedWeight,
                date: $editedDate,
                onSave: saveEdits
            )
        }
    }
    
    private func deletePhoto() {
        modelContext.delete(photo)
        try? modelContext.save()
        print("✅ Photo deleted")
        dismiss()
    }
    
    private func saveEdits() {
        if let weightValue = Double(editedWeight) {
            photo.weight = weightValue
        }
        photo.date = editedDate
        try? modelContext.save()
        print("✅ Photo details updated")
    }
}

// MARK: - Edit Photo Details View
struct EditPhotoDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    
    let photo: ProgressPhoto
    @Binding var weight: String
    @Binding var date: Date
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Weight
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weight (lbs)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasText)
                        
                        TextField("e.g., 185", text: $weight)
                            .keyboardType(.decimalPad)
                            .padding(16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.atlasText)
                    }
                    
                    // Date
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasText)
                        
                        DatePicker(
                            "",
                            selection: $date,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(.atlasPrimary)
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Edit Photo Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.atlasTextMuted)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .foregroundColor(.atlasPrimary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        ProgressPhotoDetailView(photo: ProgressPhoto(date: Date(), photoData: Data()))
    }
}
