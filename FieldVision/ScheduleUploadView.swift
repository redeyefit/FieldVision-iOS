//
//  ScheduleUploadView.swift
//  FieldVision
//
//  AI-powered schedule extraction from PDF
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import SwiftData

struct ScheduleUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var project: Project
    @Query private var settings: [UserSettings]

    @State private var showingDocumentPicker = false
    @State private var pdfFileName = ""
    @State private var extractedPDFText = ""
    @State private var extractedActivities: [ExtractedActivity] = []
    @State private var isExtracting = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var editingActivity: ExtractedActivity?

    var body: some View {
        NavigationStack {
            Form {
                // PDF Upload Section
                Section("Schedule PDF") {
                    if project.schedulePDFData != nil {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.blue)
                            Text(pdfFileName.isEmpty ? "Schedule PDF Attached" : pdfFileName)
                            Spacer()
                            Button("Remove") {
                                project.schedulePDFData = nil
                                pdfFileName = ""
                                extractedPDFText = ""
                                extractedActivities = []
                            }
                            .foregroundStyle(.red)
                        }

                        if !extractedPDFText.isEmpty {
                            DisclosureGroup("Extracted Text Preview") {
                                ScrollView {
                                    Text(extractedPDFText)
                                        .font(.caption)
                                        .textSelection(.enabled)
                                }
                                .frame(maxHeight: 150)
                            }
                        }

                        if extractedActivities.isEmpty && !isExtracting {
                            Button {
                                extractScheduleWithAI()
                            } label: {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text("Extract Activities with AI")
                                }
                            }
                            .disabled(extractedPDFText.isEmpty)
                        }
                    } else {
                        Button {
                            showingDocumentPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("Upload Schedule PDF")
                            }
                        }
                    }
                }

                // AI Extraction Loading
                if isExtracting {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Claude is analyzing your schedule...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }

                // Extracted Activities Review
                if !extractedActivities.isEmpty && !isExtracting {
                    Section {
                        Text("Review and edit activities before saving")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section("Extracted Activities (\(extractedActivities.count))") {
                        ForEach(extractedActivities) { activity in
                            ActivityRowView(
                                activity: activity,
                                onEdit: { editingActivity = activity },
                                onDelete: { deleteActivity(activity) },
                                onToggleComplete: { toggleComplete(activity) }
                            )
                        }
                    }
                }

                // Info Section
                if extractedActivities.isEmpty && !isExtracting {
                    Section {
                        Text("Upload your project schedule PDF and Claude AI will automatically extract activities, trades, dates, and durations.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Schedule Upload")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSchedule()
                    }
                    .disabled(extractedActivities.isEmpty)
                }
            }
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handlePDFSelection(result)
            }
            .sheet(item: $editingActivity) { activity in
                EditActivityView(activity: activity) { updated in
                    updateActivity(updated)
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - PDF Handling

    private func handlePDFSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            do {
                guard url.startAccessingSecurityScopedResource() else {
                    alertMessage = "Unable to access the selected file"
                    showingAlert = true
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let data = try Data(contentsOf: url)
                project.schedulePDFData = data
                pdfFileName = url.lastPathComponent

                // Extract text from PDF
                if let pdfDocument = PDFDocument(data: data) {
                    extractedPDFText = extractTextFromPDF(pdfDocument)
                }
            } catch {
                alertMessage = "Failed to load PDF: \(error.localizedDescription)"
                showingAlert = true
            }

        case .failure(let error):
            alertMessage = "Failed to select PDF: \(error.localizedDescription)"
            showingAlert = true
        }
    }

    private func extractTextFromPDF(_ pdfDocument: PDFDocument) -> String {
        var extractedText = ""

        for pageIndex in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: pageIndex),
               let pageText = page.string {
                extractedText += pageText + "\n\n"
            }
        }

        return extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - AI Extraction

    private func extractScheduleWithAI() {
        guard let userSettings = settings.first,
              let apiKey = userSettings.anthropicKey,
              !apiKey.isEmpty else {
            alertMessage = "No Claude API key found. Please add your Anthropic API key in Settings."
            showingAlert = true
            return
        }

        guard !extractedPDFText.isEmpty else {
            alertMessage = "No text extracted from PDF"
            showingAlert = true
            return
        }

        isExtracting = true

        let prompt = """
        You are a construction scheduler analyzing a project schedule. Extract all activities from the following schedule text.

        For each activity, provide:
        - activityName: Brief name of the task (e.g., "Demo", "Rough Framing", "HVAC Install")
        - trade: The trade responsible (e.g., "Demolition", "Framing", "HVAC", "Electrical", "Plumbing")
        - startDate: Start date in ISO 8601 format (YYYY-MM-DD)
        - duration: Number of workdays (integer)

        IMPORTANT: Return ONLY a valid JSON array with no additional text. Format:
        [
          {
            "activityName": "Demo Existing Structure",
            "trade": "Demolition",
            "startDate": "2025-01-15",
            "duration": 5
          }
        ]

        Schedule text:
        \(extractedPDFText)
        """

        // Make API call to Claude
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 4000,
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            isExtracting = false
            alertMessage = "Failed to prepare request: \(error.localizedDescription)"
            showingAlert = true
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isExtracting = false

                if let error = error {
                    self.alertMessage = "Network error: \(error.localizedDescription)"
                    self.showingAlert = true
                    return
                }

                guard let data = data else {
                    self.alertMessage = "No data received"
                    self.showingAlert = true
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Check for API error
                        if let error = json["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            self.alertMessage = "Claude API Error: \(message)"
                            self.showingAlert = true
                            return
                        }

                        // Parse successful response
                        if let content = json["content"] as? [[String: Any]],
                           let firstBlock = content.first,
                           let text = firstBlock["text"] as? String {
                            self.parseActivitiesFromResponse(text)
                        } else {
                            self.alertMessage = "Failed to parse response structure"
                            self.showingAlert = true
                        }
                    }
                } catch {
                    self.alertMessage = "JSON parsing error: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }.resume()
    }

    private func parseActivitiesFromResponse(_ text: String) {
        print("📥 Raw Claude Response:")
        print(text)

        // Extract JSON from response (Claude might include markdown code blocks)
        var jsonText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present
        if jsonText.hasPrefix("```json") {
            jsonText = jsonText.replacingOccurrences(of: "```json", with: "")
            jsonText = jsonText.replacingOccurrences(of: "```", with: "")
            jsonText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if jsonText.hasPrefix("```") {
            jsonText = jsonText.replacingOccurrences(of: "```", with: "")
            jsonText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        print("📋 Cleaned JSON:")
        print(jsonText)

        guard let jsonData = jsonText.data(using: .utf8) else {
            alertMessage = "Failed to convert response to data"
            showingAlert = true
            return
        }

        do {
            let decoder = JSONDecoder()

            // Custom date decoding strategy for "yyyy-MM-dd" format
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone.current
            dateFormatter.isLenient = true

            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            print("📅 Date formatter configured: yyyy-MM-dd with timezone \(TimeZone.current.identifier)")

            let activities = try decoder.decode([ExtractedActivity].self, from: jsonData)

            print("✅ Successfully parsed \(activities.count) activities")
            for activity in activities {
                print("  - \(activity.activityName): \(activity.trade), starts \(activity.startDate), \(activity.duration) days")
            }

            self.extractedActivities = activities

        } catch let DecodingError.keyNotFound(key, context) {
            alertMessage = "Missing field '\(key.stringValue)' in JSON\n\nPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))\n\nJSON: \(jsonText.prefix(500))"
            showingAlert = true
            print("❌ Decoding error - key not found: \(key)")

        } catch let DecodingError.typeMismatch(type, context) {
            alertMessage = "Wrong type for field (expected \(type))\n\nPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))\n\nJSON: \(jsonText.prefix(500))"
            showingAlert = true
            print("❌ Decoding error - type mismatch: \(type)")

        } catch let DecodingError.valueNotFound(type, context) {
            alertMessage = "Missing value for type \(type)\n\nPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))\n\nJSON: \(jsonText.prefix(500))"
            showingAlert = true
            print("❌ Decoding error - value not found: \(type)")

        } catch let DecodingError.dataCorrupted(context) {
            alertMessage = "Corrupted data\n\n\(context.debugDescription)\n\nPath: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))\n\nJSON: \(jsonText.prefix(500))"
            showingAlert = true
            print("❌ Decoding error - data corrupted: \(context)")

        } catch {
            alertMessage = "Failed to parse activities: \(error.localizedDescription)\n\nJSON: \(jsonText.prefix(500))"
            showingAlert = true
            print("❌ General parsing error: \(error)")
        }
    }

    // MARK: - Activity Management

    private func deleteActivity(_ activity: ExtractedActivity) {
        extractedActivities.removeAll { $0.id == activity.id }
    }

    private func toggleComplete(_ activity: ExtractedActivity) {
        if let index = extractedActivities.firstIndex(where: { $0.id == activity.id }) {
            extractedActivities[index].isComplete.toggle()
        }
    }

    private func updateActivity(_ updated: ExtractedActivity) {
        if let index = extractedActivities.firstIndex(where: { $0.id == updated.id }) {
            extractedActivities[index] = updated
        }
    }

    // MARK: - Save

    private func saveSchedule() {
        print("💾 Saving \(extractedActivities.count) activities to schedule...")

        // Convert extracted activities to ScheduleActivity models
        for extractedActivity in extractedActivities {
            let scheduleActivity = ScheduleActivity(
                activityName: extractedActivity.activityName,
                trade: extractedActivity.trade,
                startDate: extractedActivity.startDate,
                duration: extractedActivity.duration,
                notes: nil
            )
            scheduleActivity.isComplete = extractedActivity.isComplete
            scheduleActivity.project = project
            modelContext.insert(scheduleActivity)

            print("  ✓ \(scheduleActivity.activityName) - \(scheduleActivity.trade)")
        }

        // Save the context
        do {
            try modelContext.save()
            print("✅ Schedule saved successfully! Total activities in project: \(project.schedule.count)")
            dismiss()
        } catch {
            print("❌ Failed to save schedule: \(error)")
            alertMessage = "Failed to save schedule: \(error.localizedDescription)"
            showingAlert = true
        }
    }
}

// MARK: - Extracted Activity Model
struct ExtractedActivity: Identifiable, Codable {
    var id: UUID
    var activityName: String
    var trade: String
    var startDate: Date
    var duration: Int
    var isComplete: Bool

    enum CodingKeys: String, CodingKey {
        case activityName, trade, startDate, duration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.activityName = try container.decode(String.self, forKey: .activityName)
        self.trade = try container.decode(String.self, forKey: .trade)
        self.startDate = try container.decode(Date.self, forKey: .startDate)
        self.duration = try container.decode(Int.self, forKey: .duration)
        self.isComplete = false
    }

    // For encoding (if needed)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(activityName, forKey: .activityName)
        try container.encode(trade, forKey: .trade)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(duration, forKey: .duration)
    }
}

// MARK: - Activity Row View
struct ActivityRowView: View {
    let activity: ExtractedActivity
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: onToggleComplete) {
                    Image(systemName: activity.isComplete ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(activity.isComplete ? .green : .gray)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.activityName)
                        .font(.headline)
                        .strikethrough(activity.isComplete)

                    Text(activity.trade)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                Label(activity.startDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("\(activity.duration) days", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit Activity View
struct EditActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @State var activity: ExtractedActivity
    let onSave: (ExtractedActivity) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity Details") {
                    TextField("Activity Name", text: $activity.activityName)
                    TextField("Trade", text: $activity.trade)
                }

                Section("Schedule") {
                    DatePicker("Start Date", selection: $activity.startDate, displayedComponents: .date)
                    Stepper("Duration: \(activity.duration) workdays", value: $activity.duration, in: 1...365)
                }

                Section("Status") {
                    Toggle("Mark as Complete", isOn: $activity.isComplete)
                }
            }
            .navigationTitle("Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(activity)
                        dismiss()
                    }
                }
            }
        }
    }
}
