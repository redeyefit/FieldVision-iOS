//
//  ReportDetailView.swift
//  FieldVision
//
//  Detailed view of a single report
//

import SwiftUI
import SwiftData

struct ReportDetailView: View {
    @Bindable var report: DailyReport
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [UserSettings]

    @State private var showingDeleteAlert = false
    @State private var isEditing = false
    @State private var isExporting = false
    @State private var exportedPDFURL: URL?
    @State private var showExportOptions = false
    @State private var showShareSheet = false
    @State private var exportErrorMessage: String?
    @State private var showErrorAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerCard
                
                if !report.workStatus.isEmpty {
                    workStatusSection
                }
                
                actionButtons
            }
            .padding()
        }
        .navigationTitle("Daily Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                    if !isEditing {
                        saveChanges()
                    }
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Delete Report", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteReport()
            }
        } message: {
            Text("Are you sure you want to delete this report? This action cannot be undone.")
        }
        .alert("Export Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage ?? "Failed to export PDF")
        }
        .confirmationDialog("PDF Exported Successfully", isPresented: $showExportOptions, titleVisibility: .visible) {
            Button("Share") {
                sharePDF()
            }
            Button("Done", role: .cancel) { }
        } message: {
            if let url = exportedPDFURL {
                Text(url.lastPathComponent)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfURL = exportedPDFURL {
                ShareSheet(items: [pdfURL])
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.2")
                    .foregroundStyle(.blue)
                Text(report.projectName)
                    .font(.headline)
            }
            
            if !report.projectAddress.isEmpty {
                HStack {
                    Image(systemName: "mappin.circle")
                        .foregroundStyle(.secondary)
                    Text(report.projectAddress)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text(report.date.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !report.addedBy.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                        Text(report.addedBy)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var workStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Report Content", systemImage: "doc.text.fill")
                .font(.headline)
                .foregroundStyle(.primary)
            
            if isEditing {
                TextEditor(text: $report.workStatus)
                    .frame(minHeight: 300)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else {
                Text(report.workStatus)
                    .font(.body)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                print("🔵 Share Report button tapped")
                exportPDF()
                print("🔵 Share Report button action completed")
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Preparing Report...")
                    } else {
                        Label("Share Report", systemImage: "square.and.arrow.up")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green.opacity(0.3))
                .foregroundStyle(.green)
                .cornerRadius(12)
            }
            .disabled(isExporting)
        }
        .padding(.top)
    }
    
    // MARK: - Actions
    
    func saveChanges() {
        do {
            try modelContext.save()
            print("✅ Report updated successfully")
        } catch {
            print("❌ Error saving report: \(error)")
        }
    }
    
    func deleteReport() {
        modelContext.delete(report)
        dismiss()
    }
    
    func shareReport() {
        print("📤 Share report - Coming soon")
    }
    
    func exportPDF() {
        // IMPORTANT: This function has NO PREVIEW, NO SHARING, NO UIActivityViewController
        // It ONLY saves the PDF to Documents/DailyReports and shows a success alert
        // This prevents iOS preview crashes (makeImagePlus errors)

        print("📄 Step 1: exportPDF() called")
        print("📄 Step 1a: Report exists: \(report.projectName)")

        print("📄 Step 2: Checking settings...")
        print("📄 Step 2a: Settings count: \(settings.count)")

        // Get user settings
        guard let userSettings = settings.first else {
            print("❌ Step 2b: No user settings found")
            exportErrorMessage = "User settings not found. Please configure settings first."
            showErrorAlert = true
            return
        }
        print("✅ Step 2c: User settings found - userName: \(userSettings.userName)")

        print("📄 Step 3: Checking project relationship...")
        // Get project (report should have a relationship to project)
        guard let project = report.project else {
            print("❌ Step 3a: No project relationship found")
            exportErrorMessage = "Project information not found for this report."
            showErrorAlert = true
            return
        }
        print("✅ Step 3b: Project found - name: \(project.name)")

        print("📄 Step 4: Setting isExporting to true...")
        isExporting = true
        print("✅ Step 4a: isExporting = true")

        print("📄 Step 5: About to call PDFGenerator.generatePDF()...")
        print("📄 Step 5a: Report workStatus length: \(report.workStatus.count)")

        // Generate PDF on main thread (must stay on main thread for SwiftData access)
        // PDF generation is fast enough that it won't block UI
        print("📄 Step 5b: Calling PDFGenerator.generatePDF()...")
        let pdfURL = PDFGenerator.generatePDF(
            for: report,
            project: project,
            userSettings: userSettings
        )
        print("📄 Step 5c: PDFGenerator.generatePDF() returned")

        print("📄 Step 6: Setting isExporting to false...")
        isExporting = false
        print("✅ Step 6a: isExporting = false")

        print("📄 Step 7: Checking pdfURL result...")
        if let pdfURL = pdfURL {
            print("✅ Step 7a: PDF URL exists")
            print("✅ PDF saved to: \(pdfURL.path)")

            print("📄 Step 7b: Storing PDF URL...")
            exportedPDFURL = pdfURL

            print("📄 Step 7c: Showing export options...")
            showExportOptions = true
            print("✅ Step 7d: Options dialog shown")
        } else {
            print("❌ Step 7e: PDF URL is nil")
            exportErrorMessage = "Failed to generate PDF. Please try again."
            showErrorAlert = true
            print("✅ Step 7f: Error alert shown")
        }

        print("✅ Step 8: exportPDF() completed successfully")
    }

    func sharePDF() {
        print("📤 Share PDF action triggered")
        showShareSheet = true
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

#Preview {
    NavigationStack {
        ReportDetailView(report: DailyReport(
            date: Date(),
            projectName: "Downtown Office",
            projectAddress: "123 Main Street",
            addedBy: "John Smith"
        ))
    }
    .modelContainer(for: DailyReport.self, inMemory: true)
}
