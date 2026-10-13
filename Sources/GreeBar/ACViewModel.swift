import Foundation
import GreeKit
import Observation
import ServiceManagement

@MainActor
@Observable
final class ACViewModel {
    enum Phase: Equatable {
        case idle, discovering, connecting, connected, failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var state = DeviceState()
    private(set) var info: DeviceInfo?
    private(set) var discovered: [DeviceInfo] = []
    private(set) var lastUpdate: Date?
    private(set) var isBusy = false

    var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet { updateLoginItem() }
    }

    private var device: GreeDevice?
    private var pollTask: Task<Void, Never>?
    private var pendingRefresh: Task<Void, Never>?
    private let defaults = UserDefaults.standard

    init() {
        if let data = defaults.data(forKey: "device"),
           let saved = try? JSONDecoder().decode(DeviceInfo.self, from: data) {
            connect(to: saved, key: defaults.string(forKey: "deviceKey"))
        } else {
            Task { await discover(autoSelect: true) }
        }
    }

    // MARK: Connection

    func discover(autoSelect: Bool = false, host: String? = nil) async {
        phase = .discovering
        do {
            let found = try await GreeDiscovery.scan(hosts: host.map { [$0] })
            discovered = found
            if autoSelect || host != nil {
                let pick = found.first
                if let pick {
                    connect(to: pick, key: nil)
                    return
                }
            }
            phase = found.isEmpty ? .failed("No AC found. Check Local Network permission.") : (device == nil ? .idle : .connected)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func connect(to info: DeviceInfo, key: String?) {
        let reuseKey = key ?? (info.mac == self.info?.mac ? defaults.string(forKey: "deviceKey") : nil)
        if key == nil, reuseKey == nil { defaults.removeObject(forKey: "deviceKey") }
        self.info = info
        device = GreeDevice(info: info, key: reuseKey)
        defaults.set(try? JSONEncoder().encode(info), forKey: "device")
        phase = .connecting
        startPolling()
    }

    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    func refresh() async {
        guard let device else { return }
        do {
            let newState = try await device.status()
            state = newState
            lastUpdate = .now
            phase = .connected
            if let key = await device.key { defaults.set(key, forKey: "deviceKey") }
        } catch {
            // The unit may have a new DHCP address; try to find it again by MAC.
            if let info, let found = try? await GreeDiscovery.scan(), let same = found.first(where: { $0.mac == info.mac }),
               same.ip != info.ip {
                connect(to: same, key: await device.key)
                return
            }
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: Commands

    func set(_ values: [GreeProp: Int]) {
        guard let device else { return }
        for (prop, value) in values { state[prop] = value }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try await device.set(values)
                scheduleRefresh()
            } catch {
                phase = .failed(error.localizedDescription)
                await refresh()
            }
        }
    }

    /// Debounced status re-read after a command, so rapid +/- taps don't race.
    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }

    func setPower(_ on: Bool) { set([.power: on ? 1 : 0]) }

    func setTemperature(_ celsius: Int) {
        set([.targetTemp: min(30, max(16, celsius)), .tempUnit: 0, .tempRec: 0])
    }

    func setMode(_ mode: ACMode) { set([.mode: mode.rawValue]) }
    func setFan(_ fan: FanSpeed) { set([.fanSpeed: fan.rawValue]) }
    func setVerticalSwing(_ swing: VerticalSwing) { set([.swingVertical: swing.rawValue]) }
    func setHorizontalSwing(_ swing: HorizontalSwing) { set([.swingHorizontal: swing.rawValue]) }

    func toggle(_ prop: GreeProp) {
        let on = !state.flag(prop)
        switch prop {
        case .sleepSwitch:
            set([.sleepSwitch: on ? 1 : 0, .sleepMode: on ? 1 : 0])
        case .turbo where on:
            set([.turbo: 1, .quiet: 0])
        case .quiet where on:
            set([.quiet: 1, .turbo: 0])
        default:
            set([prop: on ? 1 : 0])
        }
    }

    // MARK: Login item

    private func updateLoginItem() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            phase = .failed("Launch at login: \(error.localizedDescription)")
        }
    }
}
