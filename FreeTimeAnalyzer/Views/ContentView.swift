//
//  ContentView.swift
//  FreeTimeAnalyzer
//
//  Created by Syed Omar Faruk Towaha on 2025-10-28.
//

import SwiftUI
import EventKit
import AppKit
import Foundation

struct ContentView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var workingStart = 9
    @State private var workingEnd = 17
    @State private var selectedDate = Date()
    @State private var autoSyncMinutes: Int = 0
    @State private var autoSyncTask: Task<Void, Never>? = nil

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
                .glassControl(cornerRadius: 12)
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

                // Always-available debug actions
                HStack(spacing: 8) {
                    Button("Print Events (debug)") {
                        Task { await viewModel.debugPrintEvents(for: selectedDate, startHour: workingStart, endHour: workingEnd) }
                    }
                    .buttonStyle(GlassButtonStyle())

                    Button("Print Calendars (debug)") {
                        Task { await viewModel.debugPrintCalendars() }
                    }
                    .buttonStyle(GlassButtonStyle())
                }
                .padding(.horizontal)

                // Sync controls
                HStack(spacing: 12) {
                    Button("Sync Now") {
                        Task {
                            await viewModel.syncNow(for: selectedDate, startHour: workingStart, endHour: workingEnd)
                        }
                    }

                    Picker("Auto-sync", selection: $autoSyncMinutes) {
                        Text("Off").tag(0)
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: autoSyncMinutes) { newValue in
                        // cancel previous task
                        autoSyncTask?.cancel()
                        autoSyncTask = nil
                        if newValue > 0 {
                            autoSyncTask = Task {
                                while !Task.isCancelled {
                                    await viewModel.syncNow(for: selectedDate, startHour: workingStart, endHour: workingEnd)
                                    do {
                                        try await Task.sleep(nanoseconds: UInt64(newValue) * 60 * 1_000_000_000)
                                    } catch {
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                VStack {
                    HStack {
                        Text("Workday Start: \(workingStart):00")
                            .font(.subheadline)
                        Spacer()
                        Stepper("", value: $workingStart, in: 0...23)
                            .labelsHidden()
                    }
                    .glassControl()

                    HStack {
                        Text("Workday End: \(workingEnd):00")
                            .font(.subheadline)
                        Spacer()
                        Stepper("", value: $workingEnd, in: 1...24)
                            .labelsHidden()
                    }
                    .glassControl()
                }
                .padding(.horizontal)

                Divider()

                VStack(spacing: 8) {
                    Button("Calculate Free Time") {
                        Task { await viewModel.loadCalendarData(for: selectedDate, startHour: workingStart, endHour: workingEnd) }
                    }
                    .buttonStyle(GlassButtonStyle(cornerRadius: 12))

                    Button("Simulate Event 14:00-15:00") {
                        viewModel.simulateEvent(on: selectedDate, startHour: 14, endHour: 15)
                    }
                    .buttonStyle(GlassButtonStyle(cornerRadius: 12))
                }
                .padding()

                Spacer()
            }
            .padding(.top)
            .padding(.all, 8)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        } detail: {
            // Main content: calendar summary and free slots
            VStack(spacing: 16) {
                // Header (glass) with title and quick status
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FreeTimeAnalyzer")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(selectedDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 12) {
                        if let last = viewModel.lastSync {
                            Text("Last sync: \(last.formatted(.dateTime.hour().minute()))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Last sync: —")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Button(action: {
                            Task { await viewModel.syncNow(for: selectedDate, startHour: workingStart, endHour: workingEnd) }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(GlassButtonStyle())
                    }
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                FreeTimePanel(freeSlots: viewModel.freeSlots)

                EventsList(events: viewModel.events)

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
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
            .onChange(of: autoSyncMinutes) { _, _ in }
            .task {
                await viewModel.loadAvailableCalendars()
                await viewModel.loadCalendarData(for: selectedDate, startHour: workingStart, endHour: workingEnd)
            }
            .onDisappear {
                autoSyncTask?.cancel()
                autoSyncTask = nil
            }
        }
        .navigationSplitViewStyle(.balanced)
        .padding(12)
        .background(
            // subtle overall background tint to emulate macOS glass
            LinearGradient(colors: [Color(.windowBackgroundColor).opacity(0.02), Color(.windowBackgroundColor).opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

