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
    public let returnRoute: ReturnRoute?

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
        labels: [String: String],
        returnRoute: ReturnRoute? = nil
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
        self.returnRoute = returnRoute
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, revision, accountGeneration, locale, textDirection, safeMode, sessionStatus, connectionState, destination, mode, selectedServerId, servers, planName, planExpiresAt, usage, traffic, labels, returnRoute
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        revision = try values.decode(Int.self, forKey: .revision)
        accountGeneration = try values.decode(Int.self, forKey: .accountGeneration)
        locale = try values.decode(String.self, forKey: .locale)
        textDirection = try values.decode(TextDirection.self, forKey: .textDirection)
        safeMode = try values.decode(Bool.self, forKey: .safeMode)
        sessionStatus = try values.decode(SessionStatus.self, forKey: .sessionStatus)
        connectionState = try values.decode(ConnectionState.self, forKey: .connectionState)
        destination = try values.decode(Destination.self, forKey: .destination)
        mode = try values.decode(ConnectionMode.self, forKey: .mode)
        selectedServerId = try values.decodeIfPresent(String.self, forKey: .selectedServerId)
        servers = try values.decode([Server].self, forKey: .servers)
        planName = try values.decodeIfPresent(String.self, forKey: .planName)
        planExpiresAt = try values.decodeIfPresent(Int.self, forKey: .planExpiresAt)
        usage = try values.decode(Usage.self, forKey: .usage)
        traffic = try values.decode(Traffic.self, forKey: .traffic)
        labels = try values.decode([String: String].self, forKey: .labels)
        returnRoute = try? values.decode(ReturnRoute.self, forKey: .returnRoute)
    }

    public struct ReturnRoute: Codable, Equatable {
        public let title: String
        public let selectedId: String?
        public let enabled: Bool
        public let options: [Option]

        public struct Option: Codable, Equatable, Identifiable {
            public let id: String
            public let label: String
        }

        private enum CodingKeys: String, CodingKey { case title, selectedId, enabled, options }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            title = try values.decode(String.self, forKey: .title)
            selectedId = try values.decodeIfPresent(String.self, forKey: .selectedId)
            enabled = try values.decode(Bool.self, forKey: .enabled)
            options = try values.decode([Option].self, forKey: .options)
            guard !title.isEmpty, title.count <= 4096, options.count <= 3,
                  Set(options.map(\.id)).count == options.count,
                  options.allSatisfy({ ["direct", "hk_lite", "hk_optimized"].contains($0.id) && !$0.label.isEmpty && $0.label.count <= 4096 }),
                  selectedId.map({ selected in options.contains { $0.id == selected } }) ?? true else {
                throw NativeUiSnapshotError.invalidValue
            }
        }
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

    public enum Action: String, Codable, Hashable { case connect, disconnect, selectServer, selectReturnRoute, setMode, navigate, refresh, preferences, help }

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
        if action == .selectReturnRoute {
            guard pendingActions.isEmpty, let route = snapshot.returnRoute, route.enabled,
                  let optionId = payload["optionId"], route.options.contains(where: { $0.id == optionId }) else { return }
        }
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

    public var hasPendingCommand: Bool { !pendingActions.isEmpty }

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.sizeCategory) private var sizeCategory
    #endif
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
            iosPage(snapshot, destination: .connect).tabItem { Label(label(snapshot, "connect"), systemImage: "power") }.tag(NativeUiSnapshot.Destination.connect)
            iosPage(snapshot, destination: .servers).tabItem { Label(label(snapshot, "servers"), systemImage: "server.rack") }.tag(NativeUiSnapshot.Destination.servers)
            iosPage(snapshot, destination: .plans).tabItem { Label(label(snapshot, "plans"), systemImage: "creditcard") }.tag(NativeUiSnapshot.Destination.plans)
            iosPage(snapshot, destination: .account).tabItem { Label(label(snapshot, "account"), systemImage: "person.crop.circle") }.tag(NativeUiSnapshot.Destination.account)
        }
        .tint(iosAccent)
        #else
        macConnection(snapshot)
        #endif
    }

    #if os(iOS)
    private var iosPaper: Color { colorScheme == .dark ? Color(red: 21/255, green: 30/255, blue: 36/255) : Color(red: 243/255, green: 241/255, blue: 235/255) }
    private var iosCard: Color { colorScheme == .dark ? Color(red: 32/255, green: 44/255, blue: 51/255) : Color(red: 250/255, green: 249/255, blue: 245/255) }
    private var iosInk: Color { colorScheme == .dark ? Color(red: 233/255, green: 239/255, blue: 236/255) : Color(red: 40/255, green: 54/255, blue: 62/255) }
    private var iosMuted: Color { colorScheme == .dark ? Color(red: 168/255, green: 183/255, blue: 189/255) : Color(red: 83/255, green: 99/255, blue: 107/255) }
    private var iosAccent: Color { colorScheme == .dark ? Color(red: 171/255, green: 199/255, blue: 214/255) : Color(red: 80/255, green: 106/255, blue: 122/255) }
    private var iosBlue: Color { colorScheme == .dark ? Color(red: 43/255, green: 59/255, blue: 70/255) : Color(red: 220/255, green: 229/255, blue: 237/255) }
    private var iosMemberInk: Color { Color(red: 233/255, green: 239/255, blue: 236/255) }
    private var iosMemberMuted: Color { Color(red: 168/255, green: 183/255, blue: 189/255) }

    private func iosPage(_ snapshot: NativeUiSnapshot, destination: NativeUiSnapshot.Destination) -> some View {
        NavigationView {
            Group {
                switch destination {
                case .connect: iosDashboard(snapshot)
                case .servers: iosServers(snapshot)
                case .plans:
                    ScrollView {
                        VStack(spacing: 18) {
                            iosMembership(snapshot)
                            Button(label(snapshot, "refresh")) { bridge.send(.refresh) }
                                .buttonStyle(.bordered).disabled(bridge.isPending(.refresh))
                        }.padding(18).frame(maxWidth: 700)
                            .frame(maxWidth: .infinity)
                    }
                case .account:
                    List {
                        Section { Text(sessionLabel(snapshot)) }
                            .listRowBackground(iosCard)
                        Section {
                            Button(label(snapshot, "preferences")) { bridge.send(.preferences) }
                            Button(label(snapshot, "help")) { bridge.send(.help) }
                        }.listRowBackground(iosCard)
                    }.listStyle(.insetGrouped)
                }
            }
            .background(iosPaper)
            .foregroundStyle(iosInk)
            .navigationTitle(label(snapshot, destination.rawValue))
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { NativeBrandLogo().frame(width: 110, height: 28) } }
        }.navigationViewStyle(.stack)
    }

    private func iosDashboard(_ snapshot: NativeUiSnapshot) -> some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 370 || sizeCategory.isAccessibilityCategory || sizeCategory == .extraExtraLarge || sizeCategory == .extraExtraExtraLarge
            ScrollView {
                VStack(spacing: 18) {
                    iosHero(snapshot, compact: compact)
                    iosMembership(snapshot)
                    iosTraffic(snapshot, compact: compact)
                    iosRoutes(snapshot)
                }
                .padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity)
            }
        }
    }

    private func iosHero(_ snapshot: NativeUiSnapshot, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 8) {
                Circle().fill(!snapshot.safeMode && snapshot.connectionState == .connected ? Color(red: 95/255, green: 155/255, blue: 122/255) : iosAccent).frame(width: 7, height: 7)
                Text(snapshot.safeMode ? label(snapshot, "disconnected") : statusLabel(snapshot)).font(.subheadline.weight(.medium))
            }
            if compact {
                VStack(alignment: .leading, spacing: 24) {
                    iosPower(snapshot).frame(maxWidth: .infinity)
                    iosConnectionCopy(snapshot)
                }
            } else {
                HStack(spacing: 24) { iosPower(snapshot); iosConnectionCopy(snapshot) }
            }
            returnRoutePicker(snapshot)
            Divider().overlay(iosAccent.opacity(0.1))
            Button { bridge.send(.navigate, payload: ["destination": "servers"]) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe").frame(width: 38, height: 38)
                        .background(iosBlue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.servers.first(where: { $0.id == snapshot.selectedServerId })?.name ?? label(snapshot, "selectServer")).font(.subheadline.weight(.semibold))
                        Text(label(snapshot, "servers")).font(.caption).foregroundStyle(iosMuted)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.forward").font(.caption)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if let feedback = bridge.feedback {
                Text(label(snapshot, feedback.rawValue)).font(.subheadline).foregroundStyle(iosMuted)
            }
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            NativeWorldMap().fill(iosMuted.opacity(0.075)).frame(width: 300, height: 150)
                .offset(x: 75, y: 35).accessibilityHidden(true).allowsHitTesting(false)
        }
        .background(iosCard).clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func iosConnectionCopy(_ snapshot: NativeUiSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(snapshot.safeMode || snapshot.connectionState == .disconnected ? label(snapshot, "connect") : statusLabel(snapshot))
                .font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            Text(label(snapshot, snapshot.safeMode ? "safeMode" : "selectServer"))
                .font(.caption).foregroundStyle(iosMuted).fixedSize(horizontal: false, vertical: true)
            if sizeCategory.isAccessibilityCategory {
                iosModePicker(snapshot).pickerStyle(.menu)
            } else {
                iosModePicker(snapshot).pickerStyle(.segmented)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func iosModePicker(_ snapshot: NativeUiSnapshot) -> some View {
        Picker(label(snapshot, "smartMode"), selection: Binding(
            get: { snapshot.mode }, set: { bridge.send(.setMode, payload: ["mode": $0.rawValue]) }
        )) {
            Text(label(snapshot, "smartMode")).tag(NativeUiSnapshot.ConnectionMode.rule)
            Text(label(snapshot, "globalMode")).tag(NativeUiSnapshot.ConnectionMode.global)
        }
        .labelsHidden()
        .disabled(!canManageConnectionSettings(snapshot) || bridge.isPending(.setMode))
    }

    private func iosPower(_ snapshot: NativeUiSnapshot) -> some View {
        let connected = !snapshot.safeMode && snapshot.connectionState == .connected
        return ZStack {
            Circle().stroke(iosAccent.opacity(0.10), lineWidth: 1).frame(width: 124, height: 124)
            Circle().stroke(iosAccent.opacity(0.18), lineWidth: 1).frame(width: 108, height: 108)
            Button { bridge.send(connected ? .disconnect : .connect) } label: {
                Image(systemName: "power").font(.system(size: 32, weight: .light))
                    .foregroundStyle(connected ? iosPaper : iosAccent).frame(width: 92, height: 92)
                    .background(connected ? iosAccent : iosBlue, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(label(snapshot, connected ? "disconnect" : "connect")))
            .disabled(!canToggleConnection(snapshot) || bridge.isPending(.connect) || bridge.isPending(.disconnect))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: connected)
        }.frame(width: 124, height: 124)
    }

    private func iosMembership(_ snapshot: NativeUiSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(label(snapshot, "currentPlan")).font(.caption.weight(.semibold)).foregroundStyle(iosMemberMuted)
            Text(snapshot.planName ?? label(snapshot, "noPlan")).font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                Text(NativeByteText.format(snapshot.usage.usedBytes, locale: snapshot.locale)).font(.largeTitle.weight(.semibold)).monospacedDigit()
                Text("/ " + NativeByteText.format(snapshot.usage.totalBytes, locale: snapshot.locale)).font(.subheadline).foregroundStyle(iosMemberMuted)
                if snapshot.usage.usedBytes != nil, let total = snapshot.usage.totalBytes, total > 0 {
                    ProgressView(value: usageFraction(snapshot)).tint(Color(red: 171/255, green: 199/255, blue: 214/255))
                        .accessibilityLabel(Text(label(snapshot, "trafficUsed")))
                }
                Text(label(snapshot, "trafficUsed")).font(.caption).foregroundStyle(iosMemberMuted)
            }
            if let expiry = snapshot.planExpiresAt {
                Label(Date(timeIntervalSince1970: Double(expiry)).formatted(.dateTime.year().month().day().locale(Locale(identifier: snapshot.locale))), systemImage: "calendar")
                    .font(.caption).foregroundStyle(iosMemberMuted)
            }
            Button { bridge.send(.navigate, payload: ["destination": "plans"]) } label: {
                HStack { Text(label(snapshot, "plans")); Spacer(); Image(systemName: "arrow.right") }
                    .font(.subheadline.weight(.semibold)).padding(.horizontal, 16).frame(minHeight: 44)
                    .background(iosMemberInk.opacity(0.09), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }.buttonStyle(.plain)
        }
        .padding(26).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(iosMemberInk)
        .background(alignment: .topTrailing) {
            Circle().fill(Color.white.opacity(0.035)).frame(width: 240, height: 240).offset(x: 90, y: -100)
                .accessibilityHidden(true).allowsHitTesting(false)
        }
        .background(Color(red: 32/255, green: 44/255, blue: 51/255))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func iosTraffic(_ snapshot: NativeUiSnapshot, compact: Bool) -> some View {
        VStack(spacing: 12) {
            iosStat(snapshot, title: "trafficRemaining", value: iosRemaining(snapshot), symbol: "chart.bar")
            if compact {
                iosStat(snapshot, title: "upload", value: speed(snapshot.traffic.uploadBps, locale: snapshot.locale), symbol: "arrow.up")
                iosStat(snapshot, title: "download", value: speed(snapshot.traffic.downloadBps, locale: snapshot.locale), symbol: "arrow.down")
            } else {
                HStack(spacing: 12) {
                    iosStat(snapshot, title: "upload", value: speed(snapshot.traffic.uploadBps, locale: snapshot.locale), symbol: "arrow.up")
                    iosStat(snapshot, title: "download", value: speed(snapshot.traffic.downloadBps, locale: snapshot.locale), symbol: "arrow.down")
                }
            }
        }
    }

    private func iosStat(_ snapshot: NativeUiSnapshot, title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(label(snapshot, title), systemImage: symbol).font(.caption).foregroundStyle(iosMuted)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit().fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(iosCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityElement(children: .combine)
    }

    private func iosRemaining(_ snapshot: NativeUiSnapshot) -> String {
        guard let used = snapshot.usage.usedBytes, let total = snapshot.usage.totalBytes else { return "—" }
        return NativeByteText.format(max(0, total - used), locale: snapshot.locale)
    }

    private func iosRoutes(_ snapshot: NativeUiSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { bridge.send(.navigate, payload: ["destination": "servers"]) } label: {
                HStack { Text(label(snapshot, "servers")).font(.headline); Spacer(); Image(systemName: "chevron.forward").font(.caption) }.frame(minHeight: 44)
            }.buttonStyle(.plain)
            if snapshot.servers.isEmpty { Text(label(snapshot, "noServers")).font(.subheadline).foregroundStyle(iosMuted).padding(.vertical, 16) }
            ForEach(Array(snapshot.servers.prefix(3))) { server in
                Divider()
                iosServerRow(snapshot, server: server).padding(.vertical, 6)
            }
        }.padding(20).background(iosCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func iosServers(_ snapshot: NativeUiSnapshot) -> some View {
        List(snapshot.servers) { server in
            iosServerRow(snapshot, server: server).listRowBackground(iosCard)
        }
        .listStyle(.insetGrouped)
        .overlay { if snapshot.servers.isEmpty { Text(label(snapshot, "noServers")).foregroundStyle(iosMuted) } }
    }

    private func iosServerRow(_ snapshot: NativeUiSnapshot, server: NativeUiSnapshot.Server) -> some View {
        Button { bridge.send(.selectServer, payload: ["serverId": server.id]) } label: {
            HStack(spacing: 12) {
                Image(systemName: "globe").foregroundStyle(iosAccent).frame(width: 36, height: 36)
                    .background(iosBlue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(server.name).font(.subheadline.weight(.medium)).foregroundStyle(iosInk)
                    Text(server.latencyMs.map { latencyText($0, locale: snapshot.locale) } ?? "—").font(.caption).foregroundStyle(iosMuted)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: server.id == snapshot.selectedServerId ? "checkmark.circle.fill" : "circle").foregroundStyle(iosAccent)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(server.id == snapshot.selectedServerId ? [.isSelected] : [])
        .disabled(!server.available || !canManageConnectionSettings(snapshot) || bridge.isPending(.selectServer))
    }
    #endif

    #if os(macOS)
    private var paper: Color { colorScheme == .dark ? Color(red: 21/255, green: 30/255, blue: 36/255) : Color(red: 243/255, green: 241/255, blue: 235/255) }
    private var card: Color { colorScheme == .dark ? Color(red: 32/255, green: 44/255, blue: 51/255) : Color(red: 250/255, green: 249/255, blue: 245/255) }
    private var ink: Color { colorScheme == .dark ? Color(red: 233/255, green: 239/255, blue: 236/255) : Color(red: 40/255, green: 54/255, blue: 62/255) }
    private var muted: Color { colorScheme == .dark ? Color(red: 168/255, green: 183/255, blue: 189/255) : Color(red: 83/255, green: 99/255, blue: 107/255) }
    private var accent: Color { colorScheme == .dark ? Color(red: 171/255, green: 199/255, blue: 214/255) : Color(red: 80/255, green: 106/255, blue: 122/255) }

    private var membership: Color { Color(red: 32/255, green: 44/255, blue: 51/255) }
    private var onMembership: Color { Color(red: 233/255, green: 239/255, blue: 236/255) }
    private var membershipMuted: Color { Color(red: 168/255, green: 183/255, blue: 189/255) }
    private var blue: Color { colorScheme == .dark ? Color(red: 43/255, green: 59/255, blue: 70/255) : Color(red: 220/255, green: 229/255, blue: 237/255) }

    private func macConnection(_ snapshot: NativeUiSnapshot) -> some View {
        GeometryReader { geometry in
            let width = min(1240, max(0, geometry.size.width - 60))
            let stacked = width < 820
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if stacked {
                        connectionHero(snapshot, compact: width < 480)
                        membershipCard(snapshot)
                    } else {
                        HStack(alignment: .top, spacing: 18) {
                            connectionHero(snapshot, compact: false).frame(width: (width - 18) * 1.35 / 2.35)
                            membershipCard(snapshot).frame(width: (width - 18) / 2.35)
                        }
                    }
                    if width < 480 {
                        stat(snapshot, title: "trafficRemaining", value: remainingText(snapshot), symbol: "chart.bar", wash: Color(red: 228/255, green: 223/255, blue: 235/255))
                        HStack(spacing: 14) {
                            stat(snapshot, title: "upload", value: speed(snapshot.traffic.uploadBps, locale: snapshot.locale), symbol: "arrow.up", wash: blue)
                            stat(snapshot, title: "download", value: speed(snapshot.traffic.downloadBps, locale: snapshot.locale), symbol: "arrow.down", wash: blue)
                        }
                    } else {
                        HStack(spacing: 14) {
                            stat(snapshot, title: "trafficRemaining", value: remainingText(snapshot), symbol: "chart.bar", wash: Color(red: 228/255, green: 223/255, blue: 235/255))
                            stat(snapshot, title: "upload", value: speed(snapshot.traffic.uploadBps, locale: snapshot.locale), symbol: "arrow.up", wash: blue)
                            stat(snapshot, title: "download", value: speed(snapshot.traffic.downloadBps, locale: snapshot.locale), symbol: "arrow.down", wash: blue)
                        }
                    }
                    routeList(snapshot)
                }
                .frame(width: width, alignment: .leading)
                .padding(30)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(paper)
            .foregroundStyle(ink)
            .tint(accent)
        }
    }

    private func connectionHero(_ snapshot: NativeUiSnapshot, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle().fill(snapshot.safeMode || snapshot.connectionState != .connected ? accent : Color(red: 95/255, green: 155/255, blue: 122/255)).frame(width: 7, height: 7)
                Text(snapshot.safeMode ? label(snapshot, "disconnected") : statusLabel(snapshot)).font(.system(size: 12, weight: .medium))
            }
            HStack(spacing: compact ? 16 : 26) {
                powerButton(snapshot)
                VStack(alignment: .leading, spacing: 12) {
                    Text(snapshot.safeMode || snapshot.connectionState == .disconnected ? label(snapshot, "connect") : statusLabel(snapshot))
                        .font(.system(size: 20, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(label(snapshot, snapshot.safeMode ? "safeMode" : "selectServer"))
                        .font(.system(size: 12)).foregroundStyle(muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if !compact {
                        macModePicker(snapshot).frame(maxWidth: 190)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 27)
            if compact {
                macModePicker(snapshot)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
            }
            returnRoutePicker(snapshot)
            Rectangle().fill(accent.opacity(0.15)).frame(height: 1)
            HStack(spacing: 12) {
                Button { bridge.send(.navigate, payload: ["destination": "servers"]) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "globe").font(.system(size: 16)).frame(width: 32, height: 32)
                            .foregroundStyle(accent).background(blue, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(snapshot.servers.first(where: { $0.id == snapshot.selectedServerId })?.name ?? label(snapshot, "selectServer"))
                                .font(.system(size: 12, weight: .semibold)).lineLimit(2)
                            Text(label(snapshot, "servers")).font(.system(size: 11)).foregroundStyle(muted)
                        }
                        Image(systemName: "chevron.forward").font(.system(size: 11)).foregroundStyle(muted)
                    }
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                if !compact {
                    VStack(alignment: .trailing, spacing: 6) {
                        Label(speed(snapshot.traffic.uploadBps, locale: snapshot.locale), systemImage: "arrow.up")
                            .accessibilityLabel(Text(label(snapshot, "upload")))
                        Label(speed(snapshot.traffic.downloadBps, locale: snapshot.locale), systemImage: "arrow.down")
                            .accessibilityLabel(Text(label(snapshot, "download")))
                    }.font(.system(size: 11)).foregroundStyle(muted)
                }
            }.padding(.top, 18)
            if let feedback = bridge.feedback {
                Text(label(snapshot, feedback.rawValue)).font(.system(size: 12)).foregroundStyle(muted).padding(.top, 12)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 288, alignment: .topLeading)
        .background(alignment: .topTrailing) {
            NativeWorldMap().fill(muted.opacity(0.11)).frame(width: compact ? 240 : 360, height: compact ? 120 : 180)
                .offset(x: 12, y: 28).accessibilityHidden(true).allowsHitTesting(false)
        }
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func macModePicker(_ snapshot: NativeUiSnapshot) -> some View {
        Picker(label(snapshot, "smartMode"), selection: Binding(
            get: { snapshot.mode }, set: { bridge.send(.setMode, payload: ["mode": $0.rawValue]) }
        )) {
            Text(label(snapshot, "smartMode")).tag(NativeUiSnapshot.ConnectionMode.rule)
            Text(label(snapshot, "globalMode")).tag(NativeUiSnapshot.ConnectionMode.global)
        }
        .labelsHidden().pickerStyle(.segmented)
        .disabled(!canManageConnectionSettings(snapshot) || bridge.isPending(.setMode))
    }

    private func powerButton(_ snapshot: NativeUiSnapshot) -> some View {
        let connected = !snapshot.safeMode && snapshot.connectionState == .connected
        let action = connected ? "disconnect" : "connect"
        return ZStack {
            Circle().stroke(ink.opacity(0.07), lineWidth: 1).frame(width: 126, height: 126)
            Circle().stroke(ink.opacity(0.10), lineWidth: 1).frame(width: 100, height: 100)
            Button { bridge.send(connected ? .disconnect : .connect) } label: {
                Image(systemName: "power").font(.system(size: 30, weight: .light))
                    .foregroundStyle(connected ? paper : accent)
                    .frame(width: 80, height: 80)
                    .background(connected ? accent : blue, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(label(snapshot, action)))
            .help(label(snapshot, action))
            .disabled(!canToggleConnection(snapshot) || bridge.isPending(.connect) || bridge.isPending(.disconnect))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: connected)
        }.frame(width: 108, height: 108)
    }

    private func membershipCard(_ snapshot: NativeUiSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label(snapshot, "currentPlan")).font(.system(size: 11, weight: .semibold)).tracking(1.8).foregroundStyle(membershipMuted)
            Text(snapshot.planName ?? label(snapshot, "noPlan")).font(.system(size: 22, weight: .medium))
                .lineLimit(2).padding(.top, 18)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(NativeByteText.format(snapshot.usage.usedBytes, locale: snapshot.locale)).font(.system(size: 30, weight: .medium)).monospacedDigit()
                Text("/ " + NativeByteText.format(snapshot.usage.totalBytes, locale: snapshot.locale)).font(.system(size: 12)).foregroundStyle(membershipMuted)
            }.padding(.top, 24)
            if snapshot.usage.usedBytes != nil, let total = snapshot.usage.totalBytes, total > 0 {
                GeometryReader { size in
                    ZStack(alignment: .leading) {
                        Capsule().fill(onMembership.opacity(0.15))
                        Capsule().fill(Color(red: 171/255, green: 199/255, blue: 214/255)).frame(width: size.size.width * usageFraction(snapshot))
                    }
                }.frame(height: 5).padding(.top, 12)
            }
            Text(label(snapshot, "trafficUsed")).font(.system(size: 11)).foregroundStyle(membershipMuted).padding(.top, 10)
            Spacer(minLength: 24)
            HStack {
                if let expiry = snapshot.planExpiresAt {
                    Label(Date(timeIntervalSince1970: Double(expiry)).formatted(.dateTime.year().month().day().locale(Locale(identifier: snapshot.locale))), systemImage: "calendar")
                        .font(.system(size: 11)).foregroundStyle(membershipMuted)
                }
                Spacer(minLength: 8)
                Button { bridge.send(.navigate, payload: ["destination": "plans"]) } label: {
                    HStack(spacing: 10) { Text(label(snapshot, "plans")); Image(systemName: "arrow.right") }
                        .font(.system(size: 12, weight: .medium)).padding(.horizontal, 16).padding(.vertical, 10)
                        .background(onMembership.opacity(0.09), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }.buttonStyle(.plain)
            }
        }
        .padding(25).frame(maxWidth: .infinity, minHeight: 288, maxHeight: 288, alignment: .topLeading)
        .foregroundStyle(onMembership)
        .background(alignment: .topTrailing) {
            ZStack {
                ForEach(0..<3) { index in
                    Circle().fill(Color.white.opacity(0.025 + Double(index) * 0.005))
                        .frame(width: CGFloat(350 - index * 80), height: CGFloat(350 - index * 80))
                }
            }.offset(x: 110, y: -125).accessibilityHidden(true).allowsHitTesting(false)
        }
        .background(membership).clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func stat(_ snapshot: NativeUiSnapshot, title: String, value: String, symbol: String, wash: Color) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text(label(snapshot, title)).font(.system(size: 11)).foregroundStyle(muted)
                Text(value).font(.system(size: 23, weight: .medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
            }
            Spacer(minLength: 0)
            Image(systemName: symbol).font(.system(size: 16)).foregroundStyle(accent)
                .frame(width: 36, height: 36)
                .background(colorScheme == .dark ? blue : wash, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, 21).padding(.vertical, 19).frame(maxWidth: .infinity, minHeight: 95)
        .background(card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func routeList(_ snapshot: NativeUiSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { bridge.send(.navigate, payload: ["destination": "servers"]) } label: {
                HStack { Text(label(snapshot, "servers")).font(.system(size: 14, weight: .semibold)); Spacer(); Image(systemName: "chevron.forward").foregroundStyle(accent) }
                    .padding(.bottom, 20).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if snapshot.servers.isEmpty {
                Text(label(snapshot, "noServers")).font(.system(size: 12)).foregroundStyle(muted).padding(.vertical, 18)
            }
            ForEach(Array(snapshot.servers.prefix(3))) { server in
                Rectangle().fill(accent.opacity(0.12)).frame(height: 1)
                Button { bridge.send(.selectServer, payload: ["serverId": server.id]) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "globe").font(.system(size: 16)).foregroundStyle(accent).frame(width: 34, height: 34)
                            .background(blue, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text(server.name).font(.system(size: 12, weight: .medium)).frame(maxWidth: .infinity, alignment: .leading)
                        Text(server.latencyMs.map { latencyText($0, locale: snapshot.locale) } ?? "—").font(.system(size: 11)).foregroundStyle(muted)
                        Image(systemName: server.id == snapshot.selectedServerId ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(accent).frame(width: 18)
                    }.padding(.vertical, 16).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!server.available || !canManageConnectionSettings(snapshot) || bridge.isPending(.selectServer))
            }
        }.padding(24).background(card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func remainingText(_ snapshot: NativeUiSnapshot) -> String {
        guard let used = snapshot.usage.usedBytes, let total = snapshot.usage.totalBytes else { return "—" }
        return NativeByteText.format(max(0, total - used), locale: snapshot.locale)
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
            returnRoutePicker(snapshot)
            traffic(snapshot)
            if let feedback = bridge.feedback {
                Text(label(snapshot, feedback.rawValue))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .navigationTitle(label(snapshot, "connect"))
    }

    @ViewBuilder private func returnRoutePicker(_ snapshot: NativeUiSnapshot) -> some View {
        if let route = snapshot.returnRoute {
            Picker(route.title, selection: Binding<String?>(
                get: { route.selectedId },
                set: { optionId in
                    guard let optionId else { return }
                    bridge.send(.selectReturnRoute, payload: ["optionId": optionId])
                }
            )) {
                if route.selectedId == nil { Text("—").tag(nil as String?) }
                ForEach(route.options) { option in
                    Text(option.label).tag(Optional(option.id))
                }
            }
            .disabled(!route.enabled || bridge.hasPendingCommand)
        }
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

#if os(macOS) || os(iOS)
private struct NativeWorldMap: Shape {
    private static let polygons: [[CGPoint]] = [
        [(75, 93), (135, 45), (245, 49), (315, 105), (270, 157), (205, 167), (182, 220), (132, 178)],
        [(232, 235), (295, 246), (340, 306), (300, 408), (274, 440), (252, 355)],
        [(420, 104), (475, 65), (545, 77), (565, 130), (527, 167), (459, 162)],
        [(455, 183), (527, 170), (574, 238), (554, 320), (507, 358), (467, 295), (438, 222)],
        [(560, 85), (665, 51), (820, 67), (934, 139), (881, 190), (797, 177), (751, 246), (690, 211), (639, 173), (574, 163)],
        [(706, 245), (748, 243), (778, 293), (822, 307), (833, 336), (782, 326), (740, 279)],
        [(807, 355), (865, 326), (912, 358), (913, 407), (854, 428), (817, 397)],
    ].map { $0.map { CGPoint(x: $0.0, y: $0.1) } }

    private static let dots: Path = {
        var path = Path()
        for y in stride(from: 45.0, to: 455.0, by: 11) {
            for x in stride(from: 55.0, to: 955.0, by: 11) where polygons.contains(where: { inside(CGPoint(x: x, y: y), polygon: $0) }) {
                path.addEllipse(in: CGRect(x: x - 2.1, y: y - 2.1, width: 4.2, height: 4.2))
            }
        }
        return path
    }()

    private static func inside(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
        var result = false
        var previous = polygon.last!
        for current in polygon {
            if (current.y > point.y) != (previous.y > point.y),
               point.x < (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y) + current.x {
                result.toggle()
            }
            previous = current
        }
        return result
    }

    func path(in rect: CGRect) -> Path {
        Self.dots.applying(CGAffineTransform(scaleX: rect.width / 1000, y: rect.height / 500))
    }
}
#endif
