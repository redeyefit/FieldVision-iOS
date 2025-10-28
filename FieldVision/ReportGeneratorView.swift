//
//  ReportGeneratorView.swift
//  FieldVision
//
//  AI-powered report generation
//

import SwiftUI
import SwiftData

struct ReportGeneratorView: View {
    let project: Project
    let logs: [LogEntry]
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    
    @State private var isGenerating = false
    @State private var generatedReport: DailyReport?
    @State private var error: String?
    
    var processedLogs: [LogEntry] {
        logs.filter { $0.isProcessed && !(($0.extractedFrames ?? []).isEmpty) }
    }

    private var totalImages: Int {
        var count = 0
        for log in logs {
            // Count extracted frames from videos
            if let frames = log.extractedFrames {
                count += frames.count
            }
            // Count individual photos
            if log.photoData != nil {
                count += 1
            }
            // Count thumbnails if no full photo exists
            if log.photoData == nil, log.thumbnailData != nil {
                count += 1
            }
        }
        return count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if isGenerating {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Analyzing site footage...")
                            .font(.headline)
                        
                        Text("Sending \(totalImages) images to Claude AI")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = error {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundStyle(.red)
                        
                        Text("Error")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Try Again") {
                            self.error = nil
                            generateReport()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    ReportSetupView(
                        logsCount: logs.count,
                        imagesCount: totalImages,
                        onGenerate: generateReport
                    )
                }
            }
            .navigationTitle("Generate Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(item: $generatedReport) { report in
                ReportDetailView(report: report)
            }
        }
    }
    
    private func generateReport() {
        print("🔍 DEBUG: generateReport() called")
        print("🔍 DEBUG: Settings count from SwiftData: \(settings.count)")
        
        // Get API key from SwiftData settings
        guard let userSettings = settings.first else {
            error = "No settings found. Please configure your API key in Settings."
            print("❌ DEBUG: No settings found in SwiftData")
            return
        }
        
        // Check for Anthropic API key
        guard let apiKey = userSettings.anthropicKey, !apiKey.isEmpty else {
            error = "No Claude API key found. Please add your Anthropic API key in Settings."
            print("❌ DEBUG: Anthropic key missing")
            return
        }
        
        print("✅ DEBUG: API Key found (length: \(apiKey.count))")
        
        // Collect ALL media from ALL logs
        var allFrames: [Data] = []
        
        for log in logs {
            // Add extracted frames from videos
            if let frames = log.extractedFrames {
                allFrames.append(contentsOf: frames)
                print("📹 DEBUG: Added \(frames.count) video frames from log")
            }
            
            // Add individual photos
            if let photoData = log.photoData {
                allFrames.append(photoData)
                print("📸 DEBUG: Added 1 photo from log")
            }
            
            // Add thumbnails if no full photo exists
            if log.photoData == nil, let thumbnail = log.thumbnailData {
                allFrames.append(thumbnail)
                print("🖼️ DEBUG: Added 1 thumbnail from log")
            }
        }
        
        guard !allFrames.isEmpty else {
            error = "No media found to analyze. Please add photos or videos to this project first."
            print("❌ DEBUG: No media found in logs")
            return
        }
        
        print("📊 DEBUG: Total media collected: \(allFrames.count) images")
        print("📊 DEBUG: From \(logs.count) total logs")
        
        isGenerating = true
        
        print("🤖 Using Claude (Anthropic)")
        let anthropicService = AnthropicService(apiKey: apiKey)
        
        // Get recent reports for context
        let recentReports = project.getRecentReports(days: 7)
        print("📚 Including \(recentReports.count) recent reports for AI context")

        // Get schedule for AI analysis
        let scheduleActivities = project.schedule
        print("📅 Including \(scheduleActivities.count) schedule activities for compliance tracking")

        anthropicService.analyzeConstructionSite(
            frames: allFrames,
            projectName: project.name,
            date: Date(),
            previousReports: recentReports,
            existingConditions: project.existingConditions.isEmpty ? nil : project.existingConditions,
            scopeOfWork: project.scopeOfWork.isEmpty ? nil : project.scopeOfWork,
            baselinePhotos: project.baselinePhotoData,
            schedule: scheduleActivities
        ) { result in
            DispatchQueue.main.async {
                self.isGenerating = false
                
                switch result {
                case .success(let analysis):
                    print("✅ DEBUG: Claude analysis successful!")
                    print("📝 Work Status length: \(analysis.workStatus.count) chars")
                    
                    // Create and save report immediately
                    let report = DailyReport(
                        date: Date(),
                        projectName: project.name,
                        projectAddress: project.address,
                        addedBy: userSettings.userName.isEmpty ? "Unknown" : userSettings.userName
                    )
                    
                    // Combine all analysis into workStatus for now
                    var fullContent = "WORK STATUS:\n\(analysis.workStatus)"
                    
                    if !analysis.observations.isEmpty {
                        fullContent += "\n\nOBSERVATIONS:\n\(analysis.observations)"
                    }
                    
                    if !analysis.notableItems.isEmpty {
                        fullContent += "\n\nNOTABLE ITEMS:\n\(analysis.notableItems)"
                    }
                    
                    report.workStatus = fullContent
                    report.project = project
                    
                    // Save to database
                    modelContext.insert(report)
                    
                    do {
                        try modelContext.save()
                        print("✅ Report auto-saved successfully!")
                        
                        // Navigate to the report detail view
                        self.generatedReport = report
                        
                    } catch {
                        
                        // Navigate to the report detail view
                        self.generatedReport = report
                        
                    } catch {
                        print("❌ Error saving report: \(error)")
                        self.error = "Report generated but failed to save: \(error.localizedDescription)"
                    }
                    
                case .failure(let err):
                    print("❌ DEBUG: Claude error: \(err.localizedDescription)")
                    self.error = "Failed to generate report: \(err.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Setup View
struct ReportSetupView: View {
    let logsCount: Int
    let imagesCount: Int
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 70))
                .foregroundStyle(.blue)

            Text("Ready to Generate Report")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "photo.stack")
                        .foregroundStyle(.blue)
                    Text("\(imagesCount) images to analyze")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.blue)
                    Text("Claude AI analysis")
                    Spacer()
                }
                
                HStack {
                    Image(systemName: "hammer.fill")
                        .foregroundStyle(.blue)
                    Text("Construction-focused insights")
                    Spacer()
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            Button {
                onGenerate()
            } label: {
                Label("Generate Report", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            
            Text("Claude will analyze your site footage and automatically save a detailed construction report.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    ReportGeneratorView(
        project: Project(name: "Test", address: "123 Main", clientName: "Client"),
        logs: []
    )
    .modelContainer(for: [UserSettings.self, Project.self])
}
