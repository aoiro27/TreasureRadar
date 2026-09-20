import SwiftUI

enum RadarRenderer {
    static let phosphor = Color(red: 0.45, green: 0.98, blue: 0.42)
    static let phosphorDim = Color(red: 0.18, green: 0.42, blue: 0.18)
    static let screen = Color(red: 0.02, green: 0.07, blue: 0.03)
    static let blip = Color(red: 1.0, green: 0.32, blue: 0.12)

    static func draw(
        context: GraphicsContext,
        size: CGSize,
        date: Date,
        treasures: [DetectedTreasure],
        isScanning: Bool,
        isFound: Bool
    ) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2 - 4

        let screenPath = Path(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        context.fill(screenPath, with: .color(screen))

        context.drawLayer { ctx in
            ctx.clip(to: screenPath)
            drawGrid(ctx, center: center, radius: radius)
            if treasures.contains(where: { $0.usesUWBDistance }) {
                drawPhoneHeading(ctx, center: center, radius: radius)
            }
            if isScanning {
                drawSweep(ctx, center: center, radius: radius, date: date)
            }
            drawTreasures(ctx, center: center, radius: radius, treasures: treasures, date: date, isFound: isFound)
            drawScanlines(ctx, size: size, radius: radius, center: center)
            drawVignette(ctx, center: center, radius: radius)
        }

        context.stroke(screenPath, with: .color(phosphor.opacity(0.35)), lineWidth: 2)

        if isFound {
            let pulse = 0.45 + 0.25 * sin(date.timeIntervalSinceReferenceDate * 8)
            context.stroke(
                screenPath,
                with: .color(phosphor.opacity(pulse)),
                lineWidth: 6
            )
        }
    }

    private static func drawGrid(_ context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        for fraction in [0.25, 0.5, 0.75, 1.0] {
            let ring = radius * fraction
            let rect = CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(phosphor.opacity(fraction == 1 ? 0.55 : 0.28)), lineWidth: 1)
        }

        var cross = Path()
        cross.move(to: CGPoint(x: center.x - radius, y: center.y))
        cross.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        cross.move(to: CGPoint(x: center.x, y: center.y - radius))
        cross.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        context.stroke(cross, with: .color(phosphor.opacity(0.28)), lineWidth: 1)

        for tick in 0..<8 {
            let angle = Double(tick) * .pi / 4
            var tickPath = Path()
            let inner = CGPoint(
                x: center.x + CGFloat(cos(angle)) * (radius - 10),
                y: center.y + CGFloat(sin(angle)) * (radius - 10)
            )
            let outer = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            tickPath.move(to: inner)
            tickPath.addLine(to: outer)
            context.stroke(tickPath, with: .color(phosphor.opacity(0.4)), lineWidth: 2)
        }

        let you = CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)
        context.fill(Path(ellipseIn: you), with: .color(phosphor))
    }

    private static func drawPhoneHeading(
        _ context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat
    ) {
        let tip = CGPoint(x: center.x, y: center.y - radius * 0.92)
        var arrow = Path()
        arrow.move(to: tip)
        arrow.addLine(to: CGPoint(x: center.x - 8, y: center.y - radius * 0.78))
        arrow.addLine(to: CGPoint(x: center.x + 8, y: center.y - radius * 0.78))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(Color(red: 0.45, green: 0.85, blue: 1.0)))

        let labels: [(String, CGPoint)] = [
            ("前", CGPoint(x: center.x, y: center.y - radius * 0.62)),
            ("みぎ", CGPoint(x: center.x + radius * 0.62, y: center.y)),
            ("ひだり", CGPoint(x: center.x - radius * 0.62, y: center.y)),
            ("うしろ", CGPoint(x: center.x, y: center.y + radius * 0.62))
        ]
        for (text, point) in labels {
            context.draw(
                Text(text)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.45, green: 0.85, blue: 1.0).opacity(0.9)),
                at: point
            )
        }
    }

    private static func drawSweep(
        _ context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        date: Date
    ) {
        let period = 2.6
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
        let sweep = t * .pi * 2 - .pi / 2
        let wedges = 48

        for index in 0..<wedges {
            let frac = Double(index) / Double(wedges)
            let start = sweep - frac * 0.95
            let end = start + 0.03
            var path = Path()
            path.move(to: center)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .radians(start),
                endAngle: .radians(end),
                clockwise: false
            )
            path.closeSubpath()
            context.fill(path, with: .color(phosphor.opacity((1 - frac) * 0.22)))
        }

        var needle = Path()
        needle.move(to: center)
        needle.addLine(to: CGPoint(
            x: center.x + CGFloat(cos(sweep)) * radius,
            y: center.y + CGFloat(sin(sweep)) * radius
        ))
        context.stroke(needle, with: .color(phosphor.opacity(0.85)), lineWidth: 2)
    }

    private static func drawTreasures(
        _ context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        treasures: [DetectedTreasure],
        date: Date,
        isFound: Bool
    ) {
        for treasure in treasures {
            let usableRadius = radius * 0.86
            let distanceRadius = usableRadius * treasure.radarRadius
            if treasure.usesUWBDistance, !treasure.usesUWBDirection {
                let rect = CGRect(
                    x: center.x - distanceRadius,
                    y: center.y - distanceRadius,
                    width: distanceRadius * 2,
                    height: distanceRadius * 2
                )
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(blip.opacity(0.7)),
                    style: StrokeStyle(lineWidth: 3, dash: [7, 5])
                )
                if let meters = treasure.accuracyMeters {
                    context.draw(
                        Text(UWBRadarFusion.formattedMeters(meters))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(blip),
                        at: CGPoint(x: center.x, y: center.y - distanceRadius - 10)
                    )
                }
                continue
            }

            let point = CGPoint(
                x: center.x + CGFloat(cos(treasure.radarAngle)) * distanceRadius,
                y: center.y + CGFloat(sin(treasure.radarAngle)) * distanceRadius
            )
            if treasure.usesUWBDirection {
                var bearing = Path()
                bearing.move(to: center)
                bearing.addLine(to: point)
                context.stroke(bearing, with: .color(blip.opacity(0.7)), lineWidth: 3)

                var head = Path()
                let tipAngle = treasure.radarAngle
                let left = tipAngle + 2.7
                let right = tipAngle - 2.7
                head.move(to: point)
                head.addLine(to: CGPoint(
                    x: point.x + CGFloat(cos(left)) * 14,
                    y: point.y + CGFloat(sin(left)) * 14
                ))
                head.addLine(to: CGPoint(
                    x: point.x + CGFloat(cos(right)) * 14,
                    y: point.y + CGFloat(sin(right)) * 14
                ))
                head.closeSubpath()
                context.fill(head, with: .color(blip))
            }
            let pulse = 0.75 + 0.25 * sin(date.timeIntervalSinceReferenceDate * 6 + treasure.radarAngle)
            let size: CGFloat = treasure.proximity == .immediate ? 11 : 8

            let glow = CGRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32)
            context.fill(Path(ellipseIn: glow), with: .color(blip.opacity(0.18 * pulse)))

            let core = CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
            context.fill(Path(ellipseIn: core), with: .color(blip.opacity(0.55 + 0.45 * pulse)))

            if treasure.usesUWBDirection, let meters = treasure.accuracyMeters {
                let label = UWBRadarFusion.relativeDirectionLabel(
                    fromHorizontalAngle: treasure.uwbHorizontalAngle ?? (treasure.radarAngle + .pi / 2)
                )
                context.draw(
                    Text("\(label) \(UWBRadarFusion.formattedMeters(meters))")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white),
                    at: CGPoint(x: point.x, y: point.y + 16)
                )
            }

            if isFound, treasure.proximity == .immediate {
                let ring = CGRect(x: point.x - 18, y: point.y - 18, width: 36, height: 36)
                context.stroke(Path(ellipseIn: ring), with: .color(phosphor.opacity(pulse)), lineWidth: 2)
            }
        }
    }

    private static func drawScanlines(
        _ context: GraphicsContext,
        size: CGSize,
        radius: CGFloat,
        center: CGPoint
    ) {
        var lines = Path()
        var y = center.y - radius
        while y < center.y + radius {
            lines.move(to: CGPoint(x: center.x - radius, y: y))
            lines.addLine(to: CGPoint(x: center.x + radius, y: y))
            y += 3
        }
        context.stroke(lines, with: .color(.black.opacity(0.12)), lineWidth: 1)
    }

    private static func drawVignette(_ context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let inner = radius * 0.55
        let donut = Path(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        context.stroke(donut, with: .color(.black.opacity(0.35)), lineWidth: radius - inner)
    }
}

struct DragonRadarView: View {
    var treasures: [DetectedTreasure]
    var isScanning: Bool
    var isFound: Bool
    var onTick: (Date) -> Void = { _ in }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isScanning)) { timeline in
            Canvas { context, size in
                RadarRenderer.draw(
                    context: context,
                    size: size,
                    date: timeline.date,
                    treasures: treasures,
                    isScanning: isScanning,
                    isFound: isFound
                )
            }
            .aspectRatio(1, contentMode: .fit)
            .onChange(of: timeline.date) { _, date in
                onTick(date)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if isFound { return "宝を見つけました" }
        if treasures.isEmpty { return "レーダー。宝はまだ見えていません" }
        if let closest = treasures.min(by: { $0.radarRadius < $1.radarRadius }) {
            if closest.usesUWBDirection {
                let meters = closest.accuracyMeters.map(UWBRadarFusion.formattedMeters) ?? ""
                let direction = closest.uwbHorizontalAngle.map(UWBRadarFusion.relativeDirectionLabel(fromHorizontalAngle:)) ?? ""
                return "レーダー。宝は\(direction) \(meters)。画面の上はスマホのうしろ向き"
            }
            if closest.usesUWBDistance {
                let meters = closest.accuracyMeters.map(UWBRadarFusion.formattedMeters) ?? ""
                return "レーダー。距離 \(meters)。方角はまだわかりません"
            }
            return "レーダー。\(closest.proximity.kidLabel)"
        }
        return "レーダー"
    }
}
