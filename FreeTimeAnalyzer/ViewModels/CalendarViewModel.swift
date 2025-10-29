//
//  CalendarViewModel.swift
//  FreeTimeAnalyzer
//
//  Created by Syed Omar Faruk Towaha on 2025-10-28.
//

import Foundation
import Combine
import EventKit

#if os(iOS)
import UIKit
#endif

class CalendarViewModel: ObservableObject {
    @Published var freeSlots: [DateInterval] = []
    // Expose fetched/busy events for UI display
    @Published var events: [EKEvent] = []
    // Available calendars and selection
    @Published var calendars: [EKCalendar] = []
    @Published var selectedCalendarIdentifier: String = "" // empty = all calendars
    @Published var calendarAccessGranted: Bool = false
    @Published var calendarAccessError: String? = nil
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

    // Debug helper: print all calendars EventKit can see
    func debugPrintCalendars() async {
        let granted = await requestCalendarAccess()
        DispatchQueue.main.async { self.calendarAccessGranted = granted }
        guard granted else {
            print("Cannot print calendars: access not granted")
            return
        }
        let cals = eventStore.calendars(for: .event)
        print("--- EventKit calendars (\(cals.count)) ---")
        for cal in cals {
            let colorDesc: String
            if let cg = cal.cgColor {
                colorDesc = "\(cg)"
            } else {
                colorDesc = "(no color)"
            }
            print("title=\(cal.title), source=\(cal.source.title), id=\(cal.calendarIdentifier), color=\(colorDesc), type=\(cal.type.rawValue)")
        }
        print("--- end calendars ---")
    }

    // Debug helper: print events and the calendar each event belongs to
    func debugPrintEvents(for date: Date, startHour: Int, endHour: Int) async {
        let granted = await requestCalendarAccess()
        DispatchQueue.main.async { self.calendarAccessGranted = granted }
        guard granted else {
            print("Cannot print events: access not granted")
            return
        }

        let dayStart = Calendar.current.startOfDay(for: date)
        guard let workStart = Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: dayStart),
              let workEnd = Calendar.current.date(bySettingHour: endHour, minute: 0, second: 0, of: dayStart) else {
            print("Invalid start/end for debugPrintEvents")
            return
        }

        // If a specific calendar is selected, limit to that calendar
        var calendarsToUse: [EKCalendar]? = nil
        if !selectedCalendarIdentifier.isEmpty, let cal = eventStore.calendar(withIdentifier: selectedCalendarIdentifier) {
            calendarsToUse = [cal]
        }

        let predicate = eventStore.predicateForEvents(withStart: workStart, end: workEnd, calendars: calendarsToUse)
        let events = eventStore.events(matching: predicate)

        print("--- EventKit events ---")
        print("Events count: \(events.count) between \(workStart) and \(workEnd)")
        for ev in events {
            let cal = ev.calendar
            let calTitle = cal?.title ?? "(unknown calendar)"
            let calSource = cal?.source.title ?? "(unknown source)"
            let calId = cal?.calendarIdentifier ?? "(no id)"
            let start = ev.startDate.map { "\($0)" } ?? "(no start)"
            let end = ev.endDate.map { "\($0)" } ?? "(no end)"
            print("Calendar: \(calTitle) [id=\(calId)] source=\(calSource) -> Event: '\(ev.title ?? "(no title)")' \(start) - \(end)")
        }
        print("--- end events ---")
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

    // Force a full sync: reset EventStore caches, reload calendars and events for the given window
    func syncNow(for date: Date, startHour: Int, endHour: Int) async {
        let startTime = Date()
        print("[Sync] starting sync at \(startTime)")

        let granted = await requestCalendarAccess()
        DispatchQueue.main.async { self.calendarAccessGranted = granted }
        guard granted else {
            print("[Sync] calendar access not granted")
            return
        }

        // Reset the event store to clear caches and force fresh data from providers
        eventStore.reset()

        // Reload calendars
        let allCals = eventStore.calendars(for: .event)
        DispatchQueue.main.async {
            self.calendars = allCals.sorted { (a, b) in
                let sa = a.source.title.lowercased()
                let sb = b.source.title.lowercased()
                if sa == sb { return a.title.lowercased() < b.title.lowercased() }
                return sa < sb
            }
        }

        // Compute start/end for the day
        let dayStart = Calendar.current.startOfDay(for: date)
        guard let workStart = Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: dayStart),
              let workEnd = Calendar.current.date(bySettingHour: endHour, minute: 0, second: 0, of: dayStart) else {
            print("[Sync] invalid work window")
            return
        }

        // Fetch events (respect selected calendar if set)
        var calendarsToUse: [EKCalendar]? = nil
        if !selectedCalendarIdentifier.isEmpty, let cal = eventStore.calendar(withIdentifier: selectedCalendarIdentifier) {
            calendarsToUse = [cal]
        }
        let predicate = eventStore.predicateForEvents(withStart: workStart, end: workEnd, calendars: calendarsToUse)
        let fetched = eventStore.events(matching: predicate)

        DispatchQueue.main.async {
            self.events = fetched
            self.freeSlots = self.calculateFreeTime(workStart: workStart, workEnd: workEnd, events: fetched)
        }

        let endTime = Date()
        print("[Sync] finished sync at \(endTime) — fetched \(self.calendars.count) calendars and \(fetched.count) events; duration: \(endTime.timeIntervalSince(startTime))s")
    }

    private func requestCalendarAccess() async -> Bool {
        // Check current authorization status first to avoid unnecessary prompts
        let status: EKAuthorizationStatus
        if #available(macOS 14.0, iOS 17.0, *) {
            status = EKEventStore.authorizationStatus(for: .event)
        } else {
            status = EKEventStore.authorizationStatus(for: .event)
        }

        switch status {
        case .authorized, .fullAccess:
            DispatchQueue.main.async {
                self.calendarAccessError = nil
            }
            return true
        case .restricted:
            DispatchQueue.main.async {
                self.calendarAccessError = "Calendar access is restricted on this device."
            }
            return false
        case .denied:
            DispatchQueue.main.async {
                self.calendarAccessError = "Calendar access was denied. Please enable access in Settings."
            }
            return false
        case .notDetermined:
            break // fall through to request
        case .writeOnly:
            // write-only authorization means we can't read events — surface a helpful message
            DispatchQueue.main.async {
                self.calendarAccessError = "Calendar access is write-only on this device."
            }
            return false
        @unknown default:
            break
        }

        // Request access using the appropriate API per platform/version
        if #available(macOS 14.0, *) {
            return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                self.eventStore.requestFullAccessToEvents { granted, error in
                    if let err = error as NSError? {
                        let msg = "Calendar access error: \(err.domain) (code \(err.code)) - \(err.localizedDescription)"
                        print(msg)
                        DispatchQueue.main.async { self.calendarAccessError = msg }
                    } else if !granted {
                        DispatchQueue.main.async {
                            self.calendarAccessError = "Calendar access was not granted."
                        }
                    } else {
                        DispatchQueue.main.async { self.calendarAccessError = nil }
                    }
                    continuation.resume(returning: granted)
                }
            }
        } else {
            // iOS, iPadOS, and earlier macOS versions
            return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                self.eventStore.requestAccess(to: .event) { granted, error in
                    if let err = error as NSError? {
                        let msg = "Calendar access error: \(err.domain) (code \(err.code)) - \(err.localizedDescription)"
                        print(msg)
                        DispatchQueue.main.async { self.calendarAccessError = msg }
                    } else if !granted {
                        DispatchQueue.main.async {
                            self.calendarAccessError = "Calendar access was not granted."
                        }
                    } else {
                        DispatchQueue.main.async { self.calendarAccessError = nil }
                    }
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    #if os(iOS)
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    #endif

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
