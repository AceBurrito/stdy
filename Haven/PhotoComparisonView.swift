import SwiftUI
import SwiftData

struct PhotoComparisonView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]
    
    @State private var leftPhoto: ProgressPhoto?
    @State private var rightPhoto: ProgressPhoto?
    @State private var selectingFor: SelectionSide = .left
    @State private var showingPhotoPicker = false
    @State private var showingSaveSuccess = false
    
    enum SelectionSide {
        case left, right
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Comparison area
                    comparisonSection
                    
                    // Photo details
                    if leftPhoto != nil || rightPhoto != nil {
                        detailsSection
                    }
                    
                    Spacer()
                    
                    // Save button
                    if leftPhoto != nil && rightPhoto != nil {
                        saveButton
                    }
                }
                .padding(24)
            }
            .navigationTitle("Compare Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.atlasTextMuted)
                }
            }
            .sheet(isPresented: $showingPhotoPicker) {
                PhotoPickerSheet(
                    photos: photos,
                    selectedPhoto: selectingFor == .left ? $leftPhoto : $rightPhoto,
                    excludePhoto: selectingFor == .left ? rightPhoto : leftPhoto
                )
            }
            .alert("Saved!", isPresented: $showingSaveSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Comparison saved to your photo library.")
            }
        }
    }
    
    // MARK: - Comparison Section
    private var comparisonSection: some View {
        HStack(spacing: 12) {
            // Left photo
            photoSlot(photo: leftPhoto, label: "BEFORE", side: .left)
            
            // Right photo
            photoSlot(photo: rightPhoto, label: "AFTER", side: .right)
        }
        .frame(height: 350)
    }
    
    private func photoSlot(photo: ProgressPhoto?, label: String, side: SelectionSide) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.atlasAccent)
                .tracking(2)
            
            Button(action: {
                selectingFor = side
                showingPhotoPicker = true
            }) {
                if let photo = photo, let uiImage = UIImage(data: photo.photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.atlasPrimary)
                        
                        Text("Select Photo")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.atlasText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.atlasPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                    )
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        HStack(spacing: 12) {
            // Left details
            if let left = leftPhoto {
                photoDetails(photo: left)
            } else {
                Spacer().frame(maxWidth: .infinity)
            }
            
            // Right details
            if let right = rightPhoto {
                photoDetails(photo: right)
            } else {
                Spacer().frame(maxWidth: .infinity)
            }
        }
    }
    
    private func photoDetails(photo: ProgressPhoto) -> some View {
        VStack(spacing: 4) {
            Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.atlasText)
            
            if let weight = photo.weight {
                Text(String(format: "%.1f lbs", weight))
                    .font(.system(size: 13))
                    .foregroundColor(.atlasTextMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: saveComparison) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.down.fill")
                Text("Save Comparison")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.atlasBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.atlasPrimary)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Save Comparison
    private func saveComparison() {
        guard let left = leftPhoto, let right = rightPhoto,
              let leftImage = UIImage(data: left.photoData),
              let rightImage = UIImage(data: right.photoData) else { return }
        
        let combinedImage = createComparisonImage(left: leftImage, right: rightImage, leftDate: left.date, rightDate: right.date, leftWeight: left.weight, rightWeight: right.weight)
        
        UIImageWriteToSavedPhotosAlbum(combinedImage, nil, nil, nil)
        showingSaveSuccess = true
    }
    
    private func createComparisonImage(left: UIImage, right: UIImage, leftDate: Date, rightDate: Date, leftWeight: Double?, rightWeight: Double?) -> UIImage {
    let spacing: CGFloat = 10
    let labelHeight: CGFloat = 50
    let padding: CGFloat = 10
    
    // Use consistent dimensions for both photos
    let targetPhotoWidth: CGFloat = 300
    let targetPhotoHeight: CGFloat = 400
    
    let totalWidth = targetPhotoWidth * 2 + spacing + padding * 2
    let totalHeight = targetPhotoHeight + labelHeight + padding * 2
    
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalWidth, height: totalHeight))
    
    return renderer.image { context in
        // Background
        UIColor(Color.atlasBackground).setFill()
        context.fill(CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight))
        
        // Left photo - aspect fill and center crop
        let leftRect = CGRect(x: padding, y: padding, width: targetPhotoWidth, height: targetPhotoHeight)
        drawImageAspectFill(image: left, in: leftRect, context: context.cgContext)
        
        // Right photo - aspect fill and center crop
        let rightRect = CGRect(x: padding + targetPhotoWidth + spacing, y: padding, width: targetPhotoWidth, height: targetPhotoHeight)
        drawImageAspectFill(image: right, in: rightRect, context: context.cgContext)
        
        // Labels
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]
        
        // Left label
        var leftText = dateFormatter.string(from: leftDate)
        if let weight = leftWeight {
            leftText += String(format: "\n%.1f lbs", weight)
        }
        let leftLabelRect = CGRect(x: padding, y: padding + targetPhotoHeight + 5, width: targetPhotoWidth, height: labelHeight)
        leftText.draw(in: leftLabelRect, withAttributes: labelAttributes)
        
        // Right label
        var rightText = dateFormatter.string(from: rightDate)
        if let weight = rightWeight {
            rightText += String(format: "\n%.1f lbs", weight)
        }
        let rightLabelRect = CGRect(x: padding + targetPhotoWidth + spacing, y: padding + targetPhotoHeight + 5, width: targetPhotoWidth, height: labelHeight)
        rightText.draw(in: rightLabelRect, withAttributes: labelAttributes)
    }
}

private func drawImageAspectFill(image: UIImage, in rect: CGRect, context: CGContext) {
    let imageSize = image.size
    let targetSize = rect.size
    
    // Calculate scale to fill (aspect fill)
    let widthRatio = targetSize.width / imageSize.width
    let heightRatio = targetSize.height / imageSize.height
    let scale = max(widthRatio, heightRatio)
    
    let scaledWidth = imageSize.width * scale
    let scaledHeight = imageSize.height * scale
    
    // Center the image
    let x = rect.origin.x + (targetSize.width - scaledWidth) / 2
    let y = rect.origin.y + (targetSize.height - scaledHeight) / 2
    
    // Clip to the target rect
    context.saveGState()
    context.clip(to: rect)
    
    image.draw(in: CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight))
    
    context.restoreGState()
}
}

// MARK: - Photo Picker Sheet
struct PhotoPickerSheet: View {
    let photos: [ProgressPhoto]
    @Binding var selectedPhoto: ProgressPhoto?
    let excludePhoto: ProgressPhoto?
    
    @Environment(\.dismiss) private var dismiss
    
    private var availablePhotos: [ProgressPhoto] {
        photos.filter { $0.id != excludePhoto?.id }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                if availablePhotos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(.atlasTextMuted)
                        
                        Text("No photos available")
                            .font(.system(size: 16))
                            .foregroundColor(.atlasTextMuted)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ], spacing: 8) {
                            ForEach(availablePhotos) { photo in
                                Button(action: {
                                    selectedPhoto = photo
                                    dismiss()
                                }) {
                                    if let uiImage = UIImage(data: photo.photoData) {
                                        VStack(spacing: 4) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 130)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            
                                            Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.system(size: 11))
                                                .foregroundColor(.atlasTextMuted)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Select Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.atlasTextMuted)
                }
            }
        }
    }
}

#Preview {
    PhotoComparisonView()
}
