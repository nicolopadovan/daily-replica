import AppKit
import DailyReplicaCore
import SwiftUI

@MainActor
final class PromptPanelCoordinator: PromptPresenting {
    var makeViewModel: ((SmartPrompt) -> SmartPromptViewModel?)?
    private var panel: NSPanel?

    func showPrompt(_ prompt: SmartPrompt) {
        guard let viewModel = makeViewModel?(prompt) else {
            return
        }
        let content = SmartPromptView(viewModel: viewModel)
            .frame(width: 360)

        let hostingController = NSHostingController(rootView: content)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 210),
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Daily Replica"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.contentViewController = hostingController
        panel.centerOnActiveScreenTopRight()
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func dismissPrompt() {
        panel?.close()
        panel = nil
    }
}

private extension NSWindow {
    func centerOnActiveScreenTopRight() {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let origin = NSPoint(
            x: visibleFrame.maxX - frame.width - 24,
            y: visibleFrame.maxY - frame.height - 24
        )
        setFrameOrigin(origin)
    }
}
