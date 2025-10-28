//
//  AnthropicService.swift
//  FieldVision
//
//  Anthropic Claude integration for construction analysis
//

import Foundation
import UIKit

class AnthropicService {
    
    // MARK: - Configuration
    private let apiKey: String
    private let endpoint = "https://api.anthropic.com/v1/messages"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // MARK: - Main Analysis Function
    func analyzeConstructionSite(
        frames: [Data],
        projectName: String,
        date: Date,
        previousReports: [DailyReport] = [],
        existingConditions: String? = nil,
        scopeOfWork: String? = nil,
        baselinePhotos: [Data]? = nil,
        schedule: [ScheduleActivity] = [],
        completion: @escaping (Result<ConstructionAnalysis, Error>) -> Void
    ) {
        // Compress and encode images
        var compressedImages: [String] = []
        for data in frames {
            guard let image = UIImage(data: data) else { continue }
            
            // Resize to max 1024px on longest side
            let resized = resizeImage(image, maxDimension: 1024)
            
            // Compress to ~100-200KB
            guard let compressed = resized.jpegData(compressionQuality: 0.6) else { continue }
            
            let sizeKB = compressed.count / 1024
            print("📦 Compressed image: \(sizeKB)KB")
            
            compressedImages.append(compressed.base64EncodedString())
        }
        
        guard !compressedImages.isEmpty else {
            completion(.failure(NSError(domain: "AnthropicService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No frames to analyze"])))
            return
        }
        
        print("📤 Sending \(compressedImages.count) images to Claude")
        print("📊 Total payload size: \(compressedImages.reduce(0) { $0 + $1.count } / 1024)KB")
        
        // Build the prompt with history and project context
        let prompt = constructionPrompt(
            projectName: projectName,
            date: date,
            previousReports: previousReports,
            existingConditions: existingConditions,
            scopeOfWork: scopeOfWork,
            schedule: schedule
        )
        
        // Create the request
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build message content with images
        var messageContent: [[String: Any]] = [
            ["type": "text", "text": prompt]
        ]

        // Add baseline photos first (if available)
        if let baselinePhotos = baselinePhotos, !baselinePhotos.isEmpty {
            messageContent.append([
                "type": "text",
                "text": "BASELINE PHOTOS (Before Work Started):"
            ])

            for data in baselinePhotos {
                guard let image = UIImage(data: data) else { continue }
                let resized = resizeImage(image, maxDimension: 1024)
                guard let compressed = resized.jpegData(compressionQuality: 0.6) else { continue }

                messageContent.append([
                    "type": "image",
                    "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": compressed.base64EncodedString()
                    ]
                ])
            }

            messageContent.append([
                "type": "text",
                "text": "TODAY'S SITE PHOTOS:"
            ])
        }

        // Add today's images
        for base64 in compressedImages {
            messageContent.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": base64
                ]
            ])
        }
        
        let payload: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 4000,
            "messages": [
                [
                    "role": "user",
                    "content": messageContent
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        } catch {
            completion(.failure(error))
            return
        }
        
        print("🚀 Sending request to Anthropic API...")
        
        // Make the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "AnthropicService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            // Parse response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    // Check for API error
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        print("❌ Anthropic API Error: \(message)")
                        completion(.failure(NSError(domain: "AnthropicService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Anthropic Error: \(message)"])))
                        return
                    }
                    
                    // Parse successful response
                    if let content = json["content"] as? [[String: Any]],
                       let firstBlock = content.first,
                       let text = firstBlock["text"] as? String {
                        
                        print("✅ Anthropic analysis complete!")
                        print("📝 Response length: \(text.count) characters")
                        
                        let analysis = self.parseAnalysis(content: text)
                        completion(.success(analysis))
                    } else {
                        print("❌ Failed to parse response structure")
                        completion(.failure(NSError(domain: "AnthropicService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])))
                    }
                }
            } catch {
                print("❌ JSON parsing error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // MARK: - Construction Prompt with History
    private func constructionPrompt(
        projectName: String,
        date: Date,
        previousReports: [DailyReport],
        existingConditions: String? = nil,
        scopeOfWork: String? = nil,
        schedule: [ScheduleActivity] = []
    ) -> String {
        let dateString = date.formatted(date: .long, time: .omitted)
        let today = Calendar.current.startOfDay(for: date)

        // Build project context section
        var projectContext = ""
        if let existingConditions = existingConditions, !existingConditions.isEmpty {
            projectContext += "\n\nEXISTING CONDITIONS (What was there BEFORE work started):\n\(existingConditions)\n"
        }

        if let scopeOfWork = scopeOfWork, !scopeOfWork.isEmpty {
            projectContext += "\n\nSCOPE OF WORK (What we're building/changing):\n\(scopeOfWork)\n"
        }

        // Build schedule section
        var scheduleSection = ""
        if !schedule.isEmpty {
            scheduleSection = "\n\nPROJECT SCHEDULE:\n"

            // Separate activities by status
            var activeActivities: [ScheduleActivity] = []
            var upcomingActivities: [ScheduleActivity] = []
            var recentlyCompleted: [ScheduleActivity] = []
            var overdueActivities: [ScheduleActivity] = []

            for activity in schedule.sorted(by: { $0.startDate < $1.startDate }) {
                let startDay = Calendar.current.startOfDay(for: activity.startDate)
                let endDay = Calendar.current.startOfDay(for: activity.endDate)
                let daysUntilStart = Calendar.current.dateComponents([.day], from: today, to: startDay).day ?? 0
                let daysSinceStart = Calendar.current.dateComponents([.day], from: startDay, to: today).day ?? 0

                switch activity.status {
                case .inProgress:
                    activeActivities.append(activity)
                case .notStarted where daysUntilStart <= 7:
                    upcomingActivities.append(activity)
                case .completed where abs(Calendar.current.dateComponents([.day], from: endDay, to: today).day ?? 999) <= 7:
                    recentlyCompleted.append(activity)
                case .overdue:
                    overdueActivities.append(activity)
                default:
                    break
                }
            }

            // Active activities (should be happening NOW)
            if !activeActivities.isEmpty {
                scheduleSection += "\n🔴 ACTIVE NOW (should be in progress today):\n"
                for activity in activeActivities {
                    let startDay = Calendar.current.startOfDay(for: activity.startDate)
                    let daysSinceStart = Calendar.current.dateComponents([.day], from: startDay, to: today).day ?? 0
                    scheduleSection += "  - \(activity.activityName) (\(activity.trade)): \(activity.startDate.formatted(date: .abbreviated, time: .omitted)) - \(activity.endDate.formatted(date: .abbreviated, time: .omitted)) (\(activity.duration) workdays) - Day \(daysSinceStart + 1) of \(activity.duration)\n"
                }
            }

            // Overdue activities
            if !overdueActivities.isEmpty {
                scheduleSection += "\n⚠️ OVERDUE (should be complete but marked incomplete):\n"
                for activity in overdueActivities {
                    scheduleSection += "  - \(activity.activityName) (\(activity.trade)): Due \(activity.endDate.formatted(date: .abbreviated, time: .omitted))\n"
                }
            }

            // Upcoming activities
            if !upcomingActivities.isEmpty {
                scheduleSection += "\n📅 STARTING SOON (within 7 days):\n"
                for activity in upcomingActivities {
                    let daysUntilStart = Calendar.current.dateComponents([.day], from: today, to: Calendar.current.startOfDay(for: activity.startDate)).day ?? 0
                    scheduleSection += "  - \(activity.activityName) (\(activity.trade)): Starts in \(daysUntilStart) days (\(activity.startDate.formatted(date: .abbreviated, time: .omitted)))\n"
                }
            }

            // Recently completed
            if !recentlyCompleted.isEmpty {
                scheduleSection += "\n✅ RECENTLY COMPLETED:\n"
                for activity in recentlyCompleted {
                    scheduleSection += "  - \(activity.activityName) (\(activity.trade)): Completed\n"
                }
            }
        }

        // Build history section
        var historySection = ""
        if !previousReports.isEmpty {
            historySection = "\n\nRECENT PROJECT HISTORY:\n"

            for report in previousReports.suffix(5) {
                let reportDate = report.date.formatted(date: .abbreviated, time: .omitted)
                let summary = report.aiContext ?? String(report.workStatus.prefix(300))

                historySection += """

                \(reportDate):
                \(summary)
                """

                if !report.openItemsList.isEmpty {
                    historySection += "\nOpen Items: \(report.openItemsList.joined(separator: "; "))"
                }

                if !report.commitmentsList.isEmpty {
                    historySection += "\nCommitments: \(report.commitmentsList.joined(separator: "; "))"
                }

                historySection += "\n"
            }
        }
        
        // Build yesterday's follow-up section
        var followUpSection = ""
        if let yesterday = previousReports.last {
            let hasOpenItems = !yesterday.openItemsList.isEmpty
            let hasCommitments = !yesterday.commitmentsList.isEmpty
            
            if hasOpenItems || hasCommitments {
                followUpSection = "\n\nITEMS TO FOLLOW UP FROM YESTERDAY:\n"
                
                if hasOpenItems {
                    followUpSection += "\nOpen Items:\n"
                    for item in yesterday.openItemsList {
                        followUpSection += "- \(item)\n"
                    }
                }
                
                if hasCommitments {
                    followUpSection += "\nCommitments to Verify:\n"
                    for commitment in yesterday.commitmentsList {
                        followUpSection += "- \(commitment)\n"
                    }
                }
            }
        }
        
        let contextInstruction = projectContext.isEmpty ? "" : """

        IMPORTANT: Use the project context to distinguish between:
        - EXISTING work (what was already there before this project started)
        - NEW work (construction/changes being performed as part of this project)
        Only report on progress related to the NEW work defined in the scope.
        """

        let scheduleInstructions = scheduleSection.isEmpty ? "" : """

        SCHEDULE COMPLIANCE ANALYSIS:
        For each activity that should be ACTIVE NOW or OVERDUE:
        - Check if photos show work matching the scheduled activity
        - If activity is scheduled but NO matching work visible: ⚠️ BEHIND SCHEDULE
        - If activity is visible and on schedule: ✅ ON SCHEDULE
        - If different work is happening (wrong activity): 🔴 SCHEDULE DEVIATION
        - For active activities, assess if progress matches expected timeline (e.g., Day 1 of 7 should show ~14% complete)

        Include a SCHEDULE COMPLIANCE section in your report showing:
        - Which scheduled activities are visible in photos
        - Any schedule deviations or concerns
        - Whether work matches the expected timeline
        """

        return """
        You are a construction superintendent with memory of recent site visits analyzing daily progress for \(projectName) on \(dateString).
        \(projectContext)\(scheduleSection)\(historySection)\(followUpSection)\(contextInstruction)\(scheduleInstructions)

        Review today's site images and generate a detailed report in this EXACT format:
        
        WORK STATUS:
        For each visible trade/activity, provide:
        - Trade name and description of work completed today
        - Estimated % complete based on visible work
        - If this trade appeared in recent history: compare to previous progress
        - Assessment: 🟢 On Track, 🟡 Minor Concern, 🔴 Issue
        - Location details (e.g., "first floor east wing")
        
        PROGRESS TRACKING:
        - Compare today's observations to recent reports
        - Note pace of progress: is work accelerating, steady, or slowing?
        - Follow up on yesterday's open items: were they addressed?
        - Check commitments from previous reports: did expected work happen?
        - Flag any delays or deviations from stated plans
        \(scheduleSection.isEmpty ? "" : """

        SCHEDULE COMPLIANCE:
        For each activity that should be active today or recently completed, provide:
        - Activity name and trade
        - Scheduled dates (start - end)
        - Progress: "Day X of Y" (e.g., "Day 3 of 7")
        - Expected % complete at this point (based on days elapsed)
        - Actual % complete observed in photos
        - Status: 🟢 On Schedule / 🟡 Minor Delay / 🔴 Behind Schedule / ⚠️ Not Started
        - Detailed explanation of schedule status

        Example format:
        - Demo (Demolition): Sep 30 - Oct 6, Day 3 of 7. Expected 43% complete. Observed: 40% complete. 🟢 On Schedule - proceeding as planned with proper safety protocols.
        - Rough Framing (Framing): Oct 10 - Oct 25, starts in 7 days. Site preparation observed, materials staged. 🟢 Ready to start on schedule.

        For OVERDUE activities:
        - Clearly state how many days overdue
        - Explain visible status and concerns

        For activities NOT STARTED when scheduled:
        - Flag as ⚠️ Not Started
        - Note any visible obstacles or reasons for delay
        """)

        OBSERVATIONS:
        - Materials observed (deliveries, stockpiles, what's on-site)
        - Equipment on site (types of machinery, tools)
        - Active trades (identify workers or contractors visible)
        - Safety observations (PPE, hazards, safety measures)
        - Weather/site conditions
        
        ITEMS TO TRACK:
        List specific items requiring follow-up (format as bullet points):
        - Open issues or concerns
        - Commitments made today
        - Inspections needed or scheduled
        - Deliveries expected
        - Work planned for near future
        
        NOTABLE ITEMS:
        - Significant progress or completions
        - Delays, issues, or concerns requiring attention
        - Quality observations
        
        Be specific about locations and use professional construction terminology.
        """
    }
    
    // MARK: - Parse Analysis
    private func parseAnalysis(content: String) -> ConstructionAnalysis {
        var workStatus = ""
        var observations = ""
        var notableItems = ""
        
        let lines = content.components(separatedBy: .newlines)
        var currentSection = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("WORK STATUS:") {
                currentSection = "work"
                continue
            } else if trimmed.hasPrefix("OBSERVATIONS:") {
                currentSection = "observations"
                continue
            } else if trimmed.hasPrefix("NOTABLE ITEMS:") {
                currentSection = "notable"
                continue
            }
            
            if !trimmed.isEmpty {
                switch currentSection {
                case "work":
                    workStatus += trimmed + "\n"
                case "observations":
                    observations += trimmed + "\n"
                case "notable":
                    notableItems += trimmed + "\n"
                default:
                    workStatus += trimmed + "\n"
                }
            }
        }
        
        if workStatus.isEmpty {
            workStatus = content
        }
        
        return ConstructionAnalysis(
            workStatus: workStatus.trimmingCharacters(in: .whitespacesAndNewlines),
            observations: observations.trimmingCharacters(in: .whitespacesAndNewlines),
            notableItems: notableItems.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    
    // MARK: - Helper: Resize Image
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resized
    }
}
