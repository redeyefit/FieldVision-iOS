//
//  ContractUploadView.swift
//  FieldVision
//
//  Created by Claude Code on 10/26/25.
//

import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

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

    // Residential code compliance
    @State private var isGeneratingCodeRequirements = false

    private let dwellingTypes = ["Single-family", "Duplex", "Townhouse", "ADU (Accessory Dwelling Unit)"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Scope") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Existing Conditions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $project.existingConditions)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scope of Work")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $project.scopeOfWork)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
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
                                .frame(maxHeight: 200)
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

                Section("Residential Project Details") {
                    Picker("Dwelling Type", selection: $project.dwellingType) {
                        Text("Select Type").tag("")
                        ForEach(dwellingTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    if !project.address.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Jurisdiction")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(project.jurisdiction.isEmpty ? "Auto-detected from address" : project.jurisdiction)
                                .font(.body)
                        }
                    }
                }

                Section("IRC Code Requirements") {
                    Button {
                        generateCodeRequirements()
                    } label: {
                        HStack {
                            if isGeneratingCodeRequirements {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Generating Requirements...")
                            } else {
                                Image(systemName: "sparkles")
                                Text("Generate Requirements")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.3))
                        .foregroundStyle(.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isGeneratingCodeRequirements || project.dwellingType.isEmpty)
                    .buttonStyle(.plain)

                    if !project.codeRequirements.isEmpty || isGeneratingCodeRequirements {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Generated IRC Requirements")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextEditor(text: $project.codeRequirements)
                                .frame(minHeight: 200)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }

                    Text("IRC requirements auto-generated for residential construction")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                        dismiss()
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

    private func generateCodeRequirements() {
        isGeneratingCodeRequirements = true

        // Auto-detect jurisdiction from address with focus on Los Angeles
        if project.jurisdiction.isEmpty {
            project.jurisdiction = detectJurisdiction(from: project.address)
        }

        // Check if API key is available
        guard let apiKey = settings.first?.anthropicKey, !apiKey.isEmpty else {
            alertMessage = "Please configure your Anthropic API key in Settings first."
            showingAlert = true
            isGeneratingCodeRequirements = false
            return
        }

        // Generate requirements using Anthropic API
        callAnthropicAPI(
            apiKey: apiKey,
            address: project.address,
            dwellingType: project.dwellingType,
            jurisdiction: project.jurisdiction,
            scopeOfWork: project.scopeOfWork
        )
    }

    private func detectJurisdiction(from address: String) -> String {
        let lowerAddress = address.lowercased()

        // Detect Los Angeles specifically (city or county)
        if lowerAddress.contains("los angeles") || lowerAddress.contains("la,") ||
           lowerAddress.contains("hollywood") || lowerAddress.contains("venice") ||
           lowerAddress.contains("santa monica") || lowerAddress.contains("beverly hills") ||
           lowerAddress.contains("culver city") || lowerAddress.contains("pasadena") ||
           lowerAddress.contains("glendale") || lowerAddress.contains("burbank") {
            return "2023 California Residential Code + LA City/County Amendments"
        }

        // Detect California cities
        if lowerAddress.contains("san francisco") || lowerAddress.contains("sf,") {
            return "2023 California Residential Code + SF Amendments"
        }
        if lowerAddress.contains("san diego") {
            return "2023 California Residential Code + SD Amendments"
        }
        if lowerAddress.contains("california") || lowerAddress.contains("ca,") || lowerAddress.contains(", ca") {
            return "2024 California Residential Code (CRC)"
        }

        // Other states
        if lowerAddress.contains("texas") || lowerAddress.contains("tx,") || lowerAddress.contains(", tx") {
            return "2021 International Residential Code (IRC) - Texas"
        }
        if lowerAddress.contains("florida") || lowerAddress.contains("fl,") || lowerAddress.contains(", fl") {
            return "2023 Florida Building Code - Residential"
        }
        if lowerAddress.contains("new york") || lowerAddress.contains("ny,") || lowerAddress.contains(", ny") {
            return "2020 New York State Residential Code"
        }

        // Default
        return "2021 International Residential Code (IRC)"
    }

    private func callAnthropicAPI(apiKey: String, address: String, dwellingType: String, jurisdiction: String, scopeOfWork: String) {
        let endpoint = "https://api.anthropic.com/v1/messages"

        guard let url = URL(string: endpoint) else {
            alertMessage = "Invalid API endpoint"
            showingAlert = true
            isGeneratingCodeRequirements = false
            return
        }

        // Build the prompt
        let prompt = """
        You are a construction code compliance expert specializing in residential building codes.

        Generate comprehensive IRC (International Residential Code) requirements for the following residential project:

        PROJECT DETAILS:
        - Location: \(address)
        - Jurisdiction: \(jurisdiction)
        - Dwelling Type: \(dwellingType)
        - Scope of Work: \(scopeOfWork.isEmpty ? "General residential construction" : scopeOfWork)

        Please provide detailed code requirements covering:

        1. GENERAL REQUIREMENTS
           - Permit requirements
           - Inspection stages
           - General compliance notes

        2. STRUCTURAL (IRC Chapters 3-8)
           - Foundation requirements (R403)
           - Floor framing (R502)
           - Wall framing (R602)
           - Roof framing (R802)
           - Lateral bracing and seismic requirements specific to location

        3. ELECTRICAL (IRC Chapter 34/NEC)
           - Circuit requirements
           - AFCI/GFCI protection
           - Kitchen, bathroom, bedroom requirements
           - Service panel sizing

        4. PLUMBING (IRC Chapters 25-32)
           - Water supply sizing
           - DWV system requirements
           - Water heater requirements
           - Fixture rough-in

        5. MECHANICAL/HVAC (IRC Chapters 12-24)
           - Load calculations
           - Duct sizing
           - Ventilation requirements

        6. INSULATION & ENERGY EFFICIENCY
           - R-value requirements for climate zone
           - Window requirements
           - Air sealing

        7. FIRE SAFETY
           - Smoke alarm placement (R314)
           - CO alarm requirements (R315)
           - Egress windows (R310)

        8. DWELLING-SPECIFIC REQUIREMENTS
           - Specific to \(dwellingType)
           - Any special local requirements for \(address)

        9. TYPICAL INSPECTION SCHEDULE
           - Foundation through final

        Format the output clearly with headers and bullet points. Include specific IRC section references.
        Focus on Los Angeles residential construction requirements if applicable.
        """

        // Create request
        var request = URLRequest(url: url)
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
            alertMessage = "Failed to create request: \(error.localizedDescription)"
            showingAlert = true
            isGeneratingCodeRequirements = false
            return
        }

        print("🚀 Generating IRC requirements with AI...")

        // Make API call
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    alertMessage = "Network error: \(error.localizedDescription)"
                    showingAlert = true
                    isGeneratingCodeRequirements = false
                    return
                }

                guard let data = data else {
                    alertMessage = "No data received from API"
                    showingAlert = true
                    isGeneratingCodeRequirements = false
                    return
                }

                // Parse response
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {

                        // Check for API error
                        if let error = json["error"] as? [String: Any],
                           let message = error["message"] as? String {
                            alertMessage = "API Error: \(message)"
                            showingAlert = true
                            isGeneratingCodeRequirements = false
                            return
                        }

                        // Parse successful response
                        if let content = json["content"] as? [[String: Any]],
                           let firstBlock = content.first,
                           let text = firstBlock["text"] as? String {

                            print("✅ IRC requirements generated successfully!")
                            project.codeRequirements = text
                            isGeneratingCodeRequirements = false
                        } else {
                            alertMessage = "Failed to parse API response"
                            showingAlert = true
                            isGeneratingCodeRequirements = false
                        }
                    }
                } catch {
                    alertMessage = "Failed to parse response: \(error.localizedDescription)"
                    showingAlert = true
                    isGeneratingCodeRequirements = false
                }
            }
        }.resume()
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
