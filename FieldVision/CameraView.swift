//
//  CameraView.swift
//  FieldVision
//
//  Created by Steven Fernandez on 10/11/25.
//

import SwiftUI
import AVFoundation

struct CameraView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var camera = CameraModel()
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    
    let maxRecordingTime: TimeInterval = 60
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Top Bar
                HStack {
                    Button {
                        stopRecording()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                    }
                    
                    Spacer()
                    
                    // Recording Timer
                    if isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(.red)
                                .frame(width: 12, height: 12)
                            
                            Text(timeString(from: recordingTime))
                                .font(.headline)
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding()
                
                Spacer()
                
                // Recording Controls
                VStack(spacing: 20) {
                    // Time remaining
                    if isRecording {
                        Text("\(Int(maxRecordingTime - recordingTime))s remaining")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    } else {
                        Text("Tap to record (max 60s)")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                    }
                    
                    // Record Button
                    Button {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(.white, lineWidth: 4)
                                .frame(width: 80, height: 80)
                            
                            if isRecording {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.red)
                                    .frame(width: 32, height: 32)
                            } else {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 64, height: 64)
                            }
                        }
                    }
                    .disabled(camera.isProcessing)
                }
                .padding(.bottom, 40)
            }
            
            // Processing overlay
            if camera.isProcessing {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    Text("Saving video...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
        }
        .onAppear {
            camera.checkPermissions()
        }
        .onDisappear {
            stopRecording()
            camera.stopSession()
        }
    }
    
    private func startRecording() {
        camera.startRecording()
        isRecording = true
        recordingTime = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
            
            // Auto-stop at max time
            if recordingTime >= maxRecordingTime {
                stopRecording()
            }
        }
    }
    
    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        
        guard isRecording else { return }
        isRecording = false
        
        #if targetEnvironment(simulator)
        // Simulator mock mode - create a dummy log
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let log = LogEntry(type: .video, duration: recordingTime)
            log.project = project
            modelContext.insert(log)
            dismiss()
        }
        #else
        // Real device - actual recording
        camera.stopRecording { url in
            guard let url = url else { return }
            saveVideoLog(url: url, duration: recordingTime)
            DispatchQueue.main.async {
                dismiss()
            }
        }
        #endif
    }
    
    private func saveVideoLog(url: URL, duration: TimeInterval) {
        // Generate thumbnail
        let thumbnail = generateThumbnail(for: url)
        
        let log = LogEntry(type: .video, videoURL: url, duration: duration)
        log.thumbnailData = thumbnail
        log.project = project
        log.isProcessed = false // Mark as not processed yet
        
        modelContext.insert(log)
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving video log: \(error)")
        }
        
        // Process frames in background
        VideoProcessor.processVideo(at: url) { frames in
            log.extractedFrames = frames
            log.isProcessed = true
            
            do {
                try modelContext.save()
                print("✅ Video processed: \(frames.count) frames extracted")
            } catch {
                print("Error saving processed frames: \(error)")
            }
        }
    }
    
    private func generateThumbnail(for videoURL: URL) -> Data? {
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
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        let tenths = Int((timeInterval.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }
}

// MARK: - Camera Preview
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        context.coordinator.previewLayer = previewLayer
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = context.coordinator.previewLayer {
            DispatchQueue.main.async {
                previewLayer.frame = uiView.bounds
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Camera Model
class CameraModel: NSObject, ObservableObject {
    @Published var isProcessing = false
    
    let session = AVCaptureSession()
    private var videoOutput: AVCaptureMovieFileOutput?
    private var recordingCompletion: ((URL?) -> Void)?
    
    override init() {
        super.init()
        setupCamera()
    }
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.startSession()
                }
            }
        default:
            break
        }
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            return
        }
        
        session.addInput(videoInput)
        
        // Add video output
        let output = AVCaptureMovieFileOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            videoOutput = output
        }
        
        session.commitConfiguration()
    }
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }
    
    func startRecording() {
        guard let videoOutput = videoOutput else { return }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")
        
        videoOutput.startRecording(to: tempURL, recordingDelegate: self)
    }
    
    func stopRecording(completion: @escaping (URL?) -> Void) {
        recordingCompletion = completion
        videoOutput?.stopRecording()
        isProcessing = true
    }
}

// MARK: - Recording Delegate
extension CameraModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        DispatchQueue.main.async { [weak self] in
            self?.isProcessing = false
            
            if let error = error {
                print("Recording error: \(error)")
                self?.recordingCompletion?(nil)
            } else {
                // Move to permanent location
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let permanentURL = documentsPath
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
                
                do {
                    try FileManager.default.moveItem(at: outputFileURL, to: permanentURL)
                    self?.recordingCompletion?(permanentURL)
                } catch {
                    print("Error moving file: \(error)")
                    self?.recordingCompletion?(nil)
                }
            }
        }
    }
}
