import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(
        \.dismiss
    ) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                Section("Workday") {
                    HStack {
                        Text("Start hour")
                        Spacer()
                        Stepper("\(viewModel.workStart):00", value: $viewModel.workStart, in: 0...23)
                    }
                    HStack {
                        Text("End hour")
                        Spacer()
                        Stepper("\(viewModel.workEnd):00", value: $viewModel.workEnd, in: 1...24)
                    }
                }

                Section("Sync") {
                    Picker("Auto-sync", selection: $viewModel.autoSyncMinutes) {
                        Text("Off").tag(0)
                        Text("5 min").tag(5)
                        Text("10 min").tag(10)
                        Text("15 min").tag(15)
                    }
                    .pickerStyle(.menu)

                    Button("Sync Now") {
                        Task { await viewModel.syncNow(for: Date(), startHour: viewModel.workStart, endHour: viewModel.workEnd) }
                    }
                }

                Section("Calendar View") {
                    Picker("Display", selection: $viewModel.calendarDisplayMode) {
                        ForEach(CalendarViewModel.CalendarDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Debug") {
                    Button("Print Calendars (debug)") { Task { await viewModel.debugPrintCalendars() } }
                    Button("Print Events (debug)") { Task { await viewModel.debugPrintEvents(for: Date(), startHour: viewModel.workStart, endHour: viewModel.workEnd) } }
                }
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 420, minHeight: 360)
    }
}
