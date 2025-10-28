//
//  ContentView.swift
//  FreeTimeAnalyzer
//
//  Created by Syed Omar Faruk Towaha on 2025-10-28.
//

import SwiftUI
import EventKit
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var workingStart = 9
    @State private var workingEnd = 17
    @State private var selectedDate = Date()

    var body: some View {
        NavigationSplitView {
            // Sidebar: date picker (graphical) + controls
            VStack(spacing: 16) {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal)

                // Calendar selector (choose which calendar to view)
                Picker("Calendar", selection: $viewModel.selectedCalendarIdentifier) {
                    Text("All Calendars").tag("")
                    ForEach(viewModel.calendars, id: \.calendarIdentifier) { cal in
                        HStack {
                            Circle()
                                .fill(Color(cal.cgColor ?? .black))
                                .frame(width: 10, height: 10)
                            Text("\(cal.title) — \(cal.source.title)")
                        }
                        .tag(cal.calendarIdentifier)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)

                if !viewModel.calendarAccessGranted {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calendar access not granted or no calendars found.")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        HStack(spacing: 8) {
                            Button("Refresh Calendars") {
                                Task { await viewModel.refreshCalendars() }
                            }
                            Button("Print Calendars (debug)") {
                                Task { await viewModel.debugPrintCalendars() }
                            }
                            Button("Open System Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }

                VStack {
                    HStack {
                        Text("Workday Start: \(workingStart):00")
                        Spacer()
                        Stepper("", value: $workingStart, in: 0...23)
                    }
                    HStack {
                        Text("Workday End: \(workingEnd):00")
                        Spacer()
                        Stepper("", value: $workingEnd, in: 1...24)
                    }
                }
                .padding(.horizontal)

                Divider()

                VStack(spacing: 8) {
                    Button("Calculate Free Time") {
                        Task { await viewModel.loadCalendarData(for: selectedDate, startHour: workingStart, endHour: workingEnd) }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Simulate Event 14:00-15:00") {
                        viewModel.simulateEvent(on: selectedDate, startHour: 14, endHour: 15)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()

                Spacer()
            }
            .padding(.top)
        } detail: {
            // Main content: calendar summary and free slots
            VStack(spacing: 16) {
                Text(selectedDate, style: .date)
                    .font(.title2)

                FreeTimePanel(freeSlots: viewModel.freeSlots)

                EventsList(events: viewModel.events)

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: selectedDate) { _, newDate in
                Task { await viewModel.loadCalendarData(for: newDate, startHour: workingStart, endHour: workingEnd) }
            }
            .onChange(of: workingStart) { _, newStart in
                Task { await viewModel.loadCalendarData(for: selectedDate, startHour: newStart, endHour: workingEnd) }
            }
            .onChange(of: workingEnd) { _, newEnd in
                Task { await viewModel.loadCalendarData(for: selectedDate, startHour: workingStart, endHour: newEnd) }
            }
            .onChange(of: viewModel.selectedCalendarIdentifier) { _, _ in
                Task { await viewModel.loadCalendarData(for: selectedDate, startHour: workingStart, endHour: workingEnd) }
            }
            .task {
                await viewModel.loadAvailableCalendars()
                await viewModel.loadCalendarData(for: selectedDate, startHour: workingStart, endHour: workingEnd)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

