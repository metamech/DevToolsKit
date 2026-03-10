#if canImport(AppKit)
import AppKit

/// Transparent borderless window overlay for drag-to-select area capture on macOS.
@MainActor
final class AreaSelectionOverlayWindow {
    private let completion: @MainActor (CGRect?) -> Void
    private var panel: NSPanel?

    init(completion: @escaping @MainActor (CGRect?) -> Void) {
        self.completion = completion
    }

    func beginSelection() {
        guard let screen = NSScreen.main else {
            completion(nil)
            return
        }

        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.2)
        panel.hasShadow = false
        panel.ignoresMouseEvents = false

        let selectionView = AreaSelectionView { [weak self] rect in
            panel.close()
            self?.panel = nil
            self?.completion(rect)
        }

        panel.contentView = selectionView
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }
}

/// NSView that handles mouse drag for region selection.
private final class AreaSelectionView: NSView {
    private let completion: @MainActor (CGRect?) -> Void
    private var startPoint: NSPoint?
    private var currentRect: NSRect?

    init(completion: @escaping @MainActor (CGRect?) -> Void) {
        self.completion = completion
        super.init(frame: .zero)
        addCursorRect(bounds, cursor: .crosshair)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentRect = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)

        let rect = NSRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
        currentRect = rect
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let rect = currentRect, rect.width > 4, rect.height > 4 else {
            completion(nil)
            return
        }

        // Convert from view coordinates to screen coordinates
        guard let window = self.window, let screen = window.screen else {
            completion(nil)
            return
        }

        let windowRect = convert(rect, to: nil)
        let screenRect = window.convertToScreen(windowRect)

        // Flip Y for CGWindowList (origin at top-left)
        let flippedY = screen.frame.maxY - screenRect.maxY
        let captureRect = CGRect(
            x: screenRect.origin.x,
            y: flippedY,
            width: screenRect.width,
            height: screenRect.height
        )

        completion(captureRect)
    }

    override func keyDown(with event: NSEvent) {
        // Escape cancels
        if event.keyCode == 53 {
            completion(nil)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let rect = currentRect else { return }

        NSColor.selectedControlColor.withAlphaComponent(0.3).setFill()
        NSBezierPath(rect: rect).fill()

        NSColor.selectedControlColor.setStroke()
        let path = NSBezierPath(rect: rect)
        path.lineWidth = 2
        path.stroke()
    }
}
#endif

#if canImport(UIKit) && !os(tvOS) && !os(watchOS)
import UIKit

/// View controller overlay for drag-to-select area capture on iOS.
@MainActor
final class AreaSelectionOverlayViewController: UIViewController {
    private let completion: @MainActor (CGRect?) -> Void
    private var startPoint: CGPoint?
    private let selectionView = UIView()

    init(completion: @escaping @MainActor (CGRect?) -> Void) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.2)

        selectionView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        selectionView.layer.borderColor = UIColor.systemBlue.cgColor
        selectionView.layer.borderWidth = 2
        selectionView.isHidden = true
        view.addSubview(selectionView)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.require(toFail: pan)
        view.addGestureRecognizer(tap)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: view)

        switch gesture.state {
        case .began:
            startPoint = location
            selectionView.frame = CGRect(origin: location, size: .zero)
            selectionView.isHidden = false

        case .changed:
            guard let start = startPoint else { return }
            let rect = CGRect(
                x: min(start.x, location.x),
                y: min(start.y, location.y),
                width: abs(location.x - start.x),
                height: abs(location.y - start.y)
            )
            selectionView.frame = rect

        case .ended:
            let rect = selectionView.frame
            dismiss(animated: true) {
                if rect.width > 4, rect.height > 4 {
                    self.completion(rect)
                } else {
                    self.completion(nil)
                }
            }

        case .cancelled:
            dismiss(animated: true) {
                self.completion(nil)
            }

        default:
            break
        }
    }

    @objc private func handleTap() {
        dismiss(animated: true) {
            self.completion(nil)
        }
    }
}
#endif
