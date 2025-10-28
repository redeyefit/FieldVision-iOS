//
//  ProjectDetailView.swift
//  FieldVision
//
//  Created by Steven Fernandez on 10/10/25.
//

import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct ProjectDetailView: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var modelContext
    
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingVideoPicker = false
    @State private var selectedVideoItems: [PhotosPickerItem] = []
    @State private var todaysLogsCache: [LogEntry] = []
    @State private var showingCamera = false
    @State private var showingReportGenerator = false
    @State private var showingContractUpload = false
    @State private var showingScheduleUpload = false
    
    var todaysLogs: [LogEntry] {
        let calendar = Calendar.current
        return project.logs.filter {
            calendar.isDateInToday($0.timestamp)
        }.sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        ZStack {
            if todaysLogsCache.isEmpty {
                EmptyLogsView()
            } else {
                LogsListView(logs: todaysLogsCache, onDelete: refreshLogs)
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label("Add Photos", systemImage: "photo")
                    }
                    
                    Button {
                        showingVideoPicker = true
                    } label: {
                        Label("Add Videos", systemImage: "video")
                    }
                    
                    Divider()
                    
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Record Video", systemImage: "video.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingContractUpload = true
                } label: {
                    Label("Contract & Scope", systemImage: "doc.badge.gearshape")
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingScheduleUpload = true
                } label: {
                    Label("Schedule", systemImage: "calendar.badge.clock")
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                NavigationLink(destination: ReportsListView(project: project)) {
                    Label("View Reports", systemImage: "doc.text")
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingReportGenerator = true
                } label: {
                    Label("Generate Report", systemImage: "sparkles")
                }
                .disabled(todaysLogsCache.isEmpty)
            }
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 20,
            matching: .images
        )
        .photosPicker(
            isPresented: $showingVideoPicker,
            selection: $selectedVideoItems,
            maxSelectionCount: 10,
            matching: .videos
        )
        .sheet(isPresented: $showingCamera) {
            CameraView(project: project)
        }
        .onChange(of: showingCamera) { _, isShowing in
            if !isShowing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    refreshLogs()
                }
            }
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        let log = LogEntry(type: .photo, photoData: data)
                        log.project = project
                        modelContext.insert(log)
                    }
                }
                
                await MainActor.run {
                    selectedPhotoItems = []
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        refreshLogs()
                    }
                }
            }
        }
        .onChange(of: selectedVideoItems) { _, newItems in
            Task {
                for item in newItems {
                    if let movie = try? await item.loadTransferable(type: Movie.self) {
                        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let permanentURL = documentsPath
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension("mov")
                        
                        do {
                            try FileManager.default.copyItem(at: movie.url, to: permanentURL)
                            
                            let asset = AVAsset(url: permanentURL)
                            let duration = try await asset.load(.duration).seconds
                            let thumbnail = Self.generateThumbnail(for: permanentURL)
                            
                            let log = LogEntry(type: .video, videoURL: permanentURL, duration: duration)
                            log.thumbnailData = thumbnail
                            log.project = project
                            log.isProcessed = false
                            
                            modelContext.insert(log)
                            
                            VideoProcessor.processVideo(at: permanentURL) { frames in
                                log.extractedFrames = frames
                                log.isProcessed = true
                                
                                do {
                                    try modelContext.save()
                                    print("✅ Imported video processed: \(frames.count) frames")
                                } catch {
                                    print("❌ Error saving processed frames: \(error)")
                                }
                            }
                        } catch {
                            print("❌ Error importing video: \(error)")
                        }
                    }
                }
                
                await MainActor.run {
                    selectedVideoItems = []
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        refreshLogs()
                    }
                }
            }
        }
        .onAppear {
            refreshLogs()
        }
        .sheet(isPresented: $showingReportGenerator) {
            ReportGeneratorView(project: project, logs: todaysLogsCache)
        }
        .sheet(isPresented: $showingContractUpload) {
            ContractUploadView(project: project)
        }
        .sheet(isPresented: $showingScheduleUpload) {
            ScheduleUploadView(project: project)
        }
    }
    
    func refreshLogs() {
        todaysLogsCache = todaysLogs
    }
    
    static func generateThumbnail(for videoURL: URL) -> Data? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            return image.jpegData(compressionQuality: 0.7)
        } catch {
            print("Error generating thumbnail: \(error)")
            return nil
        }
    }
}

// MARK: - Movie Transferable
struct Movie: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL.temporaryDirectory.appending(path: "movie.mov")
            if FileManager.default.fileExists(atPath: copy.path()) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

// MARK: - Empty Logs View
struct EmptyLogsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 70))
                .foregroundStyle(.gray)
            
            Text("No Logs Today")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap + to add photos or videos\nthroughout the day")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.fill")
                        .foregroundStyle(.blue)
                    Text("Add photos from your camera roll")
                        .font(.caption)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "video.fill")
                        .foregroundStyle(.blue)
                    Text("Add videos from your camera roll")
                        .font(.caption)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "video.badge.plus")
                        .foregroundStyle(.blue)
                    Text("Record 60-second site videos")
                        .font(.caption)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.blue)
                    Text("Generate daily report at end of day")
                        .font(.caption)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Logs List
struct LogsListView: View {
    let logs: [LogEntry]
    let onDelete: () -> Void
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List {
            ForEach(logs) { log in
                LogCardView(log: log, onDelete: onDelete)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteLog(log)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    func deleteLog(_ log: LogEntry) {
        modelContext.delete(log)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onDelete()
        }
    }
}

// MARK: - Log Card
struct LogCardView: View {
    let log: LogEntry
    let onDelete: () -> Void
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    if let photoData = log.photoData,
                       let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay {
                                Image(systemName: log.type == .video ? "video.fill" : "photo.fill")
                                    .foregroundStyle(.gray)
                            }
                    }
                    
                    if log.type == .video {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: log.type == .video ? "video.fill" : "photo")
                            .font(.caption)
                        Text(log.type == .video ? "Video Log" : "Photo Log")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    
                    Text(log.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if log.type == .video && !log.isProcessed {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Processing frames...")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    if let duration = log.duration {
                        Text("\(Int(duration))s")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .cornerRadius(6)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showingDetail) {
            LogDetailView(log: log, onDelete: onDelete)
        }
    }
}
