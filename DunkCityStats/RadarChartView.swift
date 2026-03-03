import SwiftUI

struct RadarChartView: View {
    let player1: Player
    let player2: Player
    let metrics: [RadarMetric]

    private let maxStat: CGFloat = 150
    private let ringCount = 5

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) * 0.34

            ZStack {
                ForEach(1...ringCount, id: \.self) { ring in
                    ringPath(
                        center: center,
                        radius: radius * CGFloat(ring) / CGFloat(ringCount)
                    )
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                }

                ForEach(metrics.indices, id: \.self) { index in
                    axisPath(index: index, center: center, radius: radius)
                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                }

                polygonPath(for: player1, center: center, radius: radius)
                    .fill(Color.blue.opacity(0.24))
                polygonPath(for: player1, center: center, radius: radius)
                    .stroke(Color.blue, lineWidth: 2)

                polygonPath(for: player2, center: center, radius: radius)
                    .fill(Color.orange.opacity(0.24))
                polygonPath(for: player2, center: center, radius: radius)
                    .stroke(Color.orange, lineWidth: 2)

                ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                    Text(LocalizedStringKey(metric.nameKey))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .position(pointForValue(index: index, valueScale: 1.14, center: center, radius: radius))
                }

                ForEach(1...ringCount, id: \.self) { ring in
                    Text("\(Int(maxStat * CGFloat(ring) / CGFloat(ringCount)))")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .position(
                            x: center.x + 12,
                            y: center.y - radius * CGFloat(ring) / CGFloat(ringCount)
                        )
                }
            }
        }
    }

    private func pointForValue(
        index: Int,
        valueScale: CGFloat,
        center: CGPoint,
        radius: CGFloat
    ) -> CGPoint {
        let angle = (CGFloat(2 * Double.pi) / CGFloat(metrics.count)) * CGFloat(index) - (.pi / 2)
        let distance = radius * valueScale
        return CGPoint(
            x: center.x + distance * cos(angle),
            y: center.y + distance * sin(angle)
        )
    }

    private func polygonPath(for player: Player, center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()

        for (index, metric) in metrics.enumerated() {
            let rawValue = CGFloat(player[keyPath: metric.keyPath])
            let normalizedValue = min(max(rawValue / maxStat, 0), 1)
            let point = pointForValue(
                index: index,
                valueScale: normalizedValue,
                center: center,
                radius: radius
            )

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    private func ringPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()

        for index in metrics.indices {
            let point = pointForValue(index: index, valueScale: 1, center: center, radius: radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    private func axisPath(index: Int, center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: center)
        path.addLine(to: pointForValue(index: index, valueScale: 1, center: center, radius: radius))
        return path
    }
}
