import SwiftUI

struct CalendarDisplayView: View {
    @Binding var selectedDate: Date
    @ObservedObject var viewModel: CalendarViewModel

    var body: some View {
        switch viewModel.calendarDisplayMode {
        case .year:
            YearCalendarView(centerDate: selectedDate)
        case .month:
            MonthCalendarView(month: selectedDate)
        case .week:
            WeekCalendarView(referenceDate: selectedDate)
        }
    }
}

// MARK: - Year view (12 months)
struct YearCalendarView: View {
    let centerDate: Date
    private let months = Array(0..<12)
    private var yearStart: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year], from: centerDate)
        return cal.date(from: comps) ?? centerDate
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(months, id: \.(self)) { idx in
                    if let monthDate = Calendar.current.date(byAdding: .month, value: idx, to: yearStart) {
                        MiniMonthView(month: monthDate)
                            .frame(minHeight: 140)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Mini month
struct MiniMonthView: View {
    let month: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(monthTitle(month))
                .font(.headline)
            MonthGrid(month: month, small: true)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func monthTitle(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "LLLL yyyy"
        return fmt.string(from: d)
    }
}

// MARK: - Month view
struct MonthCalendarView: View {
    let month: Date

    var body: some View {
        VStack(alignment: .leading) {
            Text(monthTitle(month))
                .font(.title3)
                .padding(.leading)
            MonthGrid(month: month)
        }
        .padding()
    }

    private func monthTitle(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "LLLL yyyy"
        return fmt.string(from: d)
    }
}

// MARK: - Week view
struct WeekCalendarView: View {
    let referenceDate: Date
    var body: some View {
        VStack(alignment: .leading) {
            Text("Week of " + weekTitle(referenceDate))
                .font(.title3)
                .padding(.leading)
            HStack(spacing: 8) {
                ForEach(daysOfWeek(referenceDate), id: \.self) { d in
                    VStack {
                        Text(shortWeekday(d))
                            .font(.caption)
                        Text(dayNum(d))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding()
        }
    }

    private func weekTitle(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: d)
    }

    private func daysOfWeek(_ d: Date) -> [Date] {
        var cal = Calendar.current
        cal.firstWeekday = 1
        let weekday = cal.component(.weekday, from: d)
        guard let start = cal.date(byAdding: .day, value: -(weekday - cal.firstWeekday), to: d) else { return [d] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func shortWeekday(_ d: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "E"
        return fmt.string(from: d)
    }

    private func dayNum(_ d: Date) -> String { String(Calendar.current.component(.day, from: d)) }
}

// MARK: - Month grid
struct MonthGrid: View {
    let month: Date
    var small: Bool = false

    var body: some View {
        let days = daysInMonth(month)
        VStack(spacing: 6) {
            HStack {
                ForEach(0..<7) { idx in
                    Text(shortWeekday(index: idx))
                        .font(.caption2)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<rows(for: days.count), id: \.(self)) { r in
                HStack(spacing: 6) {
                    ForEach(0..<7) { c in
                        let idx = r * 7 + c
                        if idx < days.count, let d = days[idx] {
                            Text("\(Calendar.current.component(.day, from: d))")
                                .font(small ? .caption2 : .body)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, small ? 2 : 6)
                        } else {
                            Text("")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, small ? 2 : 6)
                        }
                    }
                }
            }
        }
    }

    private func shortWeekday(index: Int) -> String {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        return symbols[(index + Calendar.current.firstWeekday - 1) % 7]
    }

    private func rows(for count: Int) -> Int { (count + 6) / 7 }

    private func daysInMonth(_ date: Date) -> [Date?] {
        var cal = Calendar.current
        cal.firstWeekday = 1
        guard let range = cal.range(of: .day, in: .month, for: date),
              let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: date)) else { return [] }

        let firstWeekday = cal.component(.weekday, from: monthStart)
        var items: [Date?] = Array(repeating: nil, count: firstWeekday - cal.firstWeekday)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: monthStart) {
                items.append(d)
            }
        }
        // pad to full weeks
        while items.count % 7 != 0 { items.append(nil) }
        return items
    }
}
