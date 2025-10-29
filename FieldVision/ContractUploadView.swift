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
