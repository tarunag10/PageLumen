import Charts
import PageLumenCore
import SwiftUI

struct ConfidenceChartView: View {
    let document: ReaderDocument
    let lowConfidenceThreshold: Double = 0.7

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Per-page OCR confidence")
                .font(.headline)
            Chart(pageAverages) { entry in
                BarMark(
                    x: .value("Page", entry.pageNumber),
                    y: .value("Confidence", entry.averageConfidence)
                )
                .foregroundStyle(entry.averageConfidence < lowConfidenceThreshold ? AccessibleStyle.warning : AccessibleStyle.success)
            }
            .chartYScale(domain: 0...1)
            .chartYAxis {
                AxisMarks(values: [0, 0.5, 0.7, 1.0])
            }
            .frame(minHeight: 200)
            .accessibilityLabel("Per-page OCR confidence chart")
            .accessibilityChartDescriptor(self)
            Text("Bars below \(Int(lowConfidenceThreshold * 100))% are highlighted as low-confidence pages.")
                .font(.caption)
                .foregroundStyle(.primary)
        }
        .padding()
    }

    private struct PageAverage: Identifiable {
        let id: Int
        let pageNumber: Int
        let averageConfidence: Double
    }

    private var pageAverages: [PageAverage] {
        document.pages.map { page in
            let confidences = page.blocks.map(\.confidence)
            let average = confidences.isEmpty ? 0.0 : confidences.reduce(0, +) / Double(confidences.count)
            return PageAverage(id: page.pageNumber, pageNumber: page.pageNumber, averageConfidence: average)
        }
    }
}

extension ConfidenceChartView: AXChartDescriptorRepresentable {
    func makeChartDescriptor() -> AXChartDescriptor {
        let pageCount = max(document.pages.count, 1)
        let xAxis = AXNumericDataAxisDescriptor(
            title: "Page",
            range: 1...Double(pageCount),
            gridlinePositions: []
        ) { String(format: "%.0f", $0) }

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Confidence",
            range: 0...1,
            gridlinePositions: [0.5, 0.7]
        ) { value in
            String(format: "%.0f%%", value * 100)
        }

        let series = AXDataSeriesDescriptor(
            name: "Average confidence",
            isContinuous: true,
            dataPoints: pageAverages.map { entry in
                AXDataPoint(x: Double(entry.pageNumber), y: entry.averageConfidence)
            }
        )

        return AXChartDescriptor(
            title: "Per-page OCR confidence",
            summary: "Average confidence per page, with low-confidence pages highlighted",
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
