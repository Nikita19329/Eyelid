import Testing
@testable import Eyelid

@MainActor
@Suite("Accessibility access for the HUD")
struct HUDAccessTests {
    /// Stands in for System Settings.
    final class Permission {
        var isGranted = false
        var requests = 0
    }

    /// Like the real tap, it only starts with access.
    final class FakeTap: KeyTap {
        let permission: Permission
        var isRunning = false

        init(permission: Permission) {
            self.permission = permission
        }

        func start() -> Bool {
            guard permission.isGranted else { return false }
            isRunning = true
            return true
        }

        func stop() {
            isRunning = false
        }
    }

    private let permission = Permission()
    private let tap: FakeTap
    private let hud: HUDService

    init() {
        let permission = permission
        let tap = FakeTap(permission: permission)
        self.tap = tap
        hud = HUDService(
            settings: AppSettings(defaults: InMemorySettingsStore()),
            access: AccessibilityAccess(
                isGranted: { permission.isGranted },
                request: { permission.requests += 1 }
            ),
            makeTap: { _ in tap }
        )
    }

    @Test func startsRightAwayWithAccess() {
        permission.isGranted = true

        hud.setEnabled(true)

        #expect(tap.isRunning)
        #expect(permission.requests == 0)
    }

    @Test func asksOnceAndStartsWhenAccessIsGranted() {
        hud.setEnabled(true)
        hud.setEnabled(false)
        hud.setEnabled(true)
        #expect(!tap.isRunning)
        #expect(permission.requests == 1)

        permission.isGranted = true
        hud.followAccess()

        #expect(tap.isRunning)
    }

    @Test func stopsAsSoonAsAccessIsTakenAway() {
        // A tap that has lost access stalls input across the Mac, so it must not stay.
        permission.isGranted = true
        hud.setEnabled(true)

        permission.isGranted = false
        hud.followAccess()

        #expect(!tap.isRunning)
        #expect(permission.requests == 0)
    }

    @Test func startsAgainWhenAccessComesBack() {
        permission.isGranted = true
        hud.setEnabled(true)
        permission.isGranted = false
        hud.followAccess()

        permission.isGranted = true
        hud.followAccess()

        #expect(tap.isRunning)
    }

    @Test func turningTheHUDOffStopsTheTap() {
        permission.isGranted = true
        hud.setEnabled(true)

        hud.setEnabled(false)

        #expect(!tap.isRunning)
    }
}
