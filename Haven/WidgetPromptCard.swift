// WidgetPromptCard.swift
// Haven (Main App target ONLY)
//
// One-shot prompt shown on Today after the first logged workout. Offers to
// walk the user through adding the home screen widget. Dismissed permanently.

import SwiftUI

struct WidgetPromptCard: View {
    let onShowMe: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Home screen widget").steadySectionHeader()
            Text("See today's recovery state and training without opening the app.")
                .font(SteadyType.body)
                .foregroundColor(.atlasText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button("Show Me How", action: onShowMe)
                    .buttonStyle(SteadyPrimaryButtonStyle())
                Button("Not Now", action: onDismiss)
                    .buttonStyle(SteadySecondaryButtonStyle())
            }
        }
        .steadyPanel()
    }
}

#Preview {
    ZStack {
        Color.atlasBackground.ignoresSafeArea()
        WidgetPromptCard(onShowMe: {}, onDismiss: {})
            .padding()
    }
}
