import AppKit
import CoreGraphics

// MARK: - SnipTool
//
// Displays a full-screen semi-transparent overlay.
// The user drags to select a region; on mouse-up the region is captured
// via CGWindowListCreateImage and passed to the completion handler.
//
// Permissions required (macOS 10.15+):
//   Screen Recording — System Settings → Privacy & Security → Screen Recording
//   The OS prompts automatically on first capture attempt.

final class SnipTool {
    var onCapture: ((NSImage) -> Void)?
    private var overlayWindows: [SnipOverlayWindow] = []

    func start(completion: @escaping (NSImage) -> Void) {
        onCapture = completion
        DispatchQueue.main.async { self.showOverlay() }
    }

    private func showOverlay() {
        // Create one overlay window per screen so the user can snip any display
        for screen in NSScreen.screens {
            let win = SnipOverlayWindow(screen: screen)
            win.snipTool = self
            overlayWindows.append(win)
            win.makeKeyAndOrderFront(nil)
        }
        NSCursor.crosshair.set()
    }

    /// Called by SnipOverlayWindow when the user finishes a drag.
    /// `rectInScreen` is in AppKit screen coordinates (origin: bottom-left).
    func captureRegion(_ rectInScreen: CGRect) {
        dismissOverlay()

        // Normalise (handle any drag direction)
        let normalised = CGRect(
            x: min(rectInScreen.minX, rectInScreen.maxX),
            y: min(rectInScreen.minY, rectInScreen.maxY),
            width: abs(rectInScreen.width),
            height: abs(rectInScreen.height)
        )
        guard normalised.width > 5, normalised.height > 5 else { return }

        // Wait a frame for the overlay to fully disappear before capturing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.performCapture(appKitRect: normalised)
        }
    }

    func cancel() {
        dismissOverlay()
    }

    // MARK: Private

    private func dismissOverlay() {
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        NSCursor.arrow.set()
    }

    private func performCapture(appKitRect: CGRect) {
        // Convert AppKit coords (y from bottom of main screen) → CG coords (y from top)
        let mainH = NSScreen.main?.frame.height ?? 0
        let cgRect = CGRect(
            x: appKitRect.minX,
            y: mainH - appKitRect.maxY,
            width: appKitRect.width,
            height: appKitRect.height
        )

        // CGWindowListCreateImage excludes any windows that have been ordered out
        let cgImage = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )

        if let cgImage {
            let image = NSImage(cgImage: cgImage, size: appKitRect.size)
            onCapture?(image)
        }
    }
}

// MARK: - SnipOverlayWindow

final class SnipOverlayWindow: NSWindow {
    weak var snipTool: SnipTool?

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // Sit above everything except the screensaver
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) - 1)
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        acceptsMouseMovedEvents = true

        let selView = SnipSelectionView(frame: screen.frame)
        selView.onSelection = { [weak self] rect in self?.snipTool?.captureRegion(rect) }
        selView.onCancel    = { [weak self] in self?.snipTool?.cancel() }
        contentView = selView
    }
}

// MARK: - SnipSelectionView

final class SnipSelectionView: NSView {
    var onSelection: ((CGRect) -> Void)?
    var onCancel:    (() -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: CGRect?

    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Dark overlay across the whole view
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.45).cgColor)
        ctx.fill(bounds)

        if let rect = currentRect, rect.width > 1, rect.height > 1 {
            // Punch a transparent hole so the real screen shows through
            ctx.setBlendMode(.clear)
            ctx.fill(rect)
            ctx.setBlendMode(.normal)

            // Blue highlight border
            ctx.setStrokeColor(NSColor.systemBlue.cgColor)
            ctx.setLineWidth(2)
            ctx.stroke(rect.insetBy(dx: 1, dy: 1))

            // White corner brackets
            drawCorners(ctx: ctx, rect: rect, len: 12)

            // Dimension label
            drawSizeLabel(ctx: ctx, rect: rect)
        } else {
            // Instruction text before any drag starts
            drawInstructions(ctx: ctx)
        }
    }

    private func drawCorners(ctx: CGContext, rect: CGRect, len: CGFloat) {
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(3)

        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            // top-left (AppKit: minX, maxY is visually top)
            (CGPoint(x: rect.minX, y: rect.maxY - len),
             CGPoint(x: rect.minX, y: rect.maxY),
             CGPoint(x: rect.minX + len, y: rect.maxY)),
            // top-right
            (CGPoint(x: rect.maxX - len, y: rect.maxY),
             CGPoint(x: rect.maxX, y: rect.maxY),
             CGPoint(x: rect.maxX, y: rect.maxY - len)),
            // bottom-left
            (CGPoint(x: rect.minX, y: rect.minY + len),
             CGPoint(x: rect.minX, y: rect.minY),
             CGPoint(x: rect.minX + len, y: rect.minY)),
            // bottom-right
            (CGPoint(x: rect.maxX - len, y: rect.minY),
             CGPoint(x: rect.maxX, y: rect.minY),
             CGPoint(x: rect.maxX, y: rect.minY + len))
        ]
        for (a, b, c) in corners {
            ctx.move(to: a); ctx.addLine(to: b); ctx.addLine(to: c)
        }
        ctx.strokePath()
    }

    private func drawSizeLabel(ctx: CGContext, rect: CGRect) {
        let text = "\(Int(rect.width)) × \(Int(rect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let sz = str.size()
        let pad: CGFloat = 5
        let bgRect = CGRect(x: rect.minX, y: rect.maxY + 6,
                            width: sz.width + pad * 2, height: sz.height + pad)

        ctx.setFillColor(NSColor.black.withAlphaComponent(0.65).cgColor)
        ctx.fill(bgRect)
        str.draw(at: NSPoint(x: bgRect.minX + pad, y: bgRect.minY + pad / 2))
    }

    private func drawInstructions(ctx: CGContext) {
        let text = "Click and drag to capture a region  •  Esc to cancel"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let sz = str.size()
        let x = (bounds.width - sz.width) / 2
        let y = bounds.height - 90  // near the top (AppKit coords)

        let pad: CGFloat = 10
        let bgRect = CGRect(x: x - pad, y: y - pad / 2,
                            width: sz.width + pad * 2, height: sz.height + pad)

        let path = CGPath(roundedRect: bgRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.7).cgColor)
        ctx.addPath(path); ctx.fillPath()

        str.draw(at: NSPoint(x: x, y: y))
    }

    // MARK: Mouse events

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = nil
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let cur = convert(event.locationInWindow, from: nil)
        currentRect = CGRect(
            x: min(start.x, cur.x), y: min(start.y, cur.y),
            width: abs(cur.x - start.x), height: abs(cur.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { startPoint = nil; currentRect = nil }
        guard let rect = currentRect, rect.width > 5, rect.height > 5 else {
            onCancel?(); return
        }
        // Convert view rect → screen rect
        let screenRect = window?.convertToScreen(rect) ?? rect
        onSelection?(screenRect)
    }

    // MARK: Keyboard

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() }  // Esc
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}
