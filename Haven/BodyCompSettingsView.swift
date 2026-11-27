import SwiftUI
import LocalAuthentication

struct BodyCompSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("bodyCompProtectionEnabled") private var protectionEnabled = false
    
    @State private var showingAuthError = false
    @State private var authErrorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.atlasBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Privacy Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("PRIVACY")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.atlasAccent)
                            .tracking(2)
                        
                        Toggle(isOn: $protectionEnabled) {
                            HStack(spacing: 12) {
                                Image(systemName: "faceid")
                                    .font(.system(size: 20))
                                    .foregroundColor(.atlasPrimary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Require Face ID / Touch ID")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.atlasText)
                                    
                                    Text("Protect your body composition data")
                                        .font(.system(size: 13))
                                        .foregroundColor(.atlasTextMuted)
                                }
                            }
                        }
                        .tint(.atlasPrimary)
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .onChange(of: protectionEnabled) { oldValue, newValue in
                            if newValue {
                                verifyBiometrics()
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Body Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.atlasPrimary)
                }
            }
            .alert("Authentication Unavailable", isPresented: $showingAuthError) {
                Button("OK", role: .cancel) {
                    protectionEnabled = false
                }
            } message: {
                Text(authErrorMessage)
            }
        }
    }
    
    private func verifyBiometrics() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // Biometrics available - no action needed, just enable
        } else {
            authErrorMessage = "Face ID / Touch ID is not available on this device. Please enable it in Settings."
            showingAuthError = true
        }
    }
}

#Preview {
    BodyCompSettingsView()
}
