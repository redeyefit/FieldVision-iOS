//
//  PDFGenerator.swift
//  FieldVision
//
//  PDF generation for daily construction reports
//

import Foundation
import PDFKit
import UIKit

class PDFGenerator {

    // MARK: - Constants
    private static let pageWidth: CGFloat = 612 // 8.5 inches at 72 DPI
    private static let pageHeight: CGFloat = 792 // 11 inches at 72 DPI
    private static let margin: CGFloat = 54 // 0.75 inches
    private static let bottomMargin: CGFloat = 100 // 1.4 inches - increased for footer space
    private static let footerHeight: CGFloat = 60 // Space reserved for footer
    private static let contentWidth: CGFloat = pageWidth - (margin * 2)
    private static let maxY: CGFloat = pageHeight - bottomMargin - footerHeight // Max Y before page break (632pt)

    // MARK: - Main PDF Generation
    static func generatePDF(for report: DailyReport, project: Project, userSettings: UserSettings) -> URL? {
        // Create PDF context
        let pdfMetaData = [
            kCGPDFContextCreator: "FieldVision",
            kCGPDFContextAuthor: userSettings.userName,
            kCGPDFContextTitle: "Daily Report - \(project.name) - \(report.date.formatted(date: .abbreviated, time: .omitted))"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        // Create Documents/DailyReports directory if needed
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Could not access Documents directory")
            return nil
        }

        let reportsDirectory = documentsURL.appendingPathComponent("DailyReports")

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: reportsDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: reportsDirectory, withIntermediateDirectories: true, attributes: nil)
                print("✅ Created DailyReports directory at: \(reportsDirectory.path)")
            } catch {
                print("❌ Error creating DailyReports directory: \(error)")
                return nil
            }
        }

        // Create file URL in Documents/DailyReports
        let fileName = "DailyReport_\(project.name.replacingOccurrences(of: " ", with: "_"))_\(report.date.formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")).pdf"
        let pdfURL = reportsDirectory.appendingPathComponent(fileName)

        // Generate PDF
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        do {
            // Estimate pages based on content length
            let fullText = report.workStatus
            let estimatedHeight = estimateTextHeight(text: fullText, fontSize: 11, bold: false, lineSpacing: 1.2)
            let availableHeightPerPage = maxY - margin
            var totalPages = 1 + Int(estimatedHeight / availableHeightPerPage)

            print("📄 Estimated pages: \(totalPages) (content: \(estimatedHeight)pt, per page: \(availableHeightPerPage)pt)")

            // Render the PDF
            try renderer.writePDF(to: pdfURL) { context in
                var currentY: CGFloat = margin
                var currentPage = 1

                // Helper closure to add a new page
                let addNewPage = {
                    print("📄 Adding new page. Current: \(currentPage), new: \(currentPage + 1)")
                    print("📄 Drawing footer on page \(currentPage) before transitioning...")
                    drawFooter(
                        context: context.cgContext,
                        pageNumber: currentPage,
                        totalPages: totalPages,
                        userSettings: userSettings
                    )
                    context.beginPage()
                    currentPage += 1
                    currentY = margin
                    print("📄 New page \(currentPage) started. Y reset to \(currentY). MaxY is \(maxY)")
                }

                // Start first page
                context.beginPage()
                print("📄 Starting page 1. MaxY is \(maxY)")

                // Draw header (only on first page)
                currentY = drawHeader(
                    context: context.cgContext,
                    y: currentY,
                    report: report,
                    project: project,
                    userSettings: userSettings
                )
                print("📏 After header: Y = \(currentY)")

                currentY += 20

                // Draw entire report content paragraph by paragraph
                print("\n📚 Rendering full report content...")
                print("📏 Starting at Y = \(currentY), maxY = \(maxY), space = \(maxY - currentY)pt")

                currentY = drawTextWithPageBreaks(
                    context: context.cgContext,
                    text: fullText,
                    x: margin,
                    startY: currentY,
                    width: contentWidth,
                    fontSize: 11,
                    bold: false,
                    lineSpacing: 1.2,
                    currentPage: &currentPage,
                    addNewPage: addNewPage
                )

                print("\n✅ All content rendered across \(currentPage) pages!")

                // Update total pages if we used more than estimated
                totalPages = max(totalPages, currentPage)

                // Draw footer on last page
                print("📄 Drawing footer on final page \(currentPage)")
                drawFooter(
                    context: context.cgContext,
                    pageNumber: currentPage,
                    totalPages: totalPages,
                    userSettings: userSettings
                )

                print("✅ PDF complete. Total pages: \(currentPage)")
            }

            print("✅ PDF generated successfully at: \(pdfURL.path)")
            return pdfURL

        } catch {
            print("❌ Error generating PDF: \(error)")
            return nil
        }
    }

    // MARK: - Header Drawing
    private static func drawHeader(
        context: CGContext,
        y: CGFloat,
        report: DailyReport,
        project: Project,
        userSettings: UserSettings
    ) -> CGFloat {
        var currentY = y

        // Company name
        if !userSettings.companyName.isEmpty {
            currentY = drawText(
                context: context,
                text: userSettings.companyName,
                x: margin,
                y: currentY,
                width: contentWidth,
                fontSize: 18,
                bold: true,
                alignment: .center
            )
            currentY += 8
        }

        // Report title
        currentY = drawText(
            context: context,
            text: "Daily Construction Report",
            x: margin,
            y: currentY,
            width: contentWidth,
            fontSize: 20,
            bold: true,
            alignment: .center
        )
        currentY += 12

        // Project info
        currentY = drawText(
            context: context,
            text: project.name,
            x: margin,
            y: currentY,
            width: contentWidth,
            fontSize: 14,
            bold: true,
            alignment: .center
        )
        currentY += 6

        currentY = drawText(
            context: context,
            text: project.address,
            x: margin,
            y: currentY,
            width: contentWidth,
            fontSize: 12,
            bold: false,
            alignment: .center,
            color: .darkGray
        )
        currentY += 6

        // Report date
        let dateString = report.date.formatted(date: .long, time: .omitted)
        currentY = drawText(
            context: context,
            text: dateString,
            x: margin,
            y: currentY,
            width: contentWidth,
            fontSize: 12,
            bold: false,
            alignment: .center,
            color: .darkGray
        )
        currentY += 12

        // Horizontal line
        drawLine(context: context, y: currentY)
        currentY += 12

        return currentY
    }

    // MARK: - Footer Drawing
    private static func drawFooter(
        context: CGContext,
        pageNumber: Int,
        totalPages: Int,
        userSettings: UserSettings
    ) {
        // Fixed footer position at bottom of page
        let footerY = pageHeight - 80 // Fixed position 80pt from bottom

        // Horizontal line
        drawLine(context: context, y: footerY)

        var currentY = footerY + 8

        // Prepared by
        currentY = drawText(
            context: context,
            text: "Prepared by: \(userSettings.userName)",
            x: margin,
            y: currentY,
            width: contentWidth,
            fontSize: 10,
            bold: false,
            alignment: .left,
            color: .darkGray
        )

        // Company name and license
        var footerInfo = userSettings.companyName
        if !userSettings.licenseNumber.isEmpty {
            footerInfo += " - License: \(userSettings.licenseNumber)"
        }

        if !footerInfo.isEmpty {
            currentY = drawText(
                context: context,
                text: footerInfo,
                x: margin,
                y: currentY + 4,
                width: contentWidth,
                fontSize: 9,
                bold: false,
                alignment: .left,
                color: .darkGray
            )
        }

        // Page number (right aligned at same Y as prepared by)
        let pageText = totalPages > 1 ? "Page \(pageNumber) of \(totalPages)" : "Page \(pageNumber)"
        _ = drawText(
            context: context,
            text: pageText,
            x: margin,
            y: footerY + 8,
            width: contentWidth,
            fontSize: 10,
            bold: false,
            alignment: .right,
            color: .darkGray
        )
    }


    // MARK: - Text Drawing
    private static func drawText(
        context: CGContext,
        text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        fontSize: CGFloat,
        bold: Bool,
        alignment: NSTextAlignment,
        color: UIColor = .black,
        lineSpacing: CGFloat = 1.0
    ) -> CGFloat {
        let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineSpacing = (fontSize * lineSpacing) - fontSize

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textRect = CGRect(x: x, y: y, width: width, height: CGFloat.greatestFiniteMagnitude)
        let boundingRect = attributedString.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                          options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                          context: nil)

        attributedString.draw(in: textRect)

        return y + boundingRect.height
    }

    // MARK: - Text Drawing with Page Breaks
    private static func drawTextWithPageBreaks(
        context: CGContext,
        text: String,
        x: CGFloat,
        startY: CGFloat,
        width: CGFloat,
        fontSize: CGFloat,
        bold: Bool,
        lineSpacing: CGFloat = 1.0,
        currentPage: inout Int,
        addNewPage: () -> Void
    ) -> CGFloat {
        var currentY = startY
        let lines = text.components(separatedBy: .newlines)

        print("   📝 Total lines to render: \(lines.count)")

        let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = (fontSize * lineSpacing) - fontSize

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]

        for (lineIndex, line) in lines.enumerated() {
            // Calculate height for this line
            let lineText = line.isEmpty ? " " : line // Use space for empty lines to maintain spacing
            let attributedLine = NSAttributedString(string: lineText, attributes: attributes)
            let lineHeight = attributedLine.boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            ).height

            // Check if this line will fit on current page
            if currentY + lineHeight > maxY {
                print("   ⚠️ Line \(lineIndex + 1)/\(lines.count) won't fit (Y=\(currentY), lineHeight=\(lineHeight), maxY=\(maxY))")
                print("   📄 Creating new page and continuing...")
                addNewPage()
                currentY = margin
                print("   ✅ Continuing on page \(currentPage) at Y = \(currentY)")
            }

            // Draw the line
            if !line.isEmpty {
                let rect = CGRect(x: x, y: currentY, width: width, height: lineHeight)
                attributedLine.draw(in: rect)
            }

            currentY += lineHeight

            // Progress indicator every 50 lines
            if (lineIndex + 1) % 50 == 0 {
                print("   📊 Progress: \(lineIndex + 1)/\(lines.count) lines drawn, page \(currentPage), Y=\(currentY)")
            }
        }

        print("   ✅ All \(lines.count) lines rendered on page(s) ending at page \(currentPage)")
        return currentY
    }

    // MARK: - Line Drawing
    private static func drawLine(context: CGContext, y: CGFloat) {
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: y))
        context.strokePath()
    }

    // MARK: - Accurate Text Height Calculation
    private static func calculateTextHeight(
        text: String,
        fontSize: CGFloat,
        bold: Bool,
        width: CGFloat,
        lineSpacing: CGFloat = 1.0
    ) -> CGFloat {
        let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = (fontSize * lineSpacing) - fontSize

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedString.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )

        return ceil(boundingRect.height) // Round up to be safe
    }

    // MARK: - Height Estimation
    private static func estimateTextHeight(text: String, fontSize: CGFloat, bold: Bool, lineSpacing: CGFloat = 1.0) -> CGFloat {
        let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = (fontSize * lineSpacing) - fontSize

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let boundingRect = attributedString.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                                          options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                          context: nil)

        return boundingRect.height
    }
}
