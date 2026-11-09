import SwiftUI
import Charts

struct TrendsView: View {
    let profile: UserProfile
    @Environment(DayStore.self) private var dayStore

    private struct Point: Identifiable {
        let day: Date
        let score: DayScore
        let checkIns: Set<CheckInKind>
        var id: Date { day }
    }

    var body: some View {
        let _ = dayStore.revision
        let points = loadPoints()
        let week = Array(points.suffix(7))
        let previousWeek = Array(points.dropLast(7).suffix(7))

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Text("Trends").font(.display(32, weight: .bold)).foregroundStyle(Theme.textPrimary)
                        Spacer()
                    }
                    .padding(.top, 8)

                    if points.isEmpty {
                        Card {
                            Text("Your trends appear after your first scored day.")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    } else {
                        weekCard(week, previous: previousWeek)
                        monthCard(points)
                        InsightsSection(insights: insights(points))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .onAppear { Analytics.track(.trendsViewed) }
        }
    }

    private func weekCard(_ week: [Point], previous: [Point]) -> some View {
        let average = Self.average(week.map(\.score.total))
        let previousAverage = previous.count >= 3 ? Self.average(previous.map(\.score.total)) : nil
        return Card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("THIS WEEK").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(Theme.textTertiary)
                        Text("\(average) avg").font(.display(28, weight: .bold)).foregroundStyle(Theme.textPrimary)
                    }
                    Spacer()
                    if let previousAverage {
                        let delta = average - previousAverage
                        Label("\(delta >= 0 ? "+" : "")\(delta) vs last week", systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(delta >= 0 ? Theme.accent : Theme.textSecondary)
                    }
                }
                Chart(week) { point in
                    BarMark(x: .value("Day", point.day, unit: .day), y: .value("Score", point.score.total), width: .ratio(0.6))
                        .foregroundStyle(Theme.scoreColor(point.score.total))
                        .cornerRadius(6)
                        .annotation(position: .top) {
                            Text("\(point.score.total)").font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(Theme.textSecondary)
                        }
                }
                .chartYScale(domain: 0...110)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow)).foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 170)
            }
        }
    }

    private func monthCard(_ points: [Point]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("LAST 30 DAYS").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(1).foregroundStyle(Theme.textTertiary)
                Chart(points) { point in
                    AreaMark(x: .value("Day", point.day, unit: .day), y: .value("Score", point.score.total))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Day", point.day, unit: .day), y: .value("Score", point.score.total))
                        .foregroundStyle(Theme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { _ in
                        AxisGridLine().foregroundStyle(Theme.stroke)
                        AxisValueLabel().foregroundStyle(Theme.textTertiary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(height: 150)
            }
        }
    }

    private func loadPoints() -> [Point] {
        let records = dayStore.records(last: 30)
        var history: [DayInputs] = []
        var points: [Point] = []
        for record in records {
            let inputs = record.inputs
            let score = ScoringEngine.score(day: inputs, history: Array(history.suffix(14)), profile: profile.scoringProfile)
            history.append(inputs)
            let hasAnything = score.pillars.contains { $0.hasData && $0.pillar != .habits } || !inputs.checkIns.isEmpty
            if hasAnything { points.append(Point(day: record.day, score: score, checkIns: inputs.checkIns)) }
        }
        return points
    }

    /// "Nights after late coffee: sleep score avg 9 lower." Plain mean difference, min 2 samples a side.
    private func insights(_ points: [Point]) -> [Insight] {
        guard points.count >= 7 else { return [] }
        var results: [Insight] = []
        for kind in [CheckInKind.lateCoffee, .alcohol] where profile.checkIns.contains(kind) {
            var after: [Double] = []
            var without: [Double] = []
            for (today, tomorrow) in zip(points, points.dropFirst()) where tomorrow.score.sleep.hasData {
                let sleepPct = tomorrow.score.sleep.ratio * 100
                if today.checkIns.contains(kind) { after.append(sleepPct) } else { without.append(sleepPct) }
            }
            guard after.count >= 2, without.count >= 2 else { continue }
            let diff = Int((without.reduce(0, +) / Double(without.count) - after.reduce(0, +) / Double(after.count)).rounded())
            guard abs(diff) >= 3 else { continue }
            let label = kind == .lateCoffee ? "late coffee" : "drinks"
            results.append(Insight(
                symbol: kind.symbol, color: diff > 0 ? Theme.warning : Theme.accent,
                text: diff > 0 ? "Nights after \(label): sleep score averages \(diff) lower." : "Interesting: \(label) hasn't hurt your sleep score so far."
            ))
        }

        let lightDays = points.filter { $0.score.dayType == .light }
        if lightDays.count >= 2 {
            let respected = lightDays.filter { $0.score.movement.ratio >= 0.85 }.count
            results.append(Insight(symbol: "leaf.fill", color: Theme.accent,
                                   text: "You took \(respected) of \(lightDays.count) recovery days properly after hard sessions."))
        }

        let firstHalf = points.prefix(points.count / 2).map(\.score.total)
        let secondHalf = points.suffix(points.count / 2).map(\.score.total)
        let change = Self.average(Array(secondHalf)) - Self.average(Array(firstHalf))
        if change >= 3 {
            results.append(Insight(symbol: "chart.line.uptrend.xyaxis", color: Theme.accent,
                                   text: "Your score is up \(change) points compared with the start of the month."))
        }
        return results
    }

    private static func average(_ values: [Int]) -> Int {
        values.isEmpty ? 0 : Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }
}

struct Insight: Identifiable {
    let symbol: String
    let color: Color
    let text: String
    var id: String { text }
}

struct InsightsSection: View {
    let insights: [Insight]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONNECTIONS")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundStyle(Theme.textTertiary)
                .padding(.leading, 4)
            if insights.isEmpty {
                Card {
                    Text("After a week of check-ins we'll start spotting what moves your sleep.")
                        .font(.system(size: 15, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            ForEach(insights) { insight in
                Card {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insight.symbol)
                            .foregroundStyle(insight.color)
                            .frame(width: 32, height: 32)
                            .background(insight.color.opacity(0.14), in: Circle())
                        Text(insight.text)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}
