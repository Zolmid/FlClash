#if !ZOLNIT_OBSERVER_ACCEPTANCE
#error("LeaseObserver requires an explicit acceptance build")
#endif

import Foundation
import SwiftUI

@main
struct LeaseObserverApp: App {
  var body: some Scene {
    WindowGroup { LeaseObserverView() }
  }
}

private struct LeaseObserverView: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var role = "ios_extension"
  @State private var presentation = LeaseObservationPresentation.unavailable

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text("Acceptance only")) {
          Picker("Core role", selection: $role) {
            Text("Network Extension").tag("ios_extension")
            Text("Main app").tag("ios_app")
          }
          Text(presentation.status).font(.system(.body, design: .monospaced))
          Text("deadline_result: \(presentation.deadlineResult)")
            .font(.system(.body, design: .monospaced))
          Text("A fresh file does not prove the producer is alive. This observer reads only the App Group snapshot and never starts VPN or contacts the main app.")
            .font(.footnote)
        }
        if !presentation.payload.isEmpty {
          Section(header: Text("Core snapshot")) {
            Text(presentation.payload)
              .font(.system(.caption, design: .monospaced))
              .textSelection(.enabled)
          }
        }
      }
      .navigationTitle("ZolNit Lease Observer")
    }
    .task(id: role + (scenePhase == .active ? ":active" : ":inactive")) {
      guard scenePhase == .active else { return }
      let observedRole = role
      let group = Bundle.main.object(forInfoDictionaryKey: "ZolNitObserverAppGroup") as? String ?? ""
      while !Task.isCancelled {
        let next = await Task.detached(priority: .utility) {
          guard group.hasPrefix("group."), !group.contains("$("),
            let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
          else { return LeaseObservationPresentation.unavailable }
          return LeaseObservationPresentation.read(containerURL: directory, role: observedRole)
        }.value
        guard !Task.isCancelled else { return }
        presentation = next
        do { try await Task.sleep(nanoseconds: 1_000_000_000) }
        catch { return }
      }
    }
  }
}
