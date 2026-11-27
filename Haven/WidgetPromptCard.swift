// WidgetPromptCard.swift
// Haven (Main App target ONLY)
//
// Prompt card shown below the DayCompleteCard after the user completes
// all habits for the first time. Offers to guide them through adding
// the Atlas home screen widget. One-shot — dismissed permanently.

import SwiftUI

struct WidgetPromptCard: View {
    let onShowMe: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "apps.iphone")
                    .font(.system(size: 20))
                    .foregroundColor(.atlasAmber)
                Text("Add Atlas to your Home Screen")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.atlasText)
            }

            // Description
            Text("See your habits, training, and Pace updates without opening the app.")
                .font(.system(size: 14))
                .foregroundColor(.atlasTextMuted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            // Widget preview mock
            widgetPreviewMock
                .padding(.vertical, 4)

            // Buttons
            HStack(spacing: 16) {
                Button(action: onShowMe) {
                    Text("Show Me How")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.atlasBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.atlasAmber)
                        .cornerRadius(10)
                }

                Button(action: onDismiss) {
                    Text("Maybe Later")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.atlasTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(10)
                }
            }
        }
        .padding(20)
        .background(Color.atlasAmber.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.atlasAmber.opacity(0.2), lineWidth: 1)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(1.0)) {
                appeared = true
            }
        }
    }

    // MARK: - Widget Preview Mock

    /// A mini visual representation of the small widget to show users what they'll get.
    private var widgetPreviewMock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("▼ Pace improved")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 0.357, green: 0.643, blue: 0.643))
                Spacer()
                Text("🔥 4d")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 0.878, green: 0.471, blue: 0.337))
            }

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 0.5)

            HStack(spacing: 4) {
                Circle().fill(Color(red: 0.357, green: 0.643, blue: 0.643)).frame(width: 6, height: 6)
                Circle().fill(Color(red: 0.357, green: 0.643, blue: 0.643)).frame(width: 6, height: 6)
                Circle().fill(Color.white.opacity(0.2)).frame(width: 6, height: 6)
                Text("2/3")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 3) {
                Text("🏋️")
                    .font(.system(size: 9))
                Text("Upper Body A")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(12)
        .frame(width: 140)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.16, blue: 0.16),
                    Color(red: 0.07, green: 0.07, blue: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.atlasBackground.ignoresSafeArea()
        WidgetPromptCard(
            onShowMe: {},
            onDismiss: {}
        )
        .padding(.horizontal, 20)
    }
}