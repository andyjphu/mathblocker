//
//  DebugSection.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import DeviceActivity
import SwiftData

/// Full-screen contact/report view. Combines a bug report form with the
/// diagnostic info from the old `DebugSection`, so users can attach logs
/// to a report with one tap and submit via Formspree.
struct ReportBugView: View {
    @Query private var settings: [UserSettings]

    @State private var description: String = ""
    @State private var email: String = ""
    @State private var includeLogs: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var submitStatus: SubmitStatus = .idle

    @State private var debugInfo: String = ""
    @State private var debugLog: String = ""

    private enum SubmitStatus: Equatable {
        case idle
        case success
        case failure(String)
    }

    private let formspreeURL = URL(string: "https://formspree.io/f/xnjoejjy")!

    var body: some View {
        Form {
            // MARK: Report form
            Section {
                TextField("what went wrong? (optional)", text: $description, axis: .vertical)
                    .lineLimit(4...10)

                TextField("email (optional, helps us follow up)", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Toggle("include diagnostic logs", isOn: $includeLogs)

                Button {
                    submit()
                } label: {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isSubmitting ? "sending..." : "send report")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isSubmitting)
            } header: {
                Text("report a bug")
            } footer: {
                Text("we read every report. attach logs to help us diagnose.")
            }
            .listRowBackground(Theme.cardBackground)

            // MARK: Submit status
            if submitStatus != .idle {
                Section {
                    switch submitStatus {
                    case .success:
                        Label("sent, thanks", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .failure(let msg):
                        Label(msg, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    case .idle:
                        EmptyView()
                    }
                }
                .listRowBackground(Theme.cardBackground)
            }

            // MARK: Diagnostic info
            Section {
                Text(debugInfo)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Text("state")
            } footer: {
                Text("tap and hold to select and copy.")
            }
            .listRowBackground(Theme.cardBackground)

            // MARK: Extension log
            Section {
                ScrollView {
                    Text(debugLog.isEmpty ? "(empty)" : debugLog)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                }
                .frame(maxHeight: 240)

                Button("refresh") {
                    loadDebugInfo()
                }
                Button("clear log") {
                    AppGroupConstants.sharedDefaults?.removeObject(forKey: "extensionLog")
                    debugLog = "(empty)"
                }
                .foregroundStyle(.orange)
                Button("force re-register monitoring") {
                    MonitoringManager.shared.stopMonitoring()
                    let budget = settings.first?.dailyTimeBudgetMinutes ?? 30
                    MonitoringManager.shared.startMonitoring(budgetMinutes: budget)
                    loadDebugInfo()
                }
            } header: {
                Text("extension log")
            } footer: {
                Text("tap and hold to select and copy.")
            }
            .listRowBackground(Theme.cardBackground)
        }
        .fontDesign(.serif)
        .scrollContentBackground(.hidden)
        .background { FrostedBackground(image: "olive-mountain") }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Contact")
                    .font(Theme.titleFont(size: 20))
            }
        }
        .onAppear { loadDebugInfo() }
    }

    // MARK: - Data

    private func loadDebugInfo() {
        let defaults = AppGroupConstants.sharedDefaults
        let budget = defaults?.integer(forKey: AppGroupConstants.budgetMinutesKey) ?? -1
        let hasSelection = defaults?.data(forKey: AppGroupConstants.selectionKey) != nil
        let log = defaults?.string(forKey: "extensionLog") ?? ""
        let monitoring = MonitoringManager.shared.isMonitoring

        debugInfo = """
        monitoring: \(monitoring ? "on" : "off")
        budget: \(budget) min
        selection saved: \(hasSelection ? "yes" : "no")
        """
        debugLog = log.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            let activities = DeviceActivityCenter().activities.map(\.rawValue).joined(separator: ", ")
            await MainActor.run {
                debugInfo += "\nactivities: \(activities.isEmpty ? "none" : activities)"
            }
        }
    }

    // MARK: - Submit

    private func submit() {
        isSubmitting = true
        submitStatus = .idle

        var message = description.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty { message = "(no description)" }

        if includeLogs {
            message += "\n\n--- diagnostic info ---\n\(debugInfo)"
            if !debugLog.isEmpty {
                message += "\n\n--- extension log ---\n\(debugLog)"
            }
        }

        // Formspree accepts JSON with `email` and `message` fields
        var body: [String: Any] = ["message": message]
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEmail.isEmpty {
            body["email"] = trimmedEmail
        }
        body["source"] = "mathblocker-ios"

        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            isSubmitting = false
            submitStatus = .failure("couldn't encode request")
            return
        }

        var request = URLRequest(url: formspreeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = data

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                await MainActor.run {
                    isSubmitting = false
                    if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                        submitStatus = .success
                        description = ""
                    } else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                        submitStatus = .failure("submit failed (HTTP \(code))")
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    submitStatus = .failure(error.localizedDescription)
                }
            }
        }
    }
}
