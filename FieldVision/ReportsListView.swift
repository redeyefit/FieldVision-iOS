//
//  ReportsListView.swift
//  FieldVision
//
//  View all generated reports for a project
//

import SwiftUI
import SwiftData

struct ReportsListView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    
    // Get all reports for this project, sorted by date (newest first)
    var reports: [DailyReport] {
        project.reports.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        ZStack {
            if reports.isEmpty {
                EmptyReportsView()
            } else {
                List {
                    ForEach(reports) { report in
                        NavigationLink(destination: ReportDetailView(report: report)) {
                            ReportRowView(report: report)
                        }
                    }
                    .onDelete(perform: deleteReports)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func deleteReports(at offsets: IndexSet) {
        for index in offsets {
            let report = reports[index]
            modelContext.delete(report)
        }
    }
}

// MARK: - Empty State
struct EmptyReportsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 70))
                .foregroundStyle(.gray)
            
            Text("No Reports Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Generate your first AI-powered daily report from your site logs")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Report Row
struct ReportRowView: View {
    let report: DailyReport
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.blue)
                Text(report.date.formatted(date: .long, time: .omitted))
                    .font(.headline)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Work Status Preview
            if !report.workStatus.isEmpty {
                Text(report.workStatus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.leading, 24)
            }
            
            // Metadata
            HStack(spacing: 16) {
                if !report.addedBy.isEmpty {
                    Label(report.addedBy, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Label(report.createdDate.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 24)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        ReportsListView(project: Project(name: "Test Project", address: "123 Main St", clientName: "Client"))
    }
    .modelContainer(for: [Project.self, DailyReport.self])
}
