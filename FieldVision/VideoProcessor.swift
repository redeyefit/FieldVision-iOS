//
//  VideoProcessor.swift
//  FieldVision
//
//  Frame extraction and quality filtering
//

import Foundation
import AVFoundation
import UIKit
import Accelerate

class VideoProcessor {
    
    // MARK: - Main Processing Function
    static func processVideo(at url: URL, completion: @escaping ([Data]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Step 1: Extract frames (1 per second)
            let allFrames = extractFrames(from: url, fps: 1.0)
            print("📹 Extracted \(allFrames.count) frames from video")
            
            guard !allFrames.isEmpty else {
                print("❌ No frames extracted")
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            // Step 2: Filter blurry frames (more lenient threshold)
            let sharpFrames = filterBlurryFrames(allFrames, threshold: 13.0)
            print("🔍 Kept \(sharpFrames.count) sharp frames after blur detection")
            
            // If blur filter removed everything, use original frames
            let framesToProcess = sharpFrames.isEmpty ? allFrames : sharpFrames
            print("📊 Processing \(framesToProcess.count) frames")
            
            // Step 3: Remove duplicates (more lenient similarity)
            let uniqueFrames = removeDuplicates(framesToProcess, threshold: 0.90)
            print("✨ Kept \(uniqueFrames.count) unique frames after duplicate removal")
            
            // Step 4: Keep best 20 frames (or all if less)
            let finalFrames = Array(uniqueFrames.prefix(20))
            print("✅ Final frame count: \(finalFrames.count)")
            
            // Convert to Data for storage
            let frameData = finalFrames.compactMap { $0.jpegData(compressionQuality: 0.8) }
            
            DispatchQueue.main.async {
                completion(frameData)
            }
        }
    }
    // MARK: - Frame Extraction
    private static func extractFrames(from videoURL: URL, fps: Double) -> [UIImage] {
        let asset = AVURLAsset(url: videoURL)
        let duration = asset.duration.seconds
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        var frames: [UIImage] = []
        let interval = 1.0 / fps // 1 frame per second
        
        for time in stride(from: 0.0, to: duration, by: interval) {
            let cmTime = CMTime(seconds: time, preferredTimescale: 600)
            
            do {
                let cgImage = try generator.copyCGImage(at: cmTime, actualTime: nil)
                let image = UIImage(cgImage: cgImage)
                frames.append(image)
            } catch {
                print("Error extracting frame at \(time)s: \(error)")
            }
        }
        
        return frames
    }
    
    // MARK: - Blur Detection
    private static func filterBlurryFrames(_ frames: [UIImage], threshold: Double = 10.0) -> [UIImage] {        return frames.filter { image in
            let blurScore = calculateBlurScore(image)
            return blurScore > threshold
        }
    }
    
    private static func calculateBlurScore(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0 }
        
        // Convert to grayscale
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return 0 }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height)
        
        // Calculate Laplacian variance (blur metric)
        var variance: Double = 0
        var mean: Double = 0
        var count = 0
        
        // Simple Laplacian kernel approximation
        for y in 1..<(height-1) {
            for x in 1..<(width-1) {
                let index = y * width + x
                let center = Double(pixels[index])
                let top = Double(pixels[(y-1) * width + x])
                let bottom = Double(pixels[(y+1) * width + x])
                let left = Double(pixels[y * width + (x-1)])
                let right = Double(pixels[y * width + (x+1)])
                
                let laplacian = abs(4 * center - top - bottom - left - right)
                mean += laplacian
                count += 1
            }
        }
        
        mean /= Double(count)
        
        // Calculate variance
        for y in 1..<(height-1) {
            for x in 1..<(width-1) {
                let index = y * width + x
                let center = Double(pixels[index])
                let top = Double(pixels[(y-1) * width + x])
                let bottom = Double(pixels[(y+1) * width + x])
                let left = Double(pixels[y * width + (x-1)])
                let right = Double(pixels[y * width + (x+1)])
                
                let laplacian = abs(4 * center - top - bottom - left - right)
                variance += pow(laplacian - mean, 2)
            }
        }
        
        variance /= Double(count)
        
        return variance
    }
    
    // MARK: - Duplicate Detection
    private static func removeDuplicates(_ frames: [UIImage], threshold: Double = 0.95) -> [UIImage] {
        guard !frames.isEmpty else { return [] }
        
        var uniqueFrames: [UIImage] = [frames[0]]
        var previousHash = perceptualHash(frames[0])
        
        for i in 1..<frames.count {
            let currentHash = perceptualHash(frames[i])
            let similarity = hashSimilarity(previousHash, currentHash)
            
            // If not too similar to previous, keep it
            if similarity < threshold {
                uniqueFrames.append(frames[i])
                previousHash = currentHash
            }
        }
        
        return uniqueFrames
    }
    
    // MARK: - Perceptual Hashing
    private static func perceptualHash(_ image: UIImage) -> [Double] {
        // Resize to small size for comparison
        let size = CGSize(width: 8, height: 8)
        
        guard let resized = resizeImage(image, to: size),
              let cgImage = resized.cgImage else {
            return Array(repeating: 0, count: 64)
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return Array(repeating: 0, count: 64)
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else {
            return Array(repeating: 0, count: 64)
        }
        
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height)
        
        // Calculate average
        var sum = 0.0
        for i in 0..<(width * height) {
            sum += Double(pixels[i])
        }
        let average = sum / Double(width * height)
        
        // Create hash
        var hash: [Double] = []
        for i in 0..<(width * height) {
            hash.append(Double(pixels[i]) > average ? 1.0 : 0.0)
        }
        
        return hash
    }
    
    private static func hashSimilarity(_ hash1: [Double], _ hash2: [Double]) -> Double {
        guard hash1.count == hash2.count else { return 0 }
        
        let matching = zip(hash1, hash2).filter { $0 == $1 }.count
        return Double(matching) / Double(hash1.count)
    }
    
    // MARK: - Helper Functions
    private static func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
