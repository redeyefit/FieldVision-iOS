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

        // DEBUG: Log context being passed
        print("\n🔍 ═══════════════════════════════════════════════════════")
        print("🔍 DEBUG: AI Request Context Details")
        print("🔍 ═══════════════════════════════════════════════════════")
        print("📋 Existing Conditions: \(existingConditions?.isEmpty == false ? "\(existingConditions!.count) chars" : "EMPTY")")
        print("📋 Scope of Work: \(scopeOfWork?.isEmpty == false ? "\(scopeOfWork!.count) chars" : "EMPTY")")
        print("📅 Schedule activities: \(schedule.count)")
        print("📊 Previous reports: \(previousReports.count)")
        print("📸 Total frames: \(frames.count)")
        print("📸 Baseline photos: \(baselinePhotos?.count ?? 0)")

        // Print first 200 chars of scope to verify it's being passed
        if let scopeOfWork = scopeOfWork, !scopeOfWork.isEmpty {
            let preview = String(scopeOfWork.prefix(200))
            print("\n📄 Scope of Work Preview:")
            print("   \(preview)...")
        } else {
            print("\n⚠️ NO SCOPE OF WORK PROVIDED")
        }

        // Print first 200 chars of existing conditions
        if let existingConditions = existingConditions, !existingConditions.isEmpty {
            let preview = String(existingConditions.prefix(200))
            print("\n📄 Existing Conditions Preview:")
            print("   \(preview)...")
        } else {
            print("\n⚠️ NO EXISTING CONDITIONS PROVIDED")
        }

        // Build the prompt with history and project context
        let prompt = constructionPrompt(
            projectName: projectName,
            date: date,
            previousReports: previousReports,
            existingConditions: existingConditions,
            scopeOfWork: scopeOfWork,
            schedule: schedule
        )

        // DEBUG: Print the FULL prompt being sent (first 1500 chars)
        print("\n📤 ═══════════════════════════════════════════════════════")
        print("📤 FULL PROMPT PREVIEW (first 1500 chars):")
        print("📤 ═══════════════════════════════════════════════════════")
        print(String(prompt.prefix(1500)))
        print("📤 ...")
        print("📤 [Total prompt length: \(prompt.count) chars]")
        print("📤 ═══════════════════════════════════════════════════════\n")
        
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

        // Build schedule section with EXPLICIT DATE CALCULATIONS
        var scheduleSection = ""
        if !schedule.isEmpty {
            let todayFormatted = today.formatted(date: .abbreviated, time: .omitted)
            scheduleSection = "\n\nPROJECT SCHEDULE:\n"
            scheduleSection += "TODAY'S DATE: \(todayFormatted)\n"

            // Separate activities by status
            var activeActivities: [ScheduleActivity] = []
            var upcomingActivities: [ScheduleActivity] = []
            var recentlyCompleted: [ScheduleActivity] = []
            var overdueActivities: [ScheduleActivity] = []

            for activity in schedule.sorted(by: { $0.startDate < $1.startDate }) {
                let startDay = Calendar.current.startOfDay(for: activity.startDate)
                let endDay = Calendar.current.startOfDay(for: activity.endDate)
                let daysUntilStart = Calendar.current.dateComponents([.day], from: today, to: startDay).day ?? 0

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
                scheduleSection += "\n🔴 ACTIVE NOW (should be in progress today - \(todayFormatted)):\n"
                for activity in activeActivities {
                    let startDay = Calendar.current.startOfDay(for: activity.startDate)
                    let endDay = Calendar.current.startOfDay(for: activity.endDate)

                    // Calculate days into task (from start to today)
                    let daysIntoTask = Calendar.current.dateComponents([.day], from: startDay, to: today).day ?? 0

                    // Calculate days remaining (from today to end) - KEY CALCULATION
                    let daysRemaining = Calendar.current.dateComponents([.day], from: today, to: endDay).day ?? 0

                    let startFormatted = activity.startDate.formatted(date: .abbreviated, time: .omitted)
                    let endFormatted = activity.endDate.formatted(date: .abbreviated, time: .omitted)

                    // Determine schedule status
                    let scheduleStatus: String
                    if today <= endDay {
                        scheduleStatus = "✅ ON SCHEDULE"
                    } else {
                        let daysOverdue = abs(daysRemaining)
                        scheduleStatus = "🔴 BEHIND SCHEDULE - \(daysOverdue) days overdue"
                    }

                    scheduleSection += """

                      Activity: \(activity.activityName) (\(activity.trade))
                      Dates: \(startFormatted) to \(endFormatted) (\(activity.duration) workdays)
                      Status: Today (\(todayFormatted)) is day \(daysIntoTask + 1) of \(activity.duration). \(daysRemaining) days remaining until \(endFormatted).
                      Schedule Status: \(scheduleStatus)

                    """
                }
            }

            // Overdue activities
            if !overdueActivities.isEmpty {
                scheduleSection += "\n⚠️ OVERDUE (should be complete but marked incomplete):\n"
                for activity in overdueActivities {
                    let endDay = Calendar.current.startOfDay(for: activity.endDate)
                    let daysOverdue = Calendar.current.dateComponents([.day], from: endDay, to: today).day ?? 0
                    let endFormatted = activity.endDate.formatted(date: .abbreviated, time: .omitted)

                    scheduleSection += """

                      Activity: \(activity.activityName) (\(activity.trade))
                      Due Date: \(endFormatted)
                      Status: \(daysOverdue) days overdue (was due \(endFormatted), today is \(todayFormatted))

                    """
                }
            }

            // Upcoming activities
            if !upcomingActivities.isEmpty {
                scheduleSection += "\n📅 STARTING SOON (within 7 days):\n"
                for activity in upcomingActivities {
                    let startDay = Calendar.current.startOfDay(for: activity.startDate)
                    let daysUntilStart = Calendar.current.dateComponents([.day], from: today, to: startDay).day ?? 0
                    let startFormatted = activity.startDate.formatted(date: .abbreviated, time: .omitted)
                    let endFormatted = activity.endDate.formatted(date: .abbreviated, time: .omitted)

                    scheduleSection += """

                      Activity: \(activity.activityName) (\(activity.trade))
                      Dates: \(startFormatted) to \(endFormatted) (\(activity.duration) workdays)
                      Status: Starts in \(daysUntilStart) days

                    """
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
        
        // Build the structured prompt with PROJECT CONTEXT first, then TODAY'S ANALYSIS
        return """
        You are an expert construction superintendent analyzing daily progress for \(projectName) on \(dateString).

        ═══════════════════════════════════════════════════════════
        PROJECT CONTEXT
        ═══════════════════════════════════════════════════════════
        \(projectContext.isEmpty ? "\nNo project scope information provided.\n" : projectContext)\(scheduleSection)\(historySection)\(followUpSection)

        ═══════════════════════════════════════════════════════════
        TODAY'S SITE VISIT ANALYSIS - \(dateString)
        ═══════════════════════════════════════════════════════════

        ⚠️ CRITICAL INSTRUCTIONS - PHOTO ACCURACY:

        1. ONLY describe what is DIRECTLY VISIBLE in the provided photos
        2. DO NOT invent, assume, or extrapolate details not clearly visible in images
        3. If you cannot verify something from the photos, explicitly state: "⚠️ Cannot verify from photos"
        4. DO NOT make up structural elements, equipment, or work that isn't clearly visible
        5. Be specific about what IS visible, cautious about what might be present but unclear

        Language Guidelines:
        - Use cautious language: "appears to", "visible work suggests", "observed installation"
        - NEVER state definitively about hidden work, interior conditions, or unseen details
        - If photos don't show enough detail: "Insufficient detail to verify [item]"

        Examples of GOOD vs BAD responses:

        ❌ BAD: "Steel moment frames and structural reinforcement installation complete per specifications"
        ✅ GOOD: "New framing observed with structural support posts visible. ⚠️ Cannot verify full structural details from exterior photos."

        ❌ BAD: "Insulation installation complete and properly installed"
        ✅ GOOD: "Some insulation material visible in wall cavities. ⚠️ Cannot verify installation method or coverage from available photos."

        ❌ BAD: "Electrical rough-in complete with proper wiring"
        ✅ GOOD: "Electrical conduit and boxes visible in open walls. ⚠️ Cannot verify complete wiring without access to all areas."

        ❌ BAD: "Foundation waterproofing and drainage system installed correctly"
        ✅ GOOD: "Foundation walls visible. ⚠️ Waterproofing and drainage systems not visible in photos."

        🔍 GROUNDING ANALYSIS - COMPARE TO PROJECT FACTS:

        Your analysis MUST be grounded in the project context provided above:

        1. **COMPARE to Scope of Work:**
           - Is the visible work part of the defined scope?
           - Are workers doing work that's IN SCOPE or something different?
           - Don't describe work that's not part of the scope (unless it's a concern)

        2. **COMPARE to Schedule - CRITICAL DATE LOGIC:**
           - Read the "DAYS REMAINING" number in the schedule section
           - If "days remaining" is POSITIVE (e.g., 5 days remaining): Activity is ON SCHEDULE ✅
           - If "days remaining" is NEGATIVE (e.g., -3 days remaining): Activity is BEHIND SCHEDULE 🔴
           - The schedule section shows "Schedule Status: ✅ ON SCHEDULE" or "🔴 BEHIND SCHEDULE"
           - TRUST THE SCHEDULE STATUS PROVIDED - do not recalculate dates yourself
           - Are the right activities happening? If framing is scheduled but you see plumbing: 🔴 SCHEDULE DEVIATION
           - Assess progress percentage based on days into task vs total duration

        3. **COMPARE to Previous Visit:**
           - What CHANGED since the last report?
           - Were open items from yesterday addressed?
           - Did promised work actually happen?
           - Is progress accelerating, steady, or slowing?

        4. **COMPARE to Existing Conditions:**
           - Distinguish between EXISTING work (was already there) vs NEW work (this project)
           - Don't report existing conditions as new progress

        If project context is missing (no scope/schedule): acknowledge this and describe what's visible without making assumptions about correctness.

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

        CRITICAL: Use the "Schedule Status" from the PROJECT SCHEDULE section above.
        Each activity shows "✅ ON SCHEDULE" or "🔴 BEHIND SCHEDULE" - TRUST THESE.

        For each ACTIVE activity, report:
        1. Activity name and trade
        2. Copy the dates and status from PROJECT SCHEDULE section
        3. Days remaining (from schedule section above)
        4. Actual work observed in photos
        5. Alignment: Does visible work match the scheduled activity?

        Examples:

        ✅ ON SCHEDULE Example:
        - Framing (Rough Framing): Oct 1 - Oct 15
          Schedule: Day 5 of 15, 10 days remaining. ✅ ON SCHEDULE
          Observed: Wall framing in progress, studs being installed on first floor
          Assessment: 🟢 Work aligns with schedule, progressing as planned

        🔴 BEHIND SCHEDULE Example:
        - Electrical (Electrical): Oct 1 - Oct 10
          Schedule: Day 12 of 10, -2 days remaining. 🔴 BEHIND SCHEDULE - 2 days overdue
          Observed: Electrical rough-in still in progress, conduit installation ongoing
          Assessment: 🔴 Activity is overdue. Recommend expediting to prevent downstream delays.

        ⚠️ DEVIATION Example:
        - Plumbing (Plumbing): Oct 15 - Oct 22, starts in 7 days
          Schedule: Not yet scheduled to start
          Observed: ⚠️ Plumbing work already in progress (early start)
          Assessment: 🟡 Activity started ahead of schedule - verify this doesn't conflict with other trades

        For OVERDUE activities:
        - State how many days overdue (from schedule section)
        - Assess whether work is being expedited or falling further behind

        For NOT STARTED activities:
        - If photos show NO work for scheduled activity: ⚠️ Not Started - behind schedule
        - Note any obstacles visible in photos
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
