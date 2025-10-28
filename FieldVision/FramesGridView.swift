//
//  FramesGridView.swift
//  FieldVision
//
//  View extracted frames from video logs
//

import SwiftUI

struct FramesGridView: View {
    let log: LogEntry
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFrame: Data?
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let frames = log.extractedFrames, !frames.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(Array(frames.enumerated()), id: \.offset) { index, frameData in
                                FrameThumbnailView(
                                    frameData: frameData,
                                    index: index,
                                    onTap: { selectedFrame = frameData }
                                )
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 20) {
                        if log.isProcessed {
                            Image(systemName: "photo.stack")
                                .font(.system(size: 60))
                                .foregroundStyle(.gray)
                            
                            Text("No Frames Extracted")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("This video didn't produce any valid frames")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Processing video...")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.top)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Extracted Frames")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if let frames = log.extractedFrames {
                    ToolbarItem(placement: .primaryAction) {
                        Text("\(frames.count) frames")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .sheet(item: Binding(
                get: { selectedFrame.map { FrameWrapper(data: $0) } },
                set: { selectedFrame = $0?.data }
            )) { wrapper in
                FullScreenFrameView(frameData: wrapper.data)
            }
        }
    }
}

// MARK: - Frame Thumbnail
struct FrameThumbnailView: View {
    let frameData: Data
    let index: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                if let uiImage = UIImage(data: frameData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 120)
                }
                
                // Frame number badge
                Text("#\(index + 1)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.6))
                    .cornerRadius(6)
                    .padding(8)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Full Screen Frame View
struct FullScreenFrameView: View {
    let frameData: Data
    @Environment(\.dismiss) private var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
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
                }
                .padding()
                
                Spacer()
                
                if let uiImage = UIImage(data: frameData) {
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
            }
        }
    }
}

// MARK: - Helper Wrapper
struct FrameWrapper: Identifiable {
    let id = UUID()
    let data: Data
}

#Preview {
    FramesGridView(log: LogEntry(type: .video))
}
