//
//  SettingsView.swift
//  FieldVision
//
//  App settings and API configuration
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    
    @State private var userName: String = ""
    @State private var companyName: String = ""
    @State private var licenseNumber: String = ""
    @State private var anthropicKey: String = ""
    
    private var currentSettings: UserSettings? {
        settings.first
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("User Information") {
                    TextField("Your Name", text: $userName)
                    TextField("Company Name", text: $companyName)
                    TextField("License Number", text: $licenseNumber)
                }
                
                Section("AI Configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.blue)
                            Text("Claude (Anthropic)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Text("Advanced AI for construction site analysis")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("API Key") {
                    SecureField("sk-ant-api03-...", text: $anthropicKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .font(.system(.body, design: .monospaced))
                    
                    if !anthropicKey.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("API key configured")
                                .font(.caption)
                        }
                        .foregroundStyle(.green)
                    }
                    
                    Text("Required for AI-powered report generation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Link("Get API Key →", destination: URL(string: "https://console.anthropic.com/")!)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                
                Section {
                    Button("Save Settings") {
                        saveSettings()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    private func loadSettings() {
        if let settings = currentSettings {
            userName = settings.userName
            companyName = settings.companyName
            licenseNumber = settings.licenseNumber
            anthropicKey = settings.anthropicKey ?? ""
        }
    }
    
    private func saveSettings() {
        print("💾 DEBUG: saveSettings() called")
        print("💾 DEBUG: userName: \(userName)")
        print("💾 DEBUG: anthropicKey length: \(anthropicKey.count)")
        
        if let settings = currentSettings {
            print("💾 DEBUG: Updating existing settings")
            settings.userName = userName
            settings.companyName = companyName
            settings.licenseNumber = licenseNumber
            settings.anthropicKey = anthropicKey.isEmpty ? nil : anthropicKey
        } else {
            print("💾 DEBUG: Creating new settings")
            let newSettings = UserSettings(
                userName: userName,
                companyName: companyName,
                licenseNumber: licenseNumber
            )
            newSettings.anthropicKey = anthropicKey.isEmpty ? nil : anthropicKey
            modelContext.insert(newSettings)
        }
        
        do {
            try modelContext.save()
            print("✅ DEBUG: Settings saved successfully!")
        } catch {
            print("❌ DEBUG: Failed to save settings: \(error)")
        }
        
        dismiss()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: UserSettings.self, inMemory: true)
}
