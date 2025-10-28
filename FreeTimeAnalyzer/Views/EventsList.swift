//
//  EventsList.swift
//  FreeTimeAnalyzer
//
//  Created by assistant on 2025-10-28.
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
                ForEach(events, id: \.startDate) { event in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(event.title ?? "(No title)")
                                .font(.body)
                                .foregroundColor(.primary)
                            Text(timeRange(for: event))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }

    private func timeRange(for event: EKEvent) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        guard let s = event.startDate, let e = event.endDate else { return "" }
        return "\(fmt.string(from: s)) — \(fmt.string(from: e))"
    }
}
