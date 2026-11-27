import SwiftUI
import SwiftData
import PhotosUI
import LocalAuthentication

struct BodyCompView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.unitFormatter) private var unitFormatter
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyCompEntry.date, order: .reverse) private var bodyCompEntries: [BodyCompEntry]
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var progressPhotos: [ProgressPhoto]
    @Query(sort: \ProteinEntry.date, order: .reverse) private var proteinEntries: [ProteinEntry]
    
    @State private var showingAddWeight = false
    @State private var showingAddPhoto = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingImageSourcePicker = false
    @State private var showingCamera = false
    @State private var capturedImage: UIImage?
    @State private var showingProteinLog = false
    @AppStorage("bodyCompProtectionEnabled") private var protectionEnabled = false
@State private var isUnlocked = false
@State private var showingSettings = false
@State private var showingPhotoComparison = false
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    // Calculate 7-day average
    private var currentWeight: Double {
        bodyCompEntries.first?.weight ?? userProfile?.weight ?? 0
    }
    
    private var sevenDayAverage: Double {
        let recent = Array(bodyCompEntries.prefix(7))
        guard !recent.isEmpty else { return currentWeight }
        let sum = recent.reduce(0.0) { $0 + $1.weight }
        return sum / Double(recent.count)
    }
    
    private var weightChange: Double {
        guard bodyCompEntries.count >= 7 else { return 0 }
        let recent = bodyCompEntries[0].weight
        let weekAgo = bodyCompEntries[min(6, bodyCompEntries.count - 1)].weight
        return recent - weekAgo
    }
    
    private var todayProtein: ProteinEntry? {
        let calendar = Calendar.current
        return proteinEntries.first { calendar.isDateInToday($0.date) }
    }
    
    private var sevenDayProteinAverage: Int {
        let recent = Array(proteinEntries.prefix(7))
        guard !recent.isEmpty else { return 0 }
        return recent.reduce(0) { $0 + $1.grams } / recent.count
    }
    
    var body: some View {
    ZStack {
        if protectionEnabled && !isUnlocked {
            // Lock Screen
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.atlasTextMuted)
                    
                    Text("Body Composition")
                        .font(.system(size: 24, weight: .light))
                        .foregroundColor(.atlasText)
                    
                    Text("This section is protected")
                        .font(.system(size: 15))
                        .foregroundColor(.atlasTextMuted)
                    
                    Spacer()
                    
                    Button(action: authenticate) {
                        HStack(spacing: 12) {
                            Image(systemName: "faceid")
                                .font(.system(size: 20))
                            Text("Unlock with Face ID")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.atlasBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.atlasPrimary)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                        .frame(height: 60)
                }
            }
        } else {
            bodyContent
        }
    }
    .onAppear {
        if protectionEnabled && !isUnlocked {
            authenticate()
        }
    }
    .onChange(of: scenePhase) { oldPhase, newPhase in
        if newPhase == .background && protectionEnabled {
            isUnlocked = false
        }
    }
    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LockBodyTab"))) { _ in
        if protectionEnabled {
            isUnlocked = false
        }
    }
}

private func authenticate() {
    let context = LAContext()
    var error: NSError?
    
    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Unlock Body Composition") { success, _ in
            DispatchQueue.main.async {
                if success {
                    withAnimation {
                        isUnlocked = true
                    }
                }
            }
        }
    }
}




private var bodyContent: some View {
    ZStack {
        Color.atlasBackground
            .ignoresSafeArea()
        
        ScrollView {
            VStack(spacing: 24) {
                // Weight Tracking Section
                weightTrackingSection
                
                // Protein Section
                proteinSection
                
                // Progress Photos Section
                progressPhotosSection
                
                
                Spacer()
            }
            .padding(24)
        }
    }
    .navigationTitle("Body Composition")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showingSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.atlasTextMuted)
            }
        }
    }
    .sheet(isPresented: $showingSettings) {
        BodyCompSettingsView()
    }
    .sheet(isPresented: $showingAddWeight) {
        AddWeightView()
    }
    .confirmationDialog("Add Photo", isPresented: $showingImageSourcePicker) {
        Button("Take Photo") {
            showingCamera = true
        }
        Button("Choose from Library") {
            showingAddPhoto = true
        }
        Button("Cancel", role: .cancel) { }
    }
    .photosPicker(
        isPresented: $showingAddPhoto,
        selection: $selectedPhotoItem,
        matching: .images
    )
    .fullScreenCover(isPresented: $showingCamera) {
        CameraView(image: $capturedImage)
    }
    .onChange(of: selectedPhotoItem) { oldValue, newValue in
        if let item = newValue {
            loadPhoto(item)
        }
    }
    .onChange(of: capturedImage) { oldValue, newValue in
        if let image = newValue {
            savePhoto(image)
            capturedImage = nil
        }
    }
    .sheet(isPresented: $showingProteinLog) {
        ProteinLogSheet()
    }
    .sheet(isPresented: $showingPhotoComparison) {
    PhotoComparisonView()
    }
}
    
 // MARK: - Weight Tracking Section
private var weightTrackingSection: some View {
    VStack(alignment: .leading, spacing: 16) {
        HStack {
            Text("WEIGHT TRACKING")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            Spacer()
            
            Button(action: { showingAddWeight = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("Log")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.atlasPrimary)
            }
        }
        
        HStack(spacing: 20) {
            // Current weight
            VStack(alignment: .leading, spacing: 4) {
                Text("Current")
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                
                Text(unitFormatter.displayWeight(currentWeight))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.atlasText)
            }
            
            Divider()
                .frame(height: 40)
            
            // 7-day average
            VStack(alignment: .leading, spacing: 4) {
                Text("7-Day Avg")
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                
                Text(unitFormatter.displayWeight(sevenDayAverage))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.atlasAccent)
            }
            
            Divider()
                .frame(height: 40)
            
            // Change
            VStack(alignment: .leading, spacing: 4) {
                Text("7-Day Change")
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
                
                HStack(spacing: 4) {
                    Image(systemName: weightChange > 0 ? "arrow.up.right" : weightChange < 0 ? "arrow.down.right" : "minus")
                        .font(.system(size: 14))
                    
                    Text(unitFormatter.displayWeight(abs(weightChange)))
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(weightChange > 0 ? .red : weightChange < 0 ? .green : .atlasTextMuted)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        
        // View History link
        NavigationLink(destination: WeightHistoryView()) {
            HStack {
                Text("View History")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.atlasTextMuted.opacity(0.5))
            }
            .padding(14)
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
    
    // MARK: - Protein Section
    private var proteinSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PROTEIN INTAKE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.atlasAccent)
                    .tracking(2)
                
                Spacer()
                
                Button(action: { showingProteinLog = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Log")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasPrimary)
                }
            }
            
            HStack(spacing: 20) {
                // Today's intake
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                    
                    if let today = todayProtein {
                        Text("\(today.grams)g")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.atlasText)
                    } else {
                        Text("—")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.atlasTextMuted)
                    }
                }
                
                Divider()
                    .frame(height: 40)
                
                // Goal
                VStack(alignment: .leading, spacing: 4) {
                    Text("Goal")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                    
                    if let goal = userProfile?.proteinGoal {
                        Text("\(goal)g")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.atlasAccent)
                    } else {
                        Text("Not set")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.atlasTextMuted)
                    }
                }
                
                Divider()
                    .frame(height: 40)
                
                // 7-day avg
                VStack(alignment: .leading, spacing: 4) {
                    Text("7-Day Avg")
                        .font(.system(size: 13))
                        .foregroundColor(.atlasTextMuted)
                    
                    Text("\(sevenDayProteinAverage)g")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.atlasText)
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            
            // View History link
            NavigationLink(destination: ProteinHistoryView()) {
                HStack {
                    Text("View History")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasText)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.atlasTextMuted.opacity(0.5))
                }
                .padding(14)
                .background(Color.white.opacity(0.03))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Progress Photos Section
    // MARK: - Progress Photos Section
private var progressPhotosSection: some View {
    VStack(alignment: .leading, spacing: 16) {
        HStack {
            Text("PROGRESS PHOTOS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            Spacer()
            
            if progressPhotos.count >= 2 {
                Button(action: { showingPhotoComparison = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.split.2x1")
                        Text("Compare")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.atlasAccent)
                }
                .padding(.trailing, 12)
            }
            
            Button(action: { showingImageSourcePicker = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                    Text("Add")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.atlasPrimary)
            }
        }
        
        if progressPhotos.isEmpty {
            Text("No photos yet. Track your visual progress over time!")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(progressPhotos.prefix(5)) { photo in
                        ProgressPhotoCard(photo: photo)
                    }
                }
            }
        }
    }
}
    
 
    // MARK: - Load Photo
    private func loadPhoto(_ item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    let photo = ProgressPhoto(date: Date(), photoData: data)
                    photo.weight = currentWeight
                    photo.userProfile = userProfile
                    
                    modelContext.insert(photo)
                    try? modelContext.save()
                    
                    print("✅ Progress photo saved")
                    selectedPhotoItem = nil
                }
            }
        }
    }
    
    // MARK: - Save Photo (from camera)
    private func savePhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let photo = ProgressPhoto(date: Date(), photoData: data)
        photo.weight = currentWeight
        photo.userProfile = userProfile
        
        modelContext.insert(photo)
        try? modelContext.save()
        
        print("✅ Camera photo saved")
    }
}

// MARK: - Add Weight View
struct AddWeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.unitFormatter) private var unitFormatter
    @Query private var profiles: [UserProfile]
    
    @State private var weight: String = ""
    @State private var notes: String = ""
    
    private var userProfile: UserProfile? {
        profiles.first
    }
    
    var body: some View {
        ZStack {
            Color.atlasBackground
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current Weight")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.atlasText)
                    
                    HStack {
                        TextField("e.g., 185", text: $weight)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.atlasText)
                        
                        Text(unitFormatter.weightUnit)
                            .font(.system(size: 20))
                            .foregroundColor(.atlasTextMuted)
                    }
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes (optional)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.atlasText)
                    
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .foregroundColor(.atlasText)
                        .font(.system(size: 15))
                }
                
                Spacer()
                
                Button(action: saveWeight) {
                    Text("Save Weight")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(weight.isEmpty ? Color.gray : Color.atlasPrimary)
                        .cornerRadius(12)
                }
                .disabled(weight.isEmpty)
            }
            .padding(24)
        }
        .navigationTitle("Log Weight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.atlasAccent)
            }
        }
    }
    
    private func saveWeight() {
        guard let displayValue = Double(weight) else { return }
        // Input is in user's preferred unit; store as lbs internally
        let weightInLbs = unitFormatter.toLbs(displayValue)
        
        let entry = BodyCompEntry(date: Date(), weight: weightInLbs)
        entry.notes = notes.isEmpty ? nil : notes
        entry.userProfile = userProfile
        
        modelContext.insert(entry)
        
        do {
            try modelContext.save()
            print("✅ Weight logged: \(weightInLbs) lbs")
            dismiss()
        } catch {
            print("❌ Failed to save weight: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct ProgressPhotoCard: View {
    let photo: ProgressPhoto
    @State private var showingDetail = false
    @Environment(\.unitFormatter) private var unitFormatter
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(spacing: 8) {
                if let uiImage = UIImage(data: photo.photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                VStack(spacing: 2) {
                    Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12))
                        .foregroundColor(.atlasText)
                    
                    if let weight = photo.weight {
                        Text(unitFormatter.displayWeight(weight))
                            .font(.system(size: 11))
                            .foregroundColor(.atlasTextMuted)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .fullScreenCover(isPresented: $showingDetail) {
            NavigationView {
                ProgressPhotoDetailView(photo: photo)
            }
        }
    }
}

struct WeightEntryRow: View {
    @Environment(\.unitFormatter) private var unitFormatter
    let entry: BodyCompEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 14))
                    .foregroundColor(.atlasText)
                
                if let notes = entry.notes {
                    Text(notes)
                        .font(.system(size: 12))
                        .foregroundColor(.atlasTextMuted)
                }
            }
            
            Spacer()
            
            Text(unitFormatter.displayWeight(entry.weight))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.atlasText)
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    BodyCompView()
}