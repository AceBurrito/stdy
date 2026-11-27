// BodyCompView.swift
// Steady — Body tab.
// Layout: headline (weight trend, body fat, lean mass) → trend chart → body fat
// goal → metabolic age → recent entries → progress photos.
// Weight and body fat come from manual entries plus an Apple Health import.

import SwiftUI
import SwiftData
import PhotosUI
import LocalAuthentication

struct BodyCompView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.unitFormatter) private var unitFormatter
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyCompEntry.date, order: .reverse) private var entries: [BodyCompEntry]
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var progressPhotos: [ProgressPhoto]

    // Sheets
    @State private var showingLog = false
    @State private var showingGoal = false
    @State private var showingSettings = false
    @State private var showingPhotoComparison = false
    @State private var showingImageSourcePicker = false
    @State private var showingPhotoLibrary = false
    @State private var showingCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?

    // Chart
    @State private var chartMetric: BodyMetric = .weight
    @State private var chartRange: SteadyChartRange = .quarter

    // Face ID lock
    @AppStorage("bodyCompProtectionEnabled") private var protectionEnabled = false
    @State private var isUnlocked = false

    private var profile: UserProfile? { profiles.first }
    private var state: BodyState { BodyState.from(entries: entries, profile: profile) }
    private var goal: BodyGoal? { BodyGoal.from(state: state, targetBodyFat: profile?.targetBodyFatPercent) }
    private var metabolicAge: MetabolicAge? { MetabolicAge.estimate(profile: profile, state: state) }

    /// Earliest body fat reading, the starting point of the goal bar
    private var firstBodyFat: Double? {
        entries.last(where: { ($0.bodyFat ?? 0) > 0 })?.bodyFat
    }

    private var chartPoints: [BodyDayPoint] {
        chartMetric == .weight ? state.weightPoints : BodySeries.points(for: chartMetric, entries: entries)
    }

    private var chartGoal: Double? {
        switch chartMetric {
        case .weight: return goal?.goalWeight
        case .bodyFat: return profile?.targetBodyFatPercent
        case .leanMass: return nil
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if protectionEnabled && !isUnlocked {
                    lockScreen
                } else {
                    content
                }
            }
            .background(Color.atlasBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear {
            if protectionEnabled && !isUnlocked { authenticate() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && protectionEnabled { isUnlocked = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LockBodyTab"))) { _ in
            if protectionEnabled { isUnlocked = false }
        }
    }

    // MARK: - Lock

    private var lockScreen: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "lock")
                .font(.system(size: 34, weight: .regular))
                .foregroundColor(.atlasTextMuted)
            Text("Body is locked")
                .font(SteadyType.display(28))
                .foregroundColor(.atlasText)
            Text("Unlock to see weight, body fat and photos.")
                .font(SteadyType.body)
                .foregroundColor(.atlasTextMuted)
            Spacer()
            Button(action: authenticate) {
                Label("Unlock with Face ID", systemImage: "faceid")
            }
            .buttonStyle(SteadyPrimaryButtonStyle())
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
        .frame(maxWidth: .infinity)
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your body composition") { success, _ in
            DispatchQueue.main.async {
                if success { isUnlocked = true }
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                headlinePanel
                chartPanel
                goalPanel
                metabolicAgePanel
                recentPanel
                photosPanel
                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .refreshable { await importFromHealth() }
        .task { await importFromHealth() }
        .sheet(isPresented: $showingLog) { AddWeightView() }
        .sheet(isPresented: $showingGoal) { BodyGoalView() }
        .sheet(isPresented: $showingSettings) { BodyCompSettingsView() }
        .sheet(isPresented: $showingPhotoComparison) { PhotoComparisonView() }
        .confirmationDialog("Add Photo", isPresented: $showingImageSourcePicker) {
            Button("Take Photo") { showingCamera = true }
            Button("Choose from Library") { showingPhotoLibrary = true }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedPhotoItem, matching: .images)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(image: $capturedImage)
        }
        .onChange(of: selectedPhotoItem) { _, item in
            if let item { loadPhoto(item) }
        }
        .onChange(of: capturedImage) { _, image in
            if let image {
                savePhoto(image)
                capturedImage = nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Body")
                    .font(SteadyType.display(30))
                    .foregroundColor(.atlasText)
                Text(lastReadingText).steadyLabel()
            }
            Spacer()
            Button { showingSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17))
                    .foregroundColor(.atlasTextMuted)
                    .frame(width: 36, height: 36)
            }
            Button { showingLog = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.atlasBackground)
                    .frame(width: 36, height: 36)
                    .background(Color.atlasPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .accessibilityLabel("Log weight")
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private var lastReadingText: String {
        guard let latest = entries.first else { return "No readings yet" }
        return "Last reading " + BodyFormat.relativeDay(latest.date)
    }

    // MARK: - Headline

    private var headlinePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if state.latestWeight == nil {
                Text("Log your weight to start tracking. Add body fat to unlock lean mass and your goal weight.")
                    .font(SteadyType.body)
                    .foregroundColor(.atlasTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Log weight") { showingLog = true }
                    .buttonStyle(SteadyPrimaryButtonStyle())
            } else {
                HStack(alignment: .top, spacing: 0) {
                    metricColumn(
                        label: "Weight",
                        value: (state.trendWeight ?? state.latestWeight).map { BodyFormat.number(unitFormatter.fromLbs($0)) } ?? "—",
                        unit: unitFormatter.weightUnit,
                        footnote: rateText
                    )
                    divider
                    metricColumn(
                        label: "Body fat",
                        value: state.latestBodyFat.map { BodyFormat.number($0 * 100) } ?? "—",
                        unit: state.latestBodyFat == nil ? "" : "%",
                        footnote: state.latestBodyFatDate.map { BodyFormat.relativeDay($0) } ?? (state.latestBodyFat == nil ? "not logged" : nil)
                    )
                    divider
                    metricColumn(
                        label: "Lean mass",
                        value: state.leanMass.map { BodyFormat.number(unitFormatter.fromLbs($0)) } ?? "—",
                        unit: state.leanMass == nil ? "" : unitFormatter.weightUnit,
                        footnote: state.fatMass.map { "fat " + BodyFormat.number(unitFormatter.fromLbs($0)) } ?? "needs body fat"
                    )
                }
                Text("Weight is your 7-day trend, so one heavy morning doesn't move it much.")
                    .font(SteadyType.caption)
                    .foregroundColor(.steadyTextFaint)
            }
        }
        .steadyPanel()
    }

    private var rateText: String? {
        guard let rate = state.weeklyWeightRate else { return state.weightPoints.count > 1 ? "trend building" : nil }
        let value = unitFormatter.fromLbs(abs(rate))
        if value < 0.05 { return "holding steady" }
        return String(format: "%@%.1f %@/wk", rate > 0 ? "+" : "−", value, unitFormatter.weightUnit)
    }

    // MARK: - Chart

    private var chartPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SteadySegmented(options: BodyMetric.allCases, selection: $chartMetric) { $0.title }
            }
            BodyTrendChart(metric: chartMetric, points: chartPoints, range: chartRange, goalValue: chartGoal)
            SteadySegmented(options: SteadyChartRange.allCases, selection: $chartRange) { $0.title }
        }
        .steadyPanel()
    }

    // MARK: - Goal

    @ViewBuilder
    private var goalPanel: some View {
        Button { showingGoal = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Body fat goal").steadyLabel()
                    Spacer()
                    Text(goal == nil ? "Set" : "Edit")
                        .font(SteadyType.caption)
                        .foregroundColor(.atlasPrimary)
                }
                if let goal {
                    HStack(alignment: .top, spacing: 0) {
                        metricColumn(label: "Target", value: BodyFormat.number(goal.targetBodyFat * 100), unit: "%", footnote: nil)
                        divider
                        metricColumn(label: "Goal weight", value: BodyFormat.number(unitFormatter.fromLbs(goal.goalWeight)), unit: unitFormatter.weightUnit, footnote: nil)
                    }
                    if let current = state.latestBodyFat {
                        GoalProgressBar(start: max(firstBodyFat ?? current, current),
                                        current: current, target: goal.targetBodyFat)
                    }
                    Text(BodyGoalText.summary(goal, unitFormatter: unitFormatter))
                        .font(SteadyType.caption)
                        .foregroundColor(.atlasTextMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(state.latestBodyFat == nil
                         ? "Log a body fat reading, then pick a target. Steady works out the weight that gets you there."
                         : "Pick a target body fat %. Steady works out the weight that gets you there while keeping your lean mass.")
                        .font(SteadyType.body)
                        .foregroundColor(.atlasTextMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .steadyPanel()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Metabolic Age

    @ViewBuilder
    private var metabolicAgePanel: some View {
        if let estimate = metabolicAge {
            VStack(alignment: .leading, spacing: 10) {
                Text("Metabolic age · estimate").steadyLabel()
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(estimate.years)")
                        .font(SteadyType.display(40))
                        .foregroundColor(estimate.years <= estimate.actualAge ? .atlasPrimary : .atlasAmber)
                    Text(metabolicAgeCaption(estimate))
                        .font(SteadyType.body)
                        .foregroundColor(.atlasTextMuted)
                }
                Text("Your resting burn from lean mass is about \(estimate.bmr) kcal a day. The average for your age, height and weight is \(estimate.averageBMR). More lean mass lowers this number.")
                    .font(SteadyType.caption)
                    .foregroundColor(.atlasTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .steadyPanel()
        }
    }

    private func metabolicAgeCaption(_ estimate: MetabolicAge) -> String {
        let diff = estimate.actualAge - estimate.years
        if diff == 0 { return "same as your age" }
        return diff > 0 ? "\(diff) yr younger than you" : "\(-diff) yr older than you"
    }

    // MARK: - Recent Entries

    private var recentPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent").steadyLabel()
                Spacer()
                if !entries.isEmpty {
                    NavigationLink {
                        WeightHistoryView()
                    } label: {
                        Text("All \(entries.count)")
                            .font(SteadyType.caption)
                            .foregroundColor(.atlasPrimary)
                    }
                }
            }
            if entries.isEmpty {
                Text("Nothing logged yet. Readings from Apple Health show up here automatically.")
                    .font(SteadyType.caption)
                    .foregroundColor(.atlasTextMuted)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Rectangle().fill(Color.steadyHairline).frame(height: 1) }
                        WeightEntryRow(entry: entry)
                    }
                }
            }
        }
        .steadyPanel()
    }

    // MARK: - Photos

    private var photosPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress photos").steadyLabel()
                Spacer()
                if progressPhotos.count >= 2 {
                    Button("Compare") { showingPhotoComparison = true }
                        .font(SteadyType.caption)
                        .foregroundColor(.atlasPrimary)
                        .padding(.trailing, 12)
                }
                Button("Add") { showingImageSourcePicker = true }
                    .font(SteadyType.caption)
                    .foregroundColor(.atlasPrimary)
            }
            if progressPhotos.isEmpty {
                Text("Photos catch changes the scale misses. They stay on your device and iCloud.")
                    .font(SteadyType.caption)
                    .foregroundColor(.atlasTextMuted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(progressPhotos.prefix(8)) { photo in
                            ProgressPhotoCard(photo: photo)
                        }
                    }
                }
            }
        }
        .steadyPanel()
    }

    // MARK: - Pieces

    private var divider: some View {
        Rectangle()
            .fill(Color.steadyHairline)
            .frame(width: 1)
            .padding(.horizontal, 12)
    }

    private func metricColumn(label: String, value: String, unit: String, footnote: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).steadyLabel(.steadyTextFaint)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(SteadyType.metric(22))
                    .foregroundColor(value == "—" ? .steadyTextFaint : .atlasText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .font(SteadyType.caption)
                    .foregroundColor(.atlasTextMuted)
            }
            if let footnote {
                Text(footnote)
                    .font(SteadyType.caption)
                    .foregroundColor(.atlasTextMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private func importFromHealth() async {
        await HealthKitManager.shared.requestAuthorizationIfNeeded()
        await HealthKitManager.shared.importBodyComposition(modelContext: modelContext)
        WidgetSync.refresh(modelContext: modelContext, unitFormatter: unitFormatter)
    }

    private func loadPhoto(_ item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                insertPhoto(data)
                selectedPhotoItem = nil
            }
        }
    }

    private func savePhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        insertPhoto(data)
    }

    private func insertPhoto(_ data: Data) {
        let photo = ProgressPhoto(date: Date(), photoData: data)
        photo.weight = state.latestWeight
        photo.userProfile = profile
        modelContext.insert(photo)
        try? modelContext.save()
    }
}

// MARK: - Goal Progress Bar

/// Flat bar from the starting body fat to the target. Fills as body fat drops.
struct GoalProgressBar: View {
    let start: Double
    let current: Double
    let target: Double

    private var fraction: Double {
        let span = start - target
        guard abs(span) > 0.0001 else { return current <= target ? 1 : 0 }
        return min(max((start - current) / span, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.steadyRaised)
                Rectangle().fill(Color.atlasPrimary).frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 6)
        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }
}

// MARK: - Formatting

enum BodyFormat {
    static func number(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// "today", "yesterday", "3d ago", or "Mar 4"
    static func relativeDay(_ date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        case 2...6: return "\(days)d ago"
        default: return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Log / Edit Entry

/// Logs a new weigh-in, or edits one when `entry` is passed.
struct AddWeightView: View {
    var entry: BodyCompEntry? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.unitFormatter) private var unitFormatter
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyCompEntry.date, order: .reverse) private var entries: [BodyCompEntry]

    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var date = Date()
    @State private var notes = ""
    @FocusState private var focusedField: Field?

    private enum Field { case weight, bodyFat, notes }

    private var weightValue: Double? { Double(weightText.replacingOccurrences(of: ",", with: ".")) }
    private var bodyFatValue: Double? { Double(bodyFatText.replacingOccurrences(of: ",", with: ".")) }

    private var isValid: Bool {
        guard let w = weightValue, w > 0 else { return false }
        if !bodyFatText.isEmpty {
            guard let bf = bodyFatValue, bf > 2, bf < 60 else { return false }
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field(label: "Weight", text: $weightText, unit: unitFormatter.weightUnit, placeholder: "0.0", focus: .weight)
                    field(label: "Body fat (optional)", text: $bodyFatText, unit: "%", placeholder: "e.g. 18.5", focus: .bodyFat)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date").steadyLabel()
                        DatePicker("", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .tint(.atlasPrimary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes").steadyLabel()
                        TextField("Optional", text: $notes, axis: .vertical)
                            .lineLimit(1...4)
                            .focused($focusedField, equals: .notes)
                            .textFieldStyle(atlasTextFieldStyle())
                    }

                    if entry?.isFromHealth == true {
                        Text("Imported from Apple Health. Edits stay in Steady and won't change Health.")
                            .font(SteadyType.caption)
                            .foregroundColor(.atlasTextMuted)
                    }

                    Button(entry == nil ? "Save" : "Save changes", action: save)
                        .buttonStyle(SteadyPrimaryButtonStyle(tint: isValid ? .atlasPrimary : .steadyRaised))
                        .disabled(!isValid)
                        .padding(.top, 6)
                }
                .padding(16)
            }
            .background(Color.atlasBackground.ignoresSafeArea())
            .navigationTitle(entry == nil ? "Log Weight" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.atlasTextMuted)
                }
            }
        }
        .onAppear(perform: load)
    }

    private func field(label: String, text: Binding<String>, unit: String, placeholder: String, focus: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).steadyLabel()
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: focus)
                    .font(SteadyType.metric(34))
                    .foregroundColor(.atlasText)
                Text(unit)
                    .font(SteadyType.title)
                    .foregroundColor(.atlasTextMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.steadyRaised)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.steadyHairline, lineWidth: 1))
        }
    }

    private func load() {
        if let entry {
            weightText = String(format: "%.1f", unitFormatter.fromLbs(entry.weight))
            bodyFatText = entry.bodyFat.map { String(format: "%.1f", $0 * 100) } ?? ""
            date = entry.date
            notes = entry.notes ?? ""
        } else {
            // Prefill with the last reading so a small change is a couple of taps
            if let last = entries.first {
                weightText = String(format: "%.1f", unitFormatter.fromLbs(last.weight))
            }
            focusedField = .weight
        }
    }

    private func save() {
        guard let displayWeight = weightValue else { return }
        let lbs = unitFormatter.toLbs(displayWeight)
        let bodyFat = bodyFatValue.map { $0 / 100 }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let target: BodyCompEntry
        if let entry {
            target = entry
        } else {
            target = BodyCompEntry(date: date, weight: lbs)
            target.source = "manual"
            target.userProfile = profiles.first
            modelContext.insert(target)
        }
        target.weight = lbs
        target.date = date
        target.bodyFat = bodyFatText.isEmpty ? nil : bodyFat
        target.notes = trimmedNotes.isEmpty ? nil : trimmedNotes

        do {
            try modelContext.save()
            BodyProfileSync.apply(modelContext: modelContext)
            WidgetSync.refresh(modelContext: modelContext, unitFormatter: unitFormatter)
            dismiss()
        } catch {
            print("❌ Failed to save body comp entry: \(error)")
        }
    }
}

// MARK: - Entry Row

struct WeightEntryRow: View {
    @Environment(\.unitFormatter) private var unitFormatter
    let entry: BodyCompEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(SteadyType.body)
                    .foregroundColor(.atlasText)
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(SteadyType.caption)
                        .foregroundColor(.atlasTextMuted)
                        .lineLimit(1)
                } else if entry.isFromHealth {
                    Text("Apple Health")
                        .font(SteadyType.caption)
                        .foregroundColor(.steadyTextFaint)
                }
            }
            Spacer()
            if let bf = entry.bodyFat {
                Text(String(format: "%.1f%%", bf * 100))
                    .font(SteadyType.metric(14, weight: .regular))
                    .foregroundColor(.atlasTextMuted)
            }
            Text(unitFormatter.displayWeight(entry.weight))
                .font(SteadyType.metric(16))
                .foregroundColor(.atlasText)
                .frame(minWidth: 84, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Progress Photo Card

struct ProgressPhotoCard: View {
    let photo: ProgressPhoto
    @State private var showingDetail = false
    @Environment(\.unitFormatter) private var unitFormatter

    var body: some View {
        Button { showingDetail = true } label: {
            VStack(alignment: .leading, spacing: 6) {
                if let uiImage = UIImage(data: photo.photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 108, height: 144)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                Text(photo.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(SteadyType.caption)
                    .foregroundColor(.atlasText)
                if let weight = photo.weight {
                    Text(unitFormatter.displayWeight(weight))
                        .font(SteadyType.metric(11, weight: .regular))
                        .foregroundColor(.atlasTextMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showingDetail) {
            NavigationStack {
                ProgressPhotoDetailView(photo: photo)
            }
        }
    }
}

#Preview {
    BodyCompView()
}
