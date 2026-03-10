import AppKit
import CoreGraphics

// MARK: - HotkeyManager
//
// Registers a global Cmd+Shift+V hotkey using a CGEventTap.
// Requires Accessibility permission (System Settings → Privacy → Accessibility).
//
// If permission hasn't been granted yet at launch, the manager polls
// AXIsProcessTrusted() every 2 seconds and automatically creates the
// event tap as soon as the user enables access — no relaunch required.

final class HotkeyManager {
    private static var onHotkey: (() -> Void)?
    /// Stored statically so the C-style CGEventTapCallBack can reach it
    /// without capturing state (C callbacks cannot close over Swift values).
    private static var activeTap: CFMachPort?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var permissionTimer: Timer?

    private static let kVK_ANSI_V: Int64 = 9

    func register(action: @escaping () -> Void) {
        HotkeyManager.onHotkey = action

        // Prompt the system permission dialog (shown only once by macOS)
        promptAccessibility()

        // Attempt to create the tap immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.attemptSetup()
        }
    }

    deinit {
        permissionTimer?.invalidate()
        removeEventTap()
    }

    // MARK: Private – Setup with retry

    private func attemptSetup() {
        // Already have a working tap — nothing to do
        if eventTap != nil { return }

        if AXIsProcessTrusted() {
            // Permission granted — create the tap
            if createEventTap() {
                // Success — stop polling if we were
                permissionTimer?.invalidate()
                permissionTimer = nil
            }
        } else {
            // Not yet trusted — start polling if we aren't already
            startPermissionPolling()
        }
    }

    private func startPermissionPolling() {
        guard permissionTimer == nil else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if AXIsProcessTrusted() {
                if self.createEventTap() {
                    self.permissionTimer?.invalidate()
                    self.permissionTimer = nil
                }
            }
        }
        // Ensure the timer fires even during UI tracking (e.g. menu open)
        RunLoop.main.add(timer, forMode: .common)
        permissionTimer = timer
    }

    // MARK: Private – Permissions

    private func promptAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: Private – Event tap creation

    @discardableResult
    private func createEventTap() -> Bool {
        removeEventTap()

        let mask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue)
        )

        // Note: CGEventTapCallBack is a C function type — it cannot capture
        // Swift variables. All shared state must go through static properties.
        let callback: CGEventTapCallBack = { _, type, event, _ -> Unmanaged<CGEvent>? in

            // Re-enable the tap if macOS disabled it due to timeout.
            // We access the tap through the static property instead of refcon
            // so there is no ambiguity about which tap to re-enable.
            if type == .tapDisabledByTimeout {
                if let tap = HotkeyManager.activeTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            let code  = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // Cmd + Shift + V (no other modifiers)
            let wantedFlags: CGEventFlags = [.maskCommand, .maskShift]
            let extraFlags: CGEventFlags  = [.maskAlternate, .maskControl, .maskSecondaryFn]

            if code == HotkeyManager.kVK_ANSI_V &&
               flags.intersection(wantedFlags) == wantedFlags &&
               flags.intersection(extraFlags).isEmpty {
                DispatchQueue.main.async { HotkeyManager.onHotkey?() }
                return nil  // Consume the event
            }

            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: nil
        ) else {
            return false
        }

        // Publish the tap before enabling it so any immediate tapDisabledByTimeout
        // event (extremely rare at creation time) still finds a valid reference.
        HotkeyManager.activeTap = tap

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = src
        return true
    }

    private func removeEventTap() {
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        HotkeyManager.activeTap = nil
    }
}
