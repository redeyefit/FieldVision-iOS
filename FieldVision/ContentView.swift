
//
//  ContentView.swift
//  FieldVision
//
//  Created by Steven Fernandez on 10/10/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @State private var showingAddProject = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if projects.isEmpty {
                    EmptyProjectsView(showingAddProject: $showingAddProject)
                } else {
                    ProjectsListView(projects: projects)
                }
            }
            .navigationTitle("FieldVision")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddProject = true
                    } label: {
                        Label("New Project", systemImage: "plus")
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingAddProject) {
                AddProjectView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

// MARK: - Empty State
struct EmptyProjectsView: View {
    @Binding var showingAddProject: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2")
                .font(.system(size: 80))
                .foregroundStyle(.gray)
            
            Text("No Projects Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first project to start logging daily activities")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                showingAddProject = true
            } label: {
                Label("Create Project", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top)
        }
        .padding()
    }
}

// MARK: - Projects List
struct ProjectsListView: View {
    let projects: [Project]
    
    var body: some View {
        List {
            ForEach(projects) { project in
                NavigationLink(destination: ProjectDetailView(project: project)) {
                    ProjectRowView(project: project)
                }
            }
        }
    }
}

// MARK: - Project Row
struct ProjectRowView: View {
    let project: Project
    
    var todaysLogs: Int {
        let calendar = Calendar.current
        return project.logs.filter {
            calendar.isDateInToday($0.timestamp)
        }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.name)
                .font(.headline)
            
            Text(project.address)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                Label("\(todaysLogs) logs today", systemImage: "video.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                Spacer()
                
                if project.isActive {
                    Text("Active")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundStyle(.green)
                        .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Project View
struct AddProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var projectName = ""
    @State private var address = ""
    @State private var clientName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Project Information") {
                    TextField("Project Name", text: $projectName)
                    TextField("Address", text: $address)
                    TextField("Client Name", text: $clientName)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(projectName.isEmpty)
                }
            }
        }
    }
    
    private func createProject() {
        let project = Project(
            name: projectName,
            address: address,
            clientName: clientName,
            existingConditions: "",  // ← ADD THIS
            scopeOfWork: ""          // ← ADD THIS
        )
        modelContext.insert(project)
        dismiss()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Project.self, LogEntry.self, DailyReport.self])
}
