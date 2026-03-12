import DevToolsKit
import DevToolsKitScreenCapture
import Logging
import Metrics
import SwiftUI

struct ContentView: View {
    @Environment(\.devToolsManager) private var manager
    let screenCaptureStore: ScreenCaptureStore

    var body: some View {
        VStack(spacing: 24) {
            header
            panelGrid
            Divider()
            actionButtons
            Spacer()
        }
        .padding(32)
        .frame(minWidth: 600, minHeight: 500)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("DevToolsKit Demo")
                .font(.largeTitle.bold())
            Text("Use the Developer menu or the buttons below to open panels.")
                .foregroundStyle(.secondary)
            Text("All display modes work: Docked, Windowed (tabbed), Separate Windows.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Panel Grid

    private var panelGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160))],
            spacing: 10
        ) {
            if let manager {
                ForEach(manager.panels, id: \.id) { panel in
                    Button {
                        manager.openPanel(panel.id)
                    } label: {
                        Label(panel.title, systemImage: panel.icon)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Generate Logs") {
                generateLogs()
            }

            Button("Record Metrics") {
                recordMetrics()
            }

            Button("Take Screenshot") {
                Task {
                    await takeScreenshot()
                }
            }
        }
    }

    // MARK: - Actions

    private func generateLogs() {
        let logger = Logger(label: "DemoApp")
        logger.info("User clicked Generate Logs at \(Date().formatted(date: .omitted, time: .standard))")
        logger.warning("Simulated warning: disk space below 10%")
        logger.error("Simulated error: connection timeout after 30s")
        logger.debug("Debug: current view hierarchy depth = 7")
    }

    private func recordMetrics() {
        let counter = Counter(label: "demo.button.taps", dimensions: [("button", "metrics")])
        counter.increment()

        let timer = Metrics.Timer(label: "demo.operation.duration")
        timer.recordMilliseconds(Int64.random(in: 10...500))
    }

    private func takeScreenshot() async {
        do {
            let result = try await ScreenCapturer.captureWindow()
            try screenCaptureStore.save(result)
        } catch ScreenCaptureError.userCancelled {
            // User cancelled — nothing to do
        } catch {
            Logger(label: "DemoApp").error("Screenshot failed: \(error)")
        }
    }
}
