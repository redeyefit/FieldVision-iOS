//
//  Models.swift
//  FieldVision
//
//  Created by Steven Fernandez on 10/10/25.
//

import Foundation
import SwiftData

// MARK: - Project Model
@Model
final class Project {
    var id: UUID
    var name: String
    var address: String
    var clientName: String
    var createdDate: Date
    var isActive: Bool
    
    // Contract and baseline information
    var existingConditions: String
    var scopeOfWork: String
    var contractPDFData: Data?

    // Schedule information
    var schedulePDFData: Data?

    // Residential code compliance
    var jurisdiction: String
    var dwellingType: String
    var codeRequirements: String

    // Store baseline photos as concatenated Data with separator
    private var baselinePhotoDataBlob: Data?

    @Relationship(deleteRule: .cascade)
    var logs: [LogEntry]

    @Relationship(deleteRule: .cascade)
    var reports: [DailyReport]

    @Relationship(deleteRule: .cascade)
    var schedule: [ScheduleActivity]

    init(name: String, address: String, clientName: String, existingConditions: String = "", scopeOfWork: String = "") {
        self.id = UUID()
        self.name = name
        self.address = address
        self.clientName = clientName
        self.createdDate = Date()
        self.isActive = true
        self.existingConditions = existingConditions
        self.scopeOfWork = scopeOfWork
        self.contractPDFData = nil
        self.schedulePDFData = nil
        self.jurisdiction = ""
        self.dwellingType = ""
        self.codeRequirements = ""
        self.baselinePhotoDataBlob = nil
        self.logs = []
        self.reports = []
        self.schedule = []
    }
}

// MARK: - Project Extensions
extension Project {
    // Computed property for baseline photos array
    var baselinePhotoData: [Data] {
        get {
            guard let blob = baselinePhotoDataBlob, !blob.isEmpty else { return [] }
            let separator = "|||PHOTODATA|||".data(using: .utf8)!
            var photos: [Data] = []
            var currentData = blob
            
            while !currentData.isEmpty {
                if let range = currentData.range(of: separator) {
                    photos.append(currentData[..<range.lowerBound])
                    currentData = currentData[range.upperBound...]
                } else {
                    photos.append(currentData)
                    break
                }
            }
            return photos
        }
        set {
            guard !newValue.isEmpty else {
                baselinePhotoDataBlob = nil
                return
            }
            let separator = "|||PHOTODATA|||".data(using: .utf8)!
            var blob = Data()
            for (index, photoData) in newValue.enumerated() {
                blob.append(photoData)
                if index < newValue.count - 1 {
                    blob.append(separator)
                }
            }
            baselinePhotoDataBlob = blob
        }
    }
    
    func getRecentReports(days: Int = 7) -> [DailyReport] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return reports
            .filter { $0.date >= startDate && $0.date < Date() }
            .sorted { $0.date < $1.date }
    }
    
    func getYesterdaysReport() -> DailyReport? {
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else {
            return nil
        }
        
        return reports.first { calendar.isDate($0.date, inSameDayAs: yesterday) }
    }
}

// MARK: - Log Entry Model
@Model
final class LogEntry {
    var id: UUID
    var timestamp: Date
    var type: LogType
    var duration: Double?
    var videoURL: URL?
    var photoData: Data?
    var thumbnailData: Data?
    var isProcessed: Bool
    var notes: String?
    
    @Relationship(inverse: \Project.logs)
    var project: Project?
    
    // Store frames as concatenated Data with separator
    private var extractedFramesBlob: Data?
    var aiAnalysis: String?
    
    init(type: LogType, videoURL: URL? = nil, photoData: Data? = nil, duration: Double? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.videoURL = videoURL
        self.photoData = photoData
        self.duration = duration
        self.isProcessed = false
        self.extractedFramesBlob = nil
        self.aiAnalysis = nil
    }
}

// MARK: - Log Entry Extensions
extension LogEntry {
    var extractedFrames: [Data]? {
        get {
            guard let blob = extractedFramesBlob, !blob.isEmpty else { return nil }
            let separator = "|||FRAMEDATA|||".data(using: .utf8)!
            var frames: [Data] = []
            var currentData = blob
            
            while !currentData.isEmpty {
                if let range = currentData.range(of: separator) {
                    frames.append(currentData[..<range.lowerBound])
                    currentData = currentData[range.upperBound...]
                } else {
                    frames.append(currentData)
                    break
                }
            }
            return frames.isEmpty ? nil : frames
        }
        set {
            guard let frames = newValue, !frames.isEmpty else {
                extractedFramesBlob = nil
                return
            }
            let separator = "|||FRAMEDATA|||".data(using: .utf8)!
            var blob = Data()
            for (index, frameData) in frames.enumerated() {
                blob.append(frameData)
                if index < frames.count - 1 {
                    blob.append(separator)
                }
            }
            extractedFramesBlob = blob
        }
    }
}

enum LogType: String, Codable {
    case video
    case photo
}

enum ActivityStatus: String, Codable {
    case notStarted
    case inProgress
    case completed
    case overdue
}

// MARK: - Daily Report Model
@Model
final class DailyReport {
    var id: UUID
    var date: Date
    var createdDate: Date
    var projectName: String
    var projectAddress: String
    var workStatus: String
    var inspections: String
    var pendingChangeOrders: String
    var scheduleForWeek: String
    var weatherCondition: String
    var temperature: String
    var wind: String
    var humidity: String
    var precipitation: String
    var addedBy: String
    var pdfURL: URL?
    
    @Relationship(inverse: \Project.reports)
    var project: Project?
    
    var aiContext: String?
    var progressMetrics: String?
    var openItems: String?
    var commitments: String?
    
    init(date: Date, projectName: String, projectAddress: String, addedBy: String) {
        self.id = UUID()
        self.date = date
        self.createdDate = Date()
        self.projectName = projectName
        self.projectAddress = projectAddress
        self.addedBy = addedBy
        self.workStatus = ""
        self.inspections = ""
        self.pendingChangeOrders = ""
        self.scheduleForWeek = ""
        self.weatherCondition = ""
        self.temperature = ""
        self.wind = ""
        self.humidity = ""
        self.precipitation = ""
        self.aiContext = nil
        self.progressMetrics = nil
        self.openItems = nil
        self.commitments = nil
    }
}

// MARK: - Daily Report Extensions
extension DailyReport {
    var openItemsList: [String] {
        get {
            guard let items = openItems, !items.isEmpty else { return [] }
            return items.components(separatedBy: "|||")
        }
        set {
            openItems = newValue.joined(separator: "|||")
        }
    }
    
    var commitmentsList: [String] {
        get {
            guard let commits = commitments, !commits.isEmpty else { return [] }
            return commits.components(separatedBy: "|||")
        }
        set {
            commitments = newValue.joined(separator: "|||")
        }
    }
    
    var metrics: [String: Double] {
        get {
            guard let metricsString = progressMetrics,
                  let data = metricsString.data(using: .utf8),
                  let dict = try? JSONDecoder().decode([String: Double].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let string = String(data: data, encoding: .utf8) {
                progressMetrics = string
            }
        }
    }
}

// MARK: - User Settings Model
@Model
final class UserSettings {
    var userName: String
    var companyName: String
    var licenseNumber: String
    var anthropicKey: String?
    var weatherAPIKey: String?

    init(userName: String = "", companyName: String = "", licenseNumber: String = "") {
        self.userName = userName
        self.companyName = companyName
        self.licenseNumber = licenseNumber
    }
}

// MARK: - Schedule Activity Model
@Model
final class ScheduleActivity {
    var id: UUID
    var activityName: String
    var trade: String
    var startDate: Date
    var duration: Int
    var isComplete: Bool
    var notes: String?

    @Relationship(inverse: \Project.schedule)
    var project: Project?

    init(
        activityName: String,
        trade: String,
        startDate: Date,
        duration: Int,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.activityName = activityName
        self.trade = trade
        self.startDate = startDate
        self.duration = duration
        self.isComplete = false
        self.notes = notes
    }
}

// MARK: - Schedule Activity Extensions
extension ScheduleActivity {
    // Computed end date based on start + duration (workdays)
    var endDate: Date {
        let calendar = Calendar.current
        var workdaysAdded = 0
        var currentDate = startDate

        while workdaysAdded < duration {
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            // Skip weekends (Saturday = 7, Sunday = 1 in Calendar)
            let weekday = calendar.component(.weekday, from: currentDate)
            if weekday != 1 && weekday != 7 {
                workdaysAdded += 1
            }
        }

        return currentDate
    }

    // Computed status based on dates and completion
    var status: ActivityStatus {
        let today = Calendar.current.startOfDay(for: Date())
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)

        if isComplete {
            return .completed
        } else if today < start {
            return .notStarted
        } else if today > end {
            return .overdue
        } else {
            return .inProgress
        }
    }
}

// MARK: - Construction Analysis Result
struct ConstructionAnalysis {
    let workStatus: String
    let observations: String
    let notableItems: String
}
