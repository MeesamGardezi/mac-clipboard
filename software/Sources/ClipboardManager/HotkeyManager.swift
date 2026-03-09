import AppKit
import CoreGraphics

// MARK: - HotkeyManager
//
// Registers a global Cmd+Shift+V hotkey using a CGEventTap.
// Requires Accessibility permission (System Settings → Privacy → Accessibility).
// The app prompts for this automatically on first launch.

final class HotkeyManager {
    /// Stored statically so it can be reached from the pure-C CGEventTap callback.
    private static var onHotkey: (() -> Void)?
    private var eventTap: CFMachPort?

    // kVK_ANSI_V = 9  (Carbon/HIToolbox key code, stable across keyboard layouts)
    private let kVK_ANSI_V: CGKeyCode = 9

    func register(action: @escaping () -> Void) {
        HotkeyManager.onHotkey = action
        requestAccessibilityPermission()
        createEventTap()
    }

    // MARK: Private

    private func requestAccessibilityPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options = [key: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func createEventTap() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        // NOTE: This is a C callback — no Swift closures, no captured self.
        let callback: CGEventTapCallBack = { _, type, event, _ -> Unmanaged<CGEvent>? in
            guard type == .keyDown else { return Unmanaged.passRetained(event) }

            let code  = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // Cmd + Shift + V  (no other modifiers)
            let wantedFlags: CGEventFlags = [.maskCommand, .maskShift]
            let extraFlags: CGEventFlags  = [.maskAlternate, .maskControl, .maskSecondaryFn]

            if code == 9 &&
               flags.intersection(wantedFlags) == wantedFlags &&
               flags.intersection(extraFlags).isEmpty {
                DispatchQueue.main.async { HotkeyManager.onHotkey?() }
                return nil  // Consume — don't let the system process Cmd+Shift+V
            }
            return Unmanaged.passRetained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: nil
        ) else {
            print("[HotkeyManager] Could not create event tap. " +
                  "Grant Accessibility access in System Settings → Privacy → Accessibility.")
            return
        }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
    }
}
