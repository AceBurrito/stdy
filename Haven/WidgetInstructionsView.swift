// WidgetInstructionsView.swift
// Haven (Main App target ONLY)
//
// Simple step-by-step sheet explaining how to add the Atlas widget
// to the iOS home screen. Presented from WidgetPromptCard.

import SwiftUI

struct WidgetInstructionsView: View {
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Color.atlasBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "apps.iphone")
                        .font(.system(size: 40))
                        .foregroundColor(.atlasAmber)

                    Text("Add the Atlas Widget")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.atlasText)
                }

                // Steps
                VStack(alignment: .leading, spacing: 20) {
                    stepRow(number: 1, text: "Go to your Home Screen")
                    stepRow(number: 2, text: "Long press any empty area until apps jiggle")
                    stepRow(number: 3, text: "Tap  +  in the top left corner")
                    stepRow(number: 4, text: "Search \"Atlas\"")
                    stepRow(number: 5, text: "Choose your size and tap \"Add Widget\"")
                }
                .padding(.horizontal, 8)

                Spacer()

                // Done button
                Button(action: onDone) {
                    Text("Got It")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.atlasBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.atlasAmber)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 28)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.atlasBackground)
                .frame(width: 28, height: 28)
                .background(Color.atlasAmber)
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.atlasText)
                .padding(.top, 3)
        }
    }
}

// MARK: - Preview

#Preview {
    WidgetInstructionsView(onDone: {})
}