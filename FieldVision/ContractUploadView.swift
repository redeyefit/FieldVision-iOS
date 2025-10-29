//
//  ContractUploadView.swift
//  FieldVision
//
//  Created by Claude Code on 10/26/25.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContractUploadView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var project: Project

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

        // Auto-detect jurisdiction from address
        if project.jurisdiction.isEmpty {
            // Simple jurisdiction detection based on address
            let address = project.address.lowercased()
            if address.contains("california") || address.contains("ca") {
                project.jurisdiction = "2024 California Residential Code (CRC)"
            } else if address.contains("texas") || address.contains("tx") {
                project.jurisdiction = "2021 International Residential Code (IRC)"
            } else if address.contains("florida") || address.contains("fl") {
                project.jurisdiction = "2023 Florida Building Code - Residential"
            } else if address.contains("new york") || address.contains("ny") {
                project.jurisdiction = "2020 New York State Residential Code"
            } else {
                project.jurisdiction = "2021 International Residential Code (IRC)"
            }
        }

        // TODO: Replace with actual AI generation using Anthropic API
        // For now, generate comprehensive placeholder requirements
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            project.codeRequirements = generatePlaceholderRequirements(
                dwellingType: project.dwellingType,
                jurisdiction: project.jurisdiction,
                scopeOfWork: project.scopeOfWork
            )
            isGeneratingCodeRequirements = false
        }
    }

    private func generatePlaceholderRequirements(dwellingType: String, jurisdiction: String, scopeOfWork: String) -> String {
        var requirements = """
        RESIDENTIAL CODE REQUIREMENTS - \(dwellingType)
        Jurisdiction: \(jurisdiction)

        GENERAL REQUIREMENTS:
        • All work must comply with current IRC and local amendments
        • Building permit required for structural, electrical, plumbing, and mechanical work
        • Inspections required at key stages (foundation, framing, rough-in, final)

        STRUCTURAL (IRC Chapter 3-8):
        • Foundation must meet R403 requirements for footings and concrete
        • Floor framing per R502 (joist spacing, spans, blocking)
        • Wall framing per R602 (stud spacing, headers, bracing)
        • Roof framing per R802 (rafter/truss design, connections)
        • Lateral bracing and seismic requirements per local amendments

        ELECTRICAL (IRC Chapter 34/NEC):
        • All circuits properly sized with AFCI/GFCI protection
        • Kitchen: 2 small appliance circuits (20A), dedicated circuits for major appliances
        • Bathroom: Dedicated 20A GFCI circuit
        • Bedroom: 15A circuits with AFCI protection
        • Outdoor/wet areas: GFCI protected outlets
        • Service panel properly sized for load calculations

        PLUMBING (IRC Chapter 25-32):
        • Water supply: Proper pipe sizing per fixture unit calculations (P2903)
        • DWV system: Proper trap sizing, venting per P3105
        • Water heater: TPR valve, drain pan, seismic strapping (P2801)
        • Fixtures: Proper rough-in dimensions and access

        MECHANICAL/HVAC (IRC Chapter 12-24):
        • Heating/cooling loads calculated per Manual J
        • Duct sizing per Manual D
        • Combustion air for fuel-burning appliances (M1701)
        • Ventilation requirements per M1505 (whole-house, bath, kitchen)

        ENERGY EFFICIENCY:
        • Insulation: R-value requirements per climate zone
        • Windows: U-factor and SHGC requirements
        • Air sealing per energy code
        • Ventilation meeting ASHRAE 62.2 requirements

        FIRE SAFETY:
        • Smoke alarms in all bedrooms, outside sleeping areas, each level (R314)
        • CO alarms where required (R315)
        • Egress windows in bedrooms (R310)
        • Fire-rated assemblies where required

        """

        // Add dwelling-specific requirements
        if dwellingType.contains("ADU") {
            requirements += """

            ADU-SPECIFIC REQUIREMENTS:
            • Setbacks per local zoning ordinances
            • Maximum size restrictions (typically 1,200 sq ft or 50% of primary)
            • Parking requirements (typically 1 space, may be waived)
            • Fire sprinklers if required by local code
            • Separate utilities or submetered
            • Separate address if detached

            """
        } else if dwellingType.contains("Duplex") {
            requirements += """

            DUPLEX-SPECIFIC REQUIREMENTS:
            • Fire-rated separation between units (1-hour rated)
            • Sound attenuation requirements (STC 50 minimum)
            • Separate utilities metering
            • Individual HVAC systems
            • Separate means of egress

            """
        }

        requirements += """
        INSPECTION SCHEDULE (Typical):
        1. Foundation inspection (before concrete pour)
        2. Rough framing inspection (before covering)
        3. Rough electrical inspection (before covering)
        4. Rough plumbing inspection (before covering)
        5. Rough mechanical inspection (before covering)
        6. Insulation inspection (before drywall)
        7. Final inspection (all work complete)

        NOTE: This is a general reference. Verify all requirements with local building department.
        Actual requirements may vary based on specific project conditions.

        Next Steps:
        • Submit plans to building department for permit
        • Coordinate inspection schedule with trades
        • Document all code-required items with photos
        • Track inspection approvals in daily reports
        """

        return requirements
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
