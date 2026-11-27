import SwiftUI

// MARK: - Pace Sparkline Chart
// Reusable sparkline for Pace history.
// Y-axis: Higher pace values appear HIGHER on chart.
// A downward-trending line means Pace is dropping → user is improving.
// The dashed baseline at 1.0 anchors interpretation:
//   • Below the line = aging slower than average (good)
//   • Above the line = aging faster than average (needs attention)

struct PaceSparkline: View {
    let dataPoints: [Double]      // Pace values, oldest first
    let lineColor: Color
    let baselineValue: Double = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            // Y-axis range: pad slightly beyond data range
            let dataMin = dataPoints.min() ?? 0.95
            let dataMax = dataPoints.max() ?? 1.05
            let minVal = min(dataMin - 0.02, 0.90)
            let maxVal = max(dataMax + 0.02, 1.10)
            let range = maxVal - minVal
            
            // Map data to screen points
            // Higher pace value → higher Y in data space → LOWER Y on screen (top of chart)
            let points: [CGPoint] = dataPoints.enumerated().map { index, value in
                let x = width * CGFloat(index) / CGFloat(max(dataPoints.count - 1, 1))
                // Invert: high values at top (low screen Y), low values at bottom (high screen Y)
                let normalized = CGFloat((value - minVal) / range)
                let y = height * (1.0 - normalized)
                return CGPoint(x: x, y: y)
            }
            
            // Baseline Y position (where 1.0 sits on screen)
            let baselineNormalized = CGFloat((baselineValue - minVal) / range)
            let baselineY = height * (1.0 - baselineNormalized)
            
            ZStack {
                // Dashed baseline at 1.0
                Path { path in
                    path.move(to: CGPoint(x: 0, y: baselineY))
                    path.addLine(to: CGPoint(x: width, y: baselineY))
                }
                .stroke(
                    Color(hex: "#2a2a34"),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
                
                // "1.0" label at right edge of baseline
                Text("1.0")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(hex: "#3e3e48"))
                    .position(x: width - 12, y: baselineY - 10)
                
                if points.count > 1 {
                    // Gradient fill under the sparkline
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: baselineY))
                        path.addLine(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.addLine(to: CGPoint(x: points.last!.x, y: baselineY))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [lineColor.opacity(0.18), lineColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // The sparkline stroke
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        lineColor,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    
                    // Glowing end dot (current position)
                    if let lastPoint = points.last {
                        // Outer glow
                        Circle()
                            .fill(lineColor.opacity(0.25))
                            .frame(width: 14, height: 14)
                            .position(lastPoint)
                        
                        // Inner dot
                        Circle()
                            .fill(lineColor)
                            .frame(width: 7, height: 7)
                            .position(lastPoint)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Improving (Below 1.0)") {
    ZStack {
        Color(hex: "#111116").ignoresSafeArea()
        
        PaceSparkline(
            dataPoints: [1.02, 1.01, 1.00, 0.99, 0.99, 0.98, 0.97, 0.98, 0.97, 0.96, 0.95, 0.94, 0.95, 0.94],
            lineColor: Color(hex: "#4a9e8e")
        )
        .frame(height: 60)
        .padding(24)
    }
}

#Preview("Needs Attention (Above 1.0)") {
    ZStack {
        Color(hex: "#111116").ignoresSafeArea()
        
        PaceSparkline(
            dataPoints: [0.98, 0.99, 1.00, 1.01, 1.02, 1.01, 1.03, 1.04, 1.03, 1.05, 1.04, 1.06, 1.05, 1.07],
            lineColor: Color(hex: "#c46a5a")
        )
        .frame(height: 60)
        .padding(24)
    }
}