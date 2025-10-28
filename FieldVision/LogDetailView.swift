//
//  LogDetailView.swift
//  FieldVision
//
//  Created by Steven Fernandez on 10/10/25.
//

import SwiftUI
import SwiftData
import AVKit

struct LogDetailView: View {
    @Bindable var log: LogEntry
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showingDeleteAlert = false
    @State private var showingFramesView = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    
                    Spacer()
                    
                    Menu {
                        // View Frames for videos
                        if log.type == .video {
                            Button {
                                showingFramesView = true
                            } label: {
                                Label("View Frames", systemImage: "photo.stack")
                            }
                            .disabled(log.extractedFrames?.isEmpty ?? true)
                            
                            Divider()
                        }
                        
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete Log", systemImage: "trash")
                        }
                        
                        if let photoData = log.photoData,
                           let uiImage = UIImage(data: photoData) {
                            ShareLink(item: Image(uiImage: uiImage), preview: SharePreview("Photo Log")) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                }
                .padding()
                
                Spacer()
                
                // Media Display
                if log.type == .video, let videoURL = log.videoURL {
                    // Video Player - Full Screen
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                } else if let photoData = log.photoData,
                          let uiImage = UIImage(data: photoData) {
                    // Photo with zoom/pan
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    scale *= delta
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                }
                
                Spacer()
                
                // Info Bar
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: log.type == .video ? "video.fill" : "photo")
                        Text(log.type == .video ? "Video Log" : "Photo Log")
                            .font(.headline)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                        Spacer()
                    }
                    
                    if let notes = log.notes, !notes.isEmpty {
                        HStack {
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
                .foregroundStyle(.white)
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .sheet(isPresented: $showingFramesView) {
            FramesGridView(log: log)
        }
        .alert("Delete Log", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteLog()
            }
        } message: {
            Text("Are you sure you want to delete this log? This action cannot be undone.")
        }
    }
    
    private func deleteLog() {
        modelContext.delete(log)
        dismiss()
        
        // Trigger immediate refresh in parent
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onDelete()
        }
    }
}
