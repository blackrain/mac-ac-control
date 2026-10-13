import Foundation

/// Status/command columns understood by Gree units.
public enum GreeProp: String, CaseIterable, Sendable, Codable {
    case power = "Pow"
    case mode = "Mod"
    case targetTemp = "SetTem"
    case tempUnit = "TemUn"
    case tempRec = "TemRec"
    case fanSpeed = "WdSpd"
    case freshAir = "Air"
    case xFan = "Blo"
    case health = "Health"
    case sleepSwitch = "SwhSlp"
    case sleepMode = "SlpMod"
    case light = "Lig"
    case swingHorizontal = "SwingLfRig"
    case swingVertical = "SwUpDn"
    case quiet = "Quiet"
    case turbo = "Tur"
    case energySaving = "SvSt"
    case steadyHeat = "StHt"
    case roomTemp = "TemSen"
}

public enum ACMode: Int, CaseIterable, Sendable, Identifiable {
    case auto = 0, cool = 1, dry = 2, fan = 3, heat = 4

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .auto: "Auto"
        case .cool: "Cool"
        case .dry: "Dry"
        case .fan: "Fan"
        case .heat: "Heat"
        }
    }

    public var symbol: String {
        switch self {
        case .auto: "arrow.triangle.2.circlepath"
        case .cool: "snowflake"
        case .dry: "drop"
        case .fan: "fan"
        case .heat: "sun.max"
        }
    }
}

public enum FanSpeed: Int, CaseIterable, Sendable, Identifiable {
    case auto = 0, low = 1, mediumLow = 2, medium = 3, mediumHigh = 4, high = 5

    public var id: Int { rawValue }

    public var label: String {
        self == .auto ? "Auto" : "\(rawValue)"
    }
}

public enum VerticalSwing: Int, CaseIterable, Sendable, Identifiable {
    case `default` = 0, full = 1
    case fixedTop = 2, fixedUpperMiddle = 3, fixedMiddle = 4, fixedLowerMiddle = 5, fixedBottom = 6
    case swingBottom = 7, swingLowerMiddle = 8, swingMiddle = 9, swingUpperMiddle = 10, swingTop = 11

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .default: "Off"
        case .full: "Full swing"
        case .fixedTop: "Fixed: top"
        case .fixedUpperMiddle: "Fixed: upper-middle"
        case .fixedMiddle: "Fixed: middle"
        case .fixedLowerMiddle: "Fixed: lower-middle"
        case .fixedBottom: "Fixed: bottom"
        case .swingBottom: "Swing: bottom"
        case .swingLowerMiddle: "Swing: lower-middle"
        case .swingMiddle: "Swing: middle"
        case .swingUpperMiddle: "Swing: upper-middle"
        case .swingTop: "Swing: top"
        }
    }
}

public enum HorizontalSwing: Int, CaseIterable, Sendable, Identifiable {
    case `default` = 0, full = 1, left = 2, leftCenter = 3, center = 4, rightCenter = 5, right = 6

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .default: "Off"
        case .full: "Full swing"
        case .left: "Left"
        case .leftCenter: "Left-center"
        case .center: "Center"
        case .rightCenter: "Right-center"
        case .right: "Right"
        }
    }
}

/// Snapshot of the unit's state as reported by a status request.
public struct DeviceState: Sendable, Equatable {
    public var values: [GreeProp: Int]

    public init(values: [GreeProp: Int] = [:]) {
        self.values = values
    }

    /// Builds the state from a `dat` reply. Unknown or non-integer columns are skipped.
    public init(cols: [String], dat: [Any]) {
        var values: [GreeProp: Int] = [:]
        for (col, raw) in zip(cols, dat) {
            guard let prop = GreeProp(rawValue: col) else { continue }
            if let n = raw as? Int {
                values[prop] = n
            } else if let s = raw as? String, let n = Int(s) {
                values[prop] = n
            }
        }
        self.values = values
    }

    public subscript(prop: GreeProp) -> Int? {
        get { values[prop] }
        set { values[prop] = newValue }
    }

    public func flag(_ prop: GreeProp) -> Bool { (values[prop] ?? 0) != 0 }

    public var power: Bool { flag(.power) }
    public var mode: ACMode { ACMode(rawValue: values[.mode] ?? 0) ?? .auto }
    public var targetTemp: Int? { values[.targetTemp] }
    public var fanSpeed: FanSpeed { FanSpeed(rawValue: values[.fanSpeed] ?? 0) ?? .auto }
    public var verticalSwing: VerticalSwing { VerticalSwing(rawValue: values[.swingVertical] ?? 0) ?? .default }
    public var horizontalSwing: HorizontalSwing { HorizontalSwing(rawValue: values[.swingHorizontal] ?? 0) ?? .default }

    /// Indoor temperature in °C. Most firmware reports °C + 40; some report raw °C; 0 means no sensor.
    public var roomTemp: Int? {
        guard let raw = values[.roomTemp], raw != 0 else { return nil }
        return Self.normalizeRoomTemp(raw)
    }

    static func normalizeRoomTemp(_ raw: Int) -> Int {
        raw > 40 ? raw - 40 : raw
    }
}
