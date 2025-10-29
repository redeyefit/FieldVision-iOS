//
//  ContractUploadView.swift
//  FieldVision
//
//  Created by Claude Code on 10/26/25.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import SwiftData

struct ContractUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project
    @Query private var settings: [UserSettings]

    @State private var showingDocumentPicker = false
    @State private var showingImagePicker = false
    @State private var extractedPDFText = ""
    @State private var selectedImages: [UIImage] = []
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isExtractingDetails = false
    @State private var extractionSuccess = false
    @State private var showEmptyFieldsWarning = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Existing Conditions")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if extractionSuccess && !project.existingConditions.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                        TextEditor(text: $project.existingConditions)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Scope of Work")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if extractionSuccess && !project.scopeOfWork.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                        TextEditor(text: $project.scopeOfWork)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }

                    if project.contractPDFData != nil && (project.existingConditions.isEmpty || project.scopeOfWork.isEmpty) {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.blue)
                            Text("Tip: Extract these details automatically from your contract PDF below")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Project Scope")
                } footer: {
                    if showEmptyFieldsWarning {
                        Label("Empty scope details may cause inaccurate AI reports. Add details or extract from your contract PDF.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Contract PDF") {
                    if project.contractPDFData != nil {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.blue)
                            Text("Contract PDF Attached")
                            Spacer()
                            Button("Remove") {
                                project.contractPDFData = nil
                                extractedPDFText = ""
                                extractionSuccess = false
                            }
                            .foregroundStyle(.red)
                        }

                        if !extractedPDFText.isEmpty {
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 12) {
                                    Button {
                                        extractContractDetails()
                                    } label: {
                                        HStack {
                                            if isExtractingDetails {
                                                ProgressView()
                                                    .scaleEffect(0.8)
                                                Text("Extracting...")
                                            } else {
                                                Image(systemName: "sparkles")
                                                Text("Extract Scope Details with AI")
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .cornerRadius(8)
                                    }
                                    .disabled(isExtractingDetails)

                                    Divider()

                                    ScrollView {
                                        Text(extractedPDFText)
                                            .font(.caption)
                                            .textSelection(.enabled)
                                    }
                                    .frame(maxHeight: 200)
                                }
                            } label: {
                                Label("Extracted Text & AI Tools", systemImage: "doc.text.magnifyingglass")
                            }
                        }
                    } else {
                        Button {
                            showingDocumentPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("Upload Contract PDF")
                            }
                        }
                    }
                }

                Section("Baseline Photos") {
                    if !project.baselinePhotoData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(project.baselinePhotoData.indices, id: \.self) { index in
                                    let data = project.baselinePhotoData[index]
                                    if let image = UIImage(data: data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(alignment: .topTrailing) {
                                                Button {
                                                    removeBaselinePhoto(at: index)
                                                } label: {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundStyle(.white, .red)
                                                        .font(.title3)
                                                }
                                                .padding(4)
                                            }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Button {
                        showingImagePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "photo.badge.plus")
                            Text("Add Baseline Photos")
                        }
                    }
                }

                Section {
                    Text("These details help the AI understand what existed before work started and what changes are planned, enabling better progress tracking and reporting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Contract & Scope")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Validate before dismissing
                        if project.existingConditions.isEmpty && project.scopeOfWork.isEmpty {
                            showEmptyFieldsWarning = true
                            // Still dismiss after brief delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                dismiss()
                            }
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handlePDFSelection(result)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(images: $selectedImages, onComplete: handleImageSelection)
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

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
                project.contractPDFData = data

                // Extract text from PDF
                if let pdfDocument = PDFDocument(data: data) {
                    extractedPDFText = extractTextFromPDF(pdfDocument)

                    // Optionally auto-populate fields if they're empty
                    if project.scopeOfWork.isEmpty && !extractedPDFText.isEmpty {
                        project.scopeOfWork = "PDF Contract Uploaded - See attached document"
                    }
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

    private func handleImageSelection() {
        var photoDataArray = project.baselinePhotoData

        for image in selectedImages {
            if let data = image.jpegData(compressionQuality: 0.8) {
                photoDataArray.append(data)
            }
        }

        project.baselinePhotoData = photoDataArray
        selectedImages.removeAll()
    }

    private func removeBaselinePhoto(at index: Int) {
        var photoDataArray = project.baselinePhotoData
        photoDataArray.remove(at: index)
        project.baselinePhotoData = photoDataArray
    }

    private func extractContractDetails() {
        print("📄 Starting contract detail extraction...")

        // Check for API key
        guard let userSettings = settings.first,
              let apiKey = userSettings.anthropicKey,
              !apiKey.isEmpty else {
            alertMessage = "API key not found. Please configure your Anthropic API key in Settings."
            showingAlert = true
            return
        }

        guard !extractedPDFText.isEmpty else {
            alertMessage = "No PDF text available to extract from."
            showingAlert = true
            return
        }

        isExtractingDetails = true

        // Create the extraction prompt
        let prompt = """
        Analyze this construction contract and extract the following information:

        1. EXISTING CONDITIONS: Describe what the building/site is like BEFORE work starts (age, condition, materials, layout, etc.)
        2. SCOPE OF WORK: List all work that IS included in this contract (what will be built, changed, or added)
        3. NOT IN SCOPE: List what work is explicitly EXCLUDED or not part of this contract (important!)

        Be specific and detailed. This information will be used to track construction progress accurately.

        CONTRACT TEXT:
        \(extractedPDFText)

        Format your response EXACTLY like this:

        EXISTING CONDITIONS:
        [Detailed description of pre-construction state]

        SCOPE OF WORK:
        [Detailed list of included work]

        NOT IN SCOPE:
        [List of excluded work, or "Not specified" if none mentioned]
        """

        // Create API request
        let endpoint = "https://api.anthropic.com/v1/messages"
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 2000,
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
            alertMessage = "Failed to create request: \(error.localizedDescription)"
            showingAlert = true
            isExtractingDetails = false
            return
        }

        print("🚀 Sending extraction request to Claude...")

        // Make the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isExtractingDetails = false

                if let error = error {
                    print("❌ Network error: \(error.localizedDescription)")
                    self.alertMessage = "Network error: \(error.localizedDescription)"
                    self.showingAlert = true
                    return
                }

                guard let data = data else {
                    self.alertMessage = "No data received from API"
                    self.showingAlert = true
                    return
                }

                // Parse response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        // Check for API error
                        if let error = json["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            print("❌ API Error: \(message)")
                            self.alertMessage = "API Error: \(message)"
                            self.showingAlert = true
                            return
                        }

                        // Parse successful response
                        if let content = json["content"] as? [[String: Any]],
                           let firstBlock = content.first,
                           let text = firstBlock["text"] as? String {

                            print("✅ Extraction complete!")
                            print("📝 Response: \(text.prefix(200))...")

                            // Parse the response sections
                            self.parseAndFillFields(from: text)

                        } else {
                            self.alertMessage = "Failed to parse API response"
                            self.showingAlert = true
                        }
                    }
                } catch {
                    print("❌ JSON parsing error: \(error)")
                    self.alertMessage = "Failed to parse response: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }.resume()
    }

    private func parseAndFillFields(from response: String) {
        let lines = response.components(separatedBy: .newlines)
        var currentSection = ""
        var existingConditionsText = ""
        var scopeOfWorkText = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("EXISTING CONDITIONS:") {
                currentSection = "existing"
                continue
            } else if trimmed.hasPrefix("SCOPE OF WORK:") {
                currentSection = "scope"
                continue
            } else if trimmed.hasPrefix("NOT IN SCOPE:") {
                currentSection = "notinscope"
                // We'll append NOT IN SCOPE to the scope of work for context
                continue
            }

            if !trimmed.isEmpty {
                switch currentSection {
                case "existing":
                    existingConditionsText += trimmed + "\n"
                case "scope":
                    scopeOfWorkText += trimmed + "\n"
                case "notinscope":
                    // Append exclusions to scope for clarity
                    scopeOfWorkText += "\n[NOT IN SCOPE: \(trimmed)]"
                default:
                    break
                }
            }
        }

        // Fill the fields
        if !existingConditionsText.isEmpty {
            project.existingConditions = existingConditionsText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if !scopeOfWorkText.isEmpty {
            project.scopeOfWork = scopeOfWorkText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Show success
        extractionSuccess = true
        alertMessage = "✅ Contract details extracted! Review and edit the fields above if needed."
        showingAlert = true

        print("✅ Fields populated:")
        print("   Existing Conditions: \(project.existingConditions.count) chars")
        print("   Scope of Work: \(project.scopeOfWork.count) chars")
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    var onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.images.append(image)
                parent.onComplete()
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
