//
//  FreeTimePanel.swift
//  FreeTimeAnalyzer
//
//  Created by Syed Omar Faruk Towaha on 2025-10-28.
//

import SwiftUI

struct FreeTimePanel: View {
    let freeSlots: [DateInterval]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Free Time Slots (Today)")
                .font(.title2)
                .foregroundColor(.primary)
            ForEach(freeSlots, id: \.start) { slot in
                Text(slotFormatter(slot))
                    .font(.body)
            }
            if freeSlots.isEmpty {
                Text("No free slots available.").foregroundColor(.secondary)
            }
        }
    .padding()
    }

    // Format time range
    private func slotFormatter(_ interval: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: interval.start)) - \(formatter.string(from: interval.end))"
    }
}
