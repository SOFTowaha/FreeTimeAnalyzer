//
//  EventsList.swift
//  FreeTimeAnalyzer
//
//  Created by Syed Omar Faruk Towaha on 2025-10-28.
//

import SwiftUI
import EventKit

struct EventsList: View {
    let events: [EKEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Events")
                .font(.title3)
                .padding(.bottom, 4)

            if events.isEmpty {
                Text("No events for this day.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(events.indices, id: \.self) { idx in
                    let event = events[idx]
                    HStack {
                        VStack(alignment: .leading) {
                            HStack(spacing: 8) {
                                Text(event.title ?? "(No title)")
                                    .font(.body)
                                    .foregroundColor(.primary)

                                // Calendar name + color
                                if let cal = event.calendar {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color(cal.cgColor ?? .black))
                                            .frame(width: 10, height: 10)
                                        Text(cal.title)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }

                            Text(timeRange(for: event))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding()
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.03), lineWidth: 1)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 8)
    }

    private func timeRange(for event: EKEvent) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        guard let s = event.startDate, let e = event.endDate else { return "" }
        return "\(fmt.string(from: s)) — \(fmt.string(from: e))"
    }
}
