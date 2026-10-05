import Foundation
import IOKit.ps
import Testing
@testable import Eyelid

@Suite("Battery")
struct BatteryTests {
    /// What IOKit reports for a MacBook's internal battery, trimmed to the keys Eyelid reads.
    private func description(
        current: Int = 37,
        maximum: Int = 100,
        source: String = kIOPSBatteryPowerValue,
        isCharging: Bool = false,
        type: String = kIOPSInternalBatteryType
    ) -> [String: Any] {
        [
            kIOPSTypeKey: type,
            kIOPSCurrentCapacityKey: current,
            kIOPSMaxCapacityKey: maximum,
            kIOPSPowerSourceStateKey: source,
            kIOPSIsChargingKey: isCharging,
        ]
    }

    private func state(_ level: Int, pluggedIn: Bool = false) -> BatteryState {
        BatteryState(level: level, isPluggedIn: pluggedIn, isCharging: pluggedIn)
    }

    // MARK: Reading IOKit

    @Test func readsABatteryOnBatteryPower() throws {
        let state = try #require(BatteryState(description: description()))

        #expect(state == BatteryState(level: 37, isPluggedIn: false, isCharging: false))
    }

    @Test func readsAChargingBattery() throws {
        let state = try #require(BatteryState(description: description(current: 80, source: kIOPSACPowerValue, isCharging: true)))

        #expect(state == BatteryState(level: 80, isPluggedIn: true, isCharging: true))
    }

    @Test func pluggedInButNotChargingIsStillPluggedIn() throws {
        // Optimized Battery Charging can hold the battery at 80% while connected.
        let state = try #require(BatteryState(description: description(current: 80, source: kIOPSACPowerValue)))

        #expect(state.isPluggedIn)
        #expect(!state.isCharging)
    }

    @Test func scalesCapacityToPercent() throws {
        let state = try #require(BatteryState(description: description(current: 4_500, maximum: 5_000)))

        #expect(state.level == 90)
    }

    @Test func ignoresOtherPowerSources() {
        #expect(BatteryState(description: description(type: "UPS")) == nil)
    }

    @Test func ignoresIncompleteDescriptions() {
        var incomplete = description()
        incomplete[kIOPSCurrentCapacityKey] = nil

        #expect(BatteryState(description: incomplete) == nil)
        #expect(BatteryState(description: description(maximum: 0)) == nil)
    }

    // MARK: Events

    @Test func firstReadingIsNotAnEvent() {
        #expect(BatteryEvent.between(nil, and: state(50)) == nil)
    }

    @Test func pluggingInAndUnplugging() {
        #expect(BatteryEvent.between(state(50), and: state(50, pluggedIn: true)) == .pluggedIn(state(50, pluggedIn: true)))
        #expect(BatteryEvent.between(state(50, pluggedIn: true), and: state(50)) == .unplugged(state(50)))
    }

    @Test(arguments: [(21, 20), (11, 10), (25, 9)])
    func warnsWhenTheBatteryRunsLow(from old: Int, to new: Int) {
        #expect(BatteryEvent.between(state(old), and: state(new)) == .low(state(new)))
    }

    @Test(arguments: [(20, 19), (15, 14), (10, 9), (60, 59)])
    func warnsOnlyOncePerThreshold(from old: Int, to new: Int) {
        #expect(BatteryEvent.between(state(old), and: state(new)) == nil)
    }

    @Test func noLowWarningWhileOnPower() {
        #expect(BatteryEvent.between(state(21, pluggedIn: true), and: state(20, pluggedIn: true)) == nil)
    }

    @Test func chargingUpIsNotAnEvent() {
        #expect(BatteryEvent.between(state(9, pluggedIn: true), and: state(25, pluggedIn: true)) == nil)
    }
}
