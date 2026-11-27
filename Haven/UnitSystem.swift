import Foundation
import SwiftUI

// MARK: - Unit System Enum

enum UnitSystem: String, CaseIterable {
    case imperial = "imperial"
    case metric   = "metric"

    static var deviceDefault: UnitSystem {
        let usesMetric = Locale.current.measurementSystem == .metric
        return usesMetric ? .metric : .imperial
    }
}

// MARK: - Unit Formatter

struct UnitFormatter {

    let system: UnitSystem

    // MARK: Weight (stored as lbs)

    func displayWeight(_ lbs: Double) -> String {
        switch system {
        case .imperial:
            return String(format: "%.1f lbs", lbs)
        case .metric:
            return String(format: "%.1f kg", lbs * 0.453592)
        }
    }

    func displayWeightInt(_ lbs: Double) -> String {
        switch system {
        case .imperial:
            return "\(Int(lbs)) lbs"
        case .metric:
            return "\(Int((lbs * 0.453592).rounded())) kg"
        }
    }

    func weightValue(_ lbs: Double) -> Double {
        switch system {
        case .imperial: return lbs
        case .metric:   return (lbs * 0.453592 * 10).rounded() / 10
        }
    }

    /// Convert display value back to lbs for storage.
    func toLbs(_ displayValue: Double) -> Double {
        switch system {
        case .imperial: return displayValue
        case .metric:   return displayValue / 0.453592
        }
    }

    // BUG-B: Convert stored lbs value to display value in current unit
    func fromLbs(_ lbs: Double) -> Double {
        switch system {
        case .imperial: return lbs
        case .metric:   return (lbs * 0.453592 * 10).rounded() / 10
        }
    }

    // MARK: Distance (stored as miles)

    func displayDistance(_ miles: Double) -> String {
        switch system {
        case .imperial:
            return String(format: "%.2f mi", miles)
        case .metric:
            return String(format: "%.2f km", miles * 1.60934)
        }
    }

    func distanceValue(_ miles: Double) -> Double {
        switch system {
        case .imperial: return miles
        case .metric:   return (miles * 1.60934 * 100).rounded() / 100
        }
    }

    func toMiles(_ displayValue: Double) -> Double {
        switch system {
        case .imperial: return displayValue
        case .metric:   return displayValue / 1.60934
        }
    }

    // MARK: Pace (stored as min/mile)

    func displayPace(_ minPerMile: Double) -> String {
        switch system {
        case .imperial:
            let min = Int(minPerMile)
            let sec = Int((minPerMile - Double(min)) * 60)
            return String(format: "%d:%02d /mi", min, sec)
        case .metric:
            let minPerKm = minPerMile / 1.60934
            let min = Int(minPerKm)
            let sec = Int((minPerKm - Double(min)) * 60)
            return String(format: "%d:%02d /km", min, sec)
        }
    }

    // MARK: Height (stored as inches)

    func displayHeight(_ inches: Double) -> String {
        switch system {
        case .imperial:
            let ft = Int(inches) / 12
            let remainingIn = Int(inches) % 12
            return "\(ft)'\(remainingIn)\""
        case .metric:
            return String(format: "%.0f cm", inches * 2.54)
        }
    }

    // MARK: Volume (stored as lbs × reps)

    func displayVolume(_ lbs: Double) -> String {
        switch system {
        case .imperial:
            return "\(Int(lbs).formatted()) lbs"
        case .metric:
            return "\(Int((lbs * 0.453592).rounded()).formatted()) kg"
        }
    }

    // MARK: Unit Labels

    var weightUnit: String       { system == .imperial ? "lbs" : "kg" }
    var distanceUnit: String     { system == .imperial ? "mi"  : "km" }
    var paceUnit: String         { system == .imperial ? "/mi" : "/km" }
    var heightUnit: String       { system == .imperial ? "ft/in" : "cm" }

    // MARK: Stepper Increment (weight)

    /// Imperial: 5 lbs, Metric: 2.5 kg
    var weightIncrement: Double  { system == .imperial ? 5.0 : 2.5 }

    /// The increment expressed in lbs (for storage layer).
    var weightIncrementInLbs: Double { system == .imperial ? 5.0 : 2.5 / 0.453592 }

    // MARK: Stepper Label
    // BUG-A: Always show clean display values (5 for imperial, 2.5 for metric)
    // Never convert lbs→kg for the label — just show the natural increment for the system.
    func incrementLabel(_ increment: Double) -> String {
        // increment is in lbs from ExerciseDefinition — we ignore the exact value
        // and just show the natural increment for the selected unit system
        switch system {
        case .imperial:
            // Round to nearest whole number for clean display
            let val = increment.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(increment))
                : String(format: "%.1f", increment)
            return val
        case .metric:
            // Always show 2.5 for metric (standard plate pair)
            return "2.5"
        }
    }
}

// MARK: - Environment Key

private struct UnitFormatterKey: EnvironmentKey {
    static let defaultValue = UnitFormatter(system: UnitSystem.deviceDefault)
}

extension EnvironmentValues {
    var unitFormatter: UnitFormatter {
        get { self[UnitFormatterKey.self] }
        set { self[UnitFormatterKey.self] = newValue }
    }
}