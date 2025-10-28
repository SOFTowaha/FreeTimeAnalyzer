//
//  CalendarViewModel.swift
//  FreeTimeAnalyzer
//
//  Created by Syed Omar Faruk Towaha on 2025-10-28.
//

import Foundation
import Combine
import EventKit

class CalendarViewModel: ObservableObject {
    @Published var freeSlots: [DateInterval] = []
    // Expose fetched/busy events for UI display
    @Published var events: [EKEvent] = []
    // Available calendars and selection
    @Published var calendars: [EKCalendar] = []
    @Published var selectedCalendarIdentifier: String = "" // empty = all calendars
    @Published var calendarAccessGranted: Bool = false
    private let eventStore = EKEventStore()

    // Load calendar events and compute free slots for a specific date
    func loadCalendarData(for date: Date, startHour: Int, endHour: Int) async {
        let granted = await requestCalendarAccess()
        DispatchQueue.main.async { self.calendarAccessGranted = granted }
        guard granted else {
            DispatchQueue.main.async {
                self.events = []
                self.freeSlots = []
            }
            return
        }
        let dayStart = Calendar.current.startOfDay(for: date)
        guard let workStart = Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: dayStart),
              let workEnd = Calendar.current.date(bySettingHour: endHour, minute: 0, second: 0, of: dayStart) else {
            freeSlots = []
            return
        }

        let fetched = fetchEvents(between: workStart, and: workEnd, calendarIdentifier: selectedCalendarIdentifier)
        DispatchQueue.main.async {
            self.events = fetched
            self.freeSlots = self.calculateFreeTime(workStart: workStart, workEnd: workEnd, events: fetched)
        }
    }

    // Load available calendars (call after requesting access)
    func loadAvailableCalendars() async {
        let granted = await requestCalendarAccess()
        DispatchQueue.main.async { self.calendarAccessGranted = granted }
        guard granted else { return }

        let cals = eventStore.calendars(for: .event)
        DispatchQueue.main.async {
            // sort stable by source title then calendar title
            self.calendars = cals.sorted { (a, b) in
                let sa = a.source.title.lowercased()
                let sb = b.source.title.lowercased()
                if sa == sb {
                    return a.title.lowercased() < b.title.lowercased()
                }
                return sa < sb
            }
        }
    }

    // Force reload calendars (useful after user enables permission in Settings)
    func refreshCalendars() async {
        await loadAvailableCalendars()
    }

    // Simulate an event on a particular date
    func simulateEvent(on date: Date, startHour: Int, endHour: Int) {
        let dayStart = Calendar.current.startOfDay(for: date)
        guard let simStart = Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: dayStart),
              let simEnd = Calendar.current.date(bySettingHour: endHour, minute: 0, second: 0, of: dayStart) else {
            return
        }
        let simulatedEvent = EKEvent(eventStore: eventStore)
        simulatedEvent.title = "Simulated Event"
        simulatedEvent.startDate = simStart
        simulatedEvent.endDate = simEnd

        // Recompute with simulated event within the working window and show it in events list
        DispatchQueue.main.async {
            // add simulated event to the visible events list (not persisted)
            self.events = [simulatedEvent]
            self.freeSlots = self.calculateFreeTime(workStart: simStart, workEnd: simEnd, events: [simulatedEvent])
        }
    }

    private func requestCalendarAccess() async -> Bool {
        // EventKit permission APIs changed in macOS 14. Use the newer API when available
        if #available(macOS 14.0, *) {
            return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                eventStore.requestFullAccessToEventsWithCompletion { granted, error in
                    if let error = error {
                        print("Calendar access error: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: granted)
                }
            }
        } else {
            return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        print("Calendar access error: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func fetchEvents(between start: Date, and end: Date, calendarIdentifier: String) -> [EKEvent] {
        var calendarsToUse: [EKCalendar]? = nil
        if !calendarIdentifier.isEmpty, let cal = eventStore.calendar(withIdentifier: calendarIdentifier) {
            calendarsToUse = [cal]
        }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendarsToUse)
        return eventStore.events(matching: predicate)
    }

    // Calculate time not covered by any event
    private func calculateFreeTime(workStart: Date, workEnd: Date, events: [EKEvent]) -> [DateInterval] {
        var busyIntervals = events.map { DateInterval(start: $0.startDate, end: $0.endDate) }
        busyIntervals.sort { $0.start < $1.start }

        var freeSlots: [DateInterval] = []
        var current = workStart

        for interval in busyIntervals {
            if interval.start > current {
                freeSlots.append(DateInterval(start: current, end: interval.start))
            }
            if interval.end > current {
                current = interval.end
            }
        }
        if current < workEnd {
            freeSlots.append(DateInterval(start: current, end: workEnd))
        }
        return freeSlots
    }
}
