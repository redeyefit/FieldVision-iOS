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
    @State private var exportMessage: String?
    @State private var showExportAlert = false
    
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
        .alert("PDF Exported", isPresented: $showExportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportMessage ?? "PDF export status")
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
                shareReport()
            } label: {
                Label("Share Report", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.3))
                    .foregroundStyle(.blue)
                    .cornerRadius(12)
            }
            .disabled(true)
            
            Button {
                exportPDF()
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generating PDF...")
                    } else {
                        Label("Export PDF", systemImage: "doc.fill")
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
        print("📄 Exporting PDF...")

        // Get user settings
        guard let userSettings = settings.first else {
            exportMessage = "User settings not found. Please configure settings first."
            showExportAlert = true
            return
        }

        // Get project (report should have a relationship to project)
        guard let project = report.project else {
            exportMessage = "Project information not found for this report."
            showExportAlert = true
            return
        }

        isExporting = true

        // Generate PDF on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let pdfURL = PDFGenerator.generatePDF(
                for: report,
                project: project,
                userSettings: userSettings
            )

            DispatchQueue.main.async {
                isExporting = false

                if let pdfURL = pdfURL {
                    // PDF already saved to Documents/DailyReports by PDFGenerator
                    print("✅ PDF saved to: \(pdfURL.path)")

                    let fileName = pdfURL.lastPathComponent
                    exportMessage = "PDF saved successfully to:\n\n\(fileName)\n\nYou can access it in:\nFiles app > On My iPhone > FieldVision > DailyReports"
                    showExportAlert = true
                } else {
                    print("❌ PDF generation failed")
                    exportMessage = "Failed to generate PDF. Please try again."
                    showExportAlert = true
                }
            }
        }
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
