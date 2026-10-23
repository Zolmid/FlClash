import Foundation
import SwiftUI

public enum NativeUiContract {
    public static let schemaVersion = 1
    public static let channel = "com.zolmid.zolnit/native-ui"
    public static let viewType = "com.zolmid.zolnit/native-home"
}

public struct NativeUiSnapshot: Codable, Equatable {
    public let schemaVersion: Int
    public let revision: Int
    public let accountGeneration: Int
    public let locale: String
    public let textDirection: TextDirection
    public let safeMode: Bool
    public let sessionStatus: SessionStatus
    public let connectionState: ConnectionState
    public let destination: Destination
    public let mode: ConnectionMode
    public let selectedServerId: String?
    public let servers: [Server]
    public let planName: String?
    public let planExpiresAt: Int?
    public let usage: Usage
    public let traffic: Traffic
    public let labels: [String: String]

    public init(
        schemaVersion: Int,
        revision: Int,
        accountGeneration: Int,
        locale: String,
        textDirection: TextDirection,
        safeMode: Bool,
        sessionStatus: SessionStatus,
        connectionState: ConnectionState,
        destination: Destination,
        mode: ConnectionMode,
        selectedServerId: String?,
        servers: [Server],
        planName: String?,
        planExpiresAt: Int?,
        usage: Usage,
        traffic: Traffic,
        labels: [String: String]
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.accountGeneration = accountGeneration
        self.locale = locale
        self.textDirection = textDirection
        self.safeMode = safeMode
        self.sessionStatus = sessionStatus
        self.connectionState = connectionState
        self.destination = destination
        self.mode = mode
        self.selectedServerId = selectedServerId
        self.servers = servers
        self.planName = planName
        self.planExpiresAt = planExpiresAt
        self.usage = usage
        self.traffic = traffic
        self.labels = labels
    }

    public enum TextDirection: String, Codable { case ltr, rtl }
    public enum SessionStatus: String, Codable { case restoring, signedOut, signedIn, offline, expired }
    public enum ConnectionState: String, Codable { case disconnected, connecting, connected, disconnecting, failed }
    public enum Destination: String, Codable, CaseIterable { case connect, servers, plans, account }
    public enum ConnectionMode: String, Codable { case rule, global }

    public struct Server: Codable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let available: Bool
        public let latencyMs: Int?
    }

    public struct Usage: Codable, Equatable {
        public let usedBytes: Int64?
        public let totalBytes: Int64?
    }

    public struct Traffic: Codable, Equatable {
        public let uploadBps: Int64?
        public let downloadBps: Int64?
    }
}

public enum NativeUiSnapshotError: Error, Equatable {
    case malformed
    case unsupportedSchema
    case invalidRevision
    case invalidAccountGeneration
    case missingLabels
    case invalidValue
}

enum NativeByteText {
    static func format(_ value: Int64?, locale: String) -> String {
        guard let value else { return "—" }
        let units = ["B", "KiB", "MiB", "GiB", "TiB", "PiB", "EiB"]
        var amount = Double(value)
        var unit = 0
        while amount >= 1024 && unit < units.count - 1 {
            amount /= 1024
            unit += 1
        }
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: locale)
        formatter.maximumFractionDigits = unit == 0 ? 0 : 2
        return "\(formatter.string(from: NSNumber(value: amount)) ?? String(amount)) \(units[unit])"
    }
}

public extension NativeUiSnapshot {
    static let requiredLabels = [
        "connect", "disconnect", "disconnected", "connecting", "connected", "disconnecting", "connectionFailed",
        "smartMode", "globalMode", "servers", "plans", "account", "refresh", "preferences", "help",
        "trafficRemaining", "trafficUsed", "upload", "download", "noPlan", "noServers", "signIn",
        "restoringSession", "offline", "retry", "safeMode", "selectServer", "currentPlan", "loading",
    ]

    static func decode(json: String) throws -> NativeUiSnapshot {
        guard let data = json.data(using: .utf8) else { throw NativeUiSnapshotError.malformed }
        let decoder = JSONDecoder()
        guard let snapshot = try? decoder.decode(NativeUiSnapshot.self, from: data) else {
            throw NativeUiSnapshotError.malformed
        }
        guard snapshot.schemaVersion == NativeUiContract.schemaVersion else {
            throw NativeUiSnapshotError.unsupportedSchema
        }
        guard snapshot.revision >= 0 else { throw NativeUiSnapshotError.invalidRevision }
        guard snapshot.accountGeneration >= 0 else { throw NativeUiSnapshotError.invalidAccountGeneration }
        guard snapshot.usage.usedBytes.map({ $0 >= 0 }) ?? true,
              snapshot.usage.totalBytes.map({ $0 >= 0 }) ?? true,
              snapshot.traffic.uploadBps.map({ $0 >= 0 }) ?? true,
              snapshot.traffic.downloadBps.map({ $0 >= 0 }) ?? true,
              snapshot.servers.allSatisfy({ $0.latencyMs.map({ $0 >= 0 }) ?? true }) else {
            throw NativeUiSnapshotError.invalidValue
        }
        guard Set(snapshot.labels.keys).isSuperset(of: Set(requiredLabels)) else {
            throw NativeUiSnapshotError.missingLabels
        }
        return snapshot
    }
}

public struct NativeUiCommand: Codable, Equatable {
    public let schemaVersion: Int
    public let id: String
    public let accountGeneration: Int
    public let action: Action
    public let payload: [String: String]

    public enum Action: String, Codable, Hashable { case connect, disconnect, selectServer, setMode, navigate, refresh, preferences, help }

    public init(id: String = UUID().uuidString, accountGeneration: Int, action: Action, payload: [String: String] = [:]) {
        self.schemaVersion = NativeUiContract.schemaVersion
        self.id = id
        self.accountGeneration = accountGeneration
        self.action = action
        self.payload = payload
    }
}

public struct NativeUiReceipt: Codable, Equatable {
    public let schemaVersion: Int
    public let id: String
    public let accepted: Bool
    public let errorCode: String?

    public static func decode(json: String, commandId: String) -> NativeUiReceipt? {
        guard let data = json.data(using: .utf8),
              let receipt = try? JSONDecoder().decode(NativeUiReceipt.self, from: data),
              receipt.schemaVersion == NativeUiContract.schemaVersion,
              receipt.id == commandId else { return nil }
        return receipt
    }
}

public final class NativeUiStore: ObservableObject {
    @Published public private(set) var snapshot: NativeUiSnapshot?
    private var lastRevision: Int = -1
    private var accountGeneration: Int?

    public init() {}

    @discardableResult
    public func publish(json: String) -> Bool {
        guard let incoming = try? NativeUiSnapshot.decode(json: json), incoming.revision > lastRevision else {
            return false
        }
        if let accountGeneration, incoming.accountGeneration < accountGeneration {
            return false
        }
        if accountGeneration != incoming.accountGeneration {
            snapshot = nil
        }
        accountGeneration = incoming.accountGeneration
        lastRevision = incoming.revision
        snapshot = incoming
        return true
    }

    public func clear() {
        snapshot = nil
        lastRevision = -1
        accountGeneration = nil
    }
}

public final class NativeUiBridge: ObservableObject {
    public enum Feedback: String { case offline, retry, connectionFailed, safeMode }

    public let store: NativeUiStore
    private let perform: (String, @escaping (String?) -> Void) -> Void
    @Published public private(set) var feedback: Feedback?
    @Published private var pendingActions = Set<NativeUiCommand.Action>()

    public init(store: NativeUiStore, perform: @escaping (String, @escaping (String?) -> Void) -> Void) {
        self.store = store
        self.perform = perform
    }

    public func send(_ action: NativeUiCommand.Action, payload: [String: String] = [:]) {
        guard let snapshot = store.snapshot, !pendingActions.contains(action) else { return }
        let command = NativeUiCommand(accountGeneration: snapshot.accountGeneration, action: action, payload: payload)
        guard let data = try? JSONEncoder().encode(command), let json = String(data: data, encoding: .utf8) else { return }
        pendingActions.insert(action)
        perform(json) { response in
            DispatchQueue.main.async {
                self.pendingActions.remove(action)
                guard self.store.snapshot?.accountGeneration == command.accountGeneration else { return }
                guard let response,
                      let receipt = NativeUiReceipt.decode(json: response, commandId: command.id) else {
                    self.feedback = .retry
                    return
                }
                guard receipt.accepted else {
                    self.feedback = Self.feedback(for: receipt.errorCode)
                    return
                }
                self.feedback = nil
            }
        }
    }

    public func isPending(_ action: NativeUiCommand.Action) -> Bool { pendingActions.contains(action) }

    private static func feedback(for errorCode: String?) -> Feedback {
        switch errorCode {
        case "unavailable", "unauthenticated": .offline
        case "safe_mode": .safeMode
        case "failed": .connectionFailed
        default: .retry
        }
    }
}

public struct NativeHomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var bridge: NativeUiBridge
    @ObservedObject private var store: NativeUiStore

    public init(bridge: NativeUiBridge) {
        _bridge = ObservedObject(wrappedValue: bridge)
        _store = ObservedObject(wrappedValue: bridge.store)
    }

    public var body: some View {
        Group {
            if let snapshot = store.snapshot {
                content(snapshot)
                    .environment(\.layoutDirection, snapshot.textDirection == .rtl ? .rightToLeft : .leftToRight)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private func content(_ snapshot: NativeUiSnapshot) -> some View {
        #if os(iOS)
        TabView(selection: Binding(
            get: { snapshot.destination },
            set: { bridge.send(.navigate, payload: ["destination": $0.rawValue]) }
        )) {
            connect(snapshot).tabItem { Label(label(snapshot, "connect"), systemImage: "power") }.tag(NativeUiSnapshot.Destination.connect)
            servers(snapshot).tabItem { Label(label(snapshot, "servers"), systemImage: "server.rack") }.tag(NativeUiSnapshot.Destination.servers)
            plans(snapshot).tabItem { Label(label(snapshot, "plans"), systemImage: "creditcard") }.tag(NativeUiSnapshot.Destination.plans)
            account(snapshot).tabItem { Label(label(snapshot, "account"), systemImage: "person.crop.circle") }.tag(NativeUiSnapshot.Destination.account)
        }
        #else
        macConnection(snapshot)
        #endif
    }

    #if os(macOS)
    private var paper: Color { colorScheme == .dark ? Color(red: 21/255, green: 30/255, blue: 36/255) : Color(red: 243/255, green: 241/255, blue: 235/255) }
    private var card: Color { colorScheme == .dark ? Color(red: 32/255, green: 44/255, blue: 51/255) : Color(red: 250/255, green: 249/255, blue: 245/255) }
    private var ink: Color { colorScheme == .dark ? Color(red: 233/255, green: 239/255, blue: 236/255) : Color(red: 40/255, green: 54/255, blue: 62/255) }
    private var muted: Color { colorScheme == .dark ? Color(red: 168/255, green: 183/255, blue: 189/255) : Color(red: 83/255, green: 99/255, blue: 107/255) }
    private var accent: Color { colorScheme == .dark ? Color(red: 171/255, green: 199/255, blue: 214/255) : Color(red: 80/255, green: 106/255, blue: 122/255) }

    private func macConnection(_ snapshot: NativeUiSnapshot) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(statusLabel(snapshot))
                            .font(.largeTitle.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        if snapshot.safeMode {
                            Label(label(snapshot, "safeMode"), systemImage: "shield")
                                .font(.body)
                                .foregroundStyle(muted)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Button {
                                bridge.send(snapshot.connectionState == .connected ? .disconnect : .connect)
                            } label: {
                                Label(
                                    label(snapshot, snapshot.connectionState == .connected ? "disconnect" : "connect"),
                                    systemImage: snapshot.connectionState == .connected ? "stop.fill" : "power"
                                )
                                .frame(minWidth: 156, minHeight: 28)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canToggleConnection(snapshot) || bridge.isPending(.connect) || bridge.isPending(.disconnect))
                            Picker(label(snapshot, "smartMode"), selection: Binding(
                                get: { snapshot.mode },
                                set: { bridge.send(.setMode, payload: ["mode": $0.rawValue]) }
                            )) {
                                Text(label(snapshot, "smartMode")).tag(NativeUiSnapshot.ConnectionMode.rule)
                                Text(label(snapshot, "globalMode")).tag(NativeUiSnapshot.ConnectionMode.global)
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 340)
                            .disabled(!canManageConnectionSettings(snapshot) || bridge.isPending(.setMode))
                        }
                        if let feedback = bridge.feedback {
                            Text(label(snapshot, feedback.rawValue)).foregroundStyle(muted)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    if geometry.size.width >= 700 {
                        HStack(alignment: .top, spacing: 20) {
                            routeSummary(snapshot)
                            planSummary(snapshot)
                        }
                    } else {
                        routeSummary(snapshot)
                        planSummary(snapshot)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text(label(snapshot, "trafficUsed")).font(.headline)
                        Text(usageText(snapshot)).font(.title2.monospacedDigit())
                        if let total = snapshot.usage.totalBytes, total > 0, snapshot.usage.usedBytes != nil {
                            ProgressView(value: usageFraction(snapshot))
                        }
                        HStack {
                            Label(speed(snapshot.traffic.uploadBps, locale: snapshot.locale), systemImage: "arrow.up")
                                .accessibilityLabel(Text(label(snapshot, "upload")))
                            Spacer()
                            Label(speed(snapshot.traffic.downloadBps, locale: snapshot.locale), systemImage: "arrow.down")
                                .accessibilityLabel(Text(label(snapshot, "download")))
                        }
                        .foregroundStyle(muted)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .frame(maxWidth: 1040, alignment: .leading)
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(paper)
            .foregroundStyle(ink)
            .tint(accent)
        }
    }

    private func routeSummary(_ snapshot: NativeUiSnapshot) -> some View {
        summary(snapshot, title: "servers", value: snapshot.servers.first(where: { $0.id == snapshot.selectedServerId })?.name ?? label(snapshot, "selectServer"), destination: .servers)
    }

    private func planSummary(_ snapshot: NativeUiSnapshot) -> some View {
        summary(snapshot, title: "currentPlan", value: snapshot.planName ?? label(snapshot, "noPlan"), destination: .plans)
    }

    private func summary(_ snapshot: NativeUiSnapshot, title: String, value: String, destination: NativeUiSnapshot.Destination) -> some View {
        Button {
            bridge.send(.navigate, payload: ["destination": destination.rawValue])
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(label(snapshot, title)).font(.headline).foregroundStyle(muted)
                HStack(alignment: .firstTextBaseline) {
                    Text(value).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 12)
                    Image(systemName: "chevron.forward").foregroundStyle(muted)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .background(card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func usageText(_ snapshot: NativeUiSnapshot) -> String {
        "\(NativeByteText.format(snapshot.usage.usedBytes, locale: snapshot.locale)) / \(NativeByteText.format(snapshot.usage.totalBytes, locale: snapshot.locale))"
    }
    #endif

    private func connect(_ snapshot: NativeUiSnapshot) -> some View {
        VStack(spacing: 20) {
            NativeBrandLogo()
            Text(statusLabel(snapshot)).font(.title2).accessibilityAddTraits(.isHeader)
            Button {
                bridge.send(snapshot.connectionState == .connected ? .disconnect : .connect)
            } label: {
                Label(
                    label(snapshot, snapshot.connectionState == .connected ? "disconnect" : "connect"),
                    systemImage: snapshot.connectionState == .connected ? "stop.fill" : "power"
                )
                .frame(minWidth: 156)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canToggleConnection(snapshot) || bridge.isPending(snapshot.connectionState == .connected ? .disconnect : .connect))
            Picker(label(snapshot, "smartMode"), selection: Binding(
                get: { snapshot.mode }, set: { bridge.send(.setMode, payload: ["mode": $0.rawValue]) }
            )) {
                Text(label(snapshot, "smartMode")).tag(NativeUiSnapshot.ConnectionMode.rule)
                Text(label(snapshot, "globalMode")).tag(NativeUiSnapshot.ConnectionMode.global)
            }
            .pickerStyle(.segmented)
            .disabled(!canManageConnectionSettings(snapshot) || bridge.isPending(.setMode))
            traffic(snapshot)
            if let feedback = bridge.feedback {
                Text(label(snapshot, feedback.rawValue))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle(label(snapshot, "connect"))
    }

    private func traffic(_ snapshot: NativeUiSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label(snapshot, "trafficUsed"))
            if snapshot.usage.usedBytes != nil && snapshot.usage.totalBytes != nil {
                ProgressView(value: usageFraction(snapshot))
            } else {
                Text("—")
            }
            HStack {
                Label(speed(snapshot.traffic.uploadBps, locale: snapshot.locale), systemImage: "arrow.up")
                    .accessibilityLabel(Text(label(snapshot, "upload")))
                Spacer()
                Label(speed(snapshot.traffic.downloadBps, locale: snapshot.locale), systemImage: "arrow.down")
                    .accessibilityLabel(Text(label(snapshot, "download")))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func servers(_ snapshot: NativeUiSnapshot) -> some View {
        List(snapshot.servers) { server in
            Button {
                bridge.send(.selectServer, payload: ["serverId": server.id])
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(server.name)
                        if let latency = server.latencyMs { Text(latencyText(latency, locale: snapshot.locale)).font(.caption) }
                    }
                    Spacer()
                    if server.id == snapshot.selectedServerId { Image(systemName: "checkmark") }
                }
            }
            .disabled(!server.available || !canManageConnectionSettings(snapshot) || bridge.isPending(.selectServer))
        }
        .overlay { if snapshot.servers.isEmpty { Text(label(snapshot, "noServers")) } }
        .navigationTitle(label(snapshot, "servers"))
    }

    private func plans(_ snapshot: NativeUiSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(label(snapshot, "currentPlan")).font(.headline)
            Text(snapshot.planName ?? label(snapshot, "noPlan"))
            Button(label(snapshot, "refresh")) { bridge.send(.refresh) }
        }
        .padding()
        .navigationTitle(label(snapshot, "plans"))
    }

    private func account(_ snapshot: NativeUiSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sessionLabel(snapshot))
            Button(label(snapshot, "preferences")) { bridge.send(.preferences) }
            Button(label(snapshot, "help")) { bridge.send(.help) }
        }
        .padding()
        .navigationTitle(label(snapshot, "account"))
    }

    private func label(_ snapshot: NativeUiSnapshot, _ key: String) -> String { snapshot.labels[key] ?? "" }
    private func statusLabel(_ snapshot: NativeUiSnapshot) -> String {
        switch snapshot.connectionState {
        case .disconnected: label(snapshot, "disconnected")
        case .connecting: label(snapshot, "connecting")
        case .connected: label(snapshot, "connected")
        case .disconnecting: label(snapshot, "disconnecting")
        case .failed: label(snapshot, "connectionFailed")
        }
    }
    private func sessionLabel(_ snapshot: NativeUiSnapshot) -> String {
        switch snapshot.sessionStatus {
        case .restoring: label(snapshot, "restoringSession")
        case .signedOut, .expired: label(snapshot, "signIn")
        case .signedIn: label(snapshot, "account")
        case .offline: label(snapshot, "offline")
        }
    }
    private func usageFraction(_ snapshot: NativeUiSnapshot) -> Double {
        guard let used = snapshot.usage.usedBytes,
              let total = snapshot.usage.totalBytes, total > 0 else { return 0 }
        return min(1, Double(used) / Double(total))
    }
    private func canToggleConnection(_ snapshot: NativeUiSnapshot) -> Bool {
        guard !snapshot.safeMode, snapshot.connectionState != .connecting, snapshot.connectionState != .disconnecting else { return false }
        return snapshot.connectionState == .connected || snapshot.sessionStatus == .signedIn
    }
    private func canManageConnectionSettings(_ snapshot: NativeUiSnapshot) -> Bool {
        !snapshot.safeMode && snapshot.sessionStatus == .signedIn && snapshot.connectionState != .connecting && snapshot.connectionState != .disconnecting
    }
    private func speed(_ bytesPerSecond: Int64?, locale: String) -> String {
        guard let bytesPerSecond else { return "—" }
        let formatted = NativeByteText.format(bytesPerSecond, locale: locale)
        return "\(formatted)/s"
    }
    private func latencyText(_ milliseconds: Int, locale: String) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = Locale(identifier: locale)
        formatter.unitOptions = .providedUnit
        return formatter.string(from: Measurement(value: Double(milliseconds), unit: UnitDuration.milliseconds))
    }
}

private struct NativeBrandLogo: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(colorScheme == .dark ? "zolnit-horizontal-dark" : "zolnit-horizontal-light", bundle: NativeUiAssets.bundle)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 180, maxHeight: 44)
            .accessibilityHidden(true)
    }
}

private enum NativeUiAssets {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: NativeUiBundleMarker.self)
        #endif
    }
}

private final class NativeUiBundleMarker {}
