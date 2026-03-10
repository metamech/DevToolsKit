import DevToolsKitScreenCapture
import SwiftUI

/// Modal sheet for quickly capturing an issue report.
///
/// Presents provider selection, auto-captured state (read-only),
/// dynamic expected-state fields, notes, tags, and a screenshot button.
///
/// Since 0.5.0
@MainActor
public struct QuickCaptureView: View {
    let store: IssueCaptureStore
    let providers: [any IssueCaptureProvider]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProviderIndex: Int = 0
    @State private var capturedState: [String: String] = [:]
    @State private var expectedValues: [String: String] = [:]
    @State private var selectedMulti: [String: Set<String>] = [:]
    @State private var notes: String = ""
    @State private var tagText: String = ""
    @State private var screenshotData: Data?
    @State private var isCapturing = false
    @State private var errorMessage: String?

    /// - Parameters:
    ///   - store: The shared issue capture store.
    ///   - providers: Available providers for capture.
    public init(store: IssueCaptureStore, providers: [any IssueCaptureProvider]) {
        self.store = store
        self.providers = providers
    }

    private var selectedProvider: (any IssueCaptureProvider)? {
        guard !providers.isEmpty, selectedProviderIndex < providers.count else { return nil }
        return providers[selectedProviderIndex]
    }

    public var body: some View {
        NavigationStack {
            Form {
                if providers.count > 1 {
                    Section("Provider") {
                        Picker("Provider", selection: $selectedProviderIndex) {
                            ForEach(Array(providers.enumerated()), id: \.offset) { index, provider in
                                Text(provider.displayName).tag(index)
                            }
                        }
                        .labelsHidden()
                    }
                }

                Section("Current State") {
                    if capturedState.isEmpty {
                        Text("Capturing...")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(capturedState.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            LabeledContent(key, value: value)
                        }
                    }
                }

                if let provider = selectedProvider {
                    Section("Expected State") {
                        ForEach(provider.expectedStateFields) { field in
                            fieldView(for: field)
                        }
                    }
                }

                Section("Notes") {
                    TextField("What happened?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Tags") {
                    TextField("Comma-separated tags", text: $tagText)
                }

                Section("Screenshot") {
                    HStack {
                        if screenshotData != nil {
                            Label("Screenshot attached", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Spacer()
                            Button("Remove") {
                                screenshotData = nil
                            }
                        } else {
                            Button {
                                captureScreenshot()
                            } label: {
                                Label("Capture Window", systemImage: "camera")
                            }
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Quick Capture")
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCapture() }
                        .disabled(selectedProvider == nil)
                }
            }
            #else
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCapture() }
                        .disabled(selectedProvider == nil)
                }
            }
            #endif
        }
        .frame(minWidth: 400, minHeight: 500)
        .onChange(of: selectedProviderIndex) { _, _ in
            refreshCapturedState()
        }
        .onAppear {
            refreshCapturedState()
        }
    }

    // MARK: - Field Views

    @ViewBuilder
    private func fieldView(for field: IssueCaptureField) -> some View {
        switch field {
        case .text(let id, let label, let placeholder):
            TextField(label, text: binding(for: id), prompt: Text(placeholder))

        case .quickSelect(let id, let label, let options):
            Picker(label, selection: binding(for: id)) {
                Text("Select...").tag("")
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }

        case .multiSelect(let id, let label, let options):
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(options, id: \.self) { option in
                    Toggle(option, isOn: Binding(
                        get: { selectedMulti[id, default: []].contains(option) },
                        set: { isOn in
                            if isOn {
                                selectedMulti[id, default: []].insert(option)
                            } else {
                                selectedMulti[id, default: []].remove(option)
                            }
                            // Store as comma-separated for the expected state
                            expectedValues[id] = selectedMulti[id, default: []].sorted().joined(separator: ", ")
                        }
                    ))
                    #if os(macOS)
                    .toggleStyle(.checkbox)
                    #endif
                }
            }
        }
    }

    private func binding(for fieldID: String) -> Binding<String> {
        Binding(
            get: { expectedValues[fieldID, default: ""] },
            set: { expectedValues[fieldID] = $0 }
        )
    }

    // MARK: - Actions

    private func refreshCapturedState() {
        guard let provider = selectedProvider else { return }
        Task {
            capturedState = await provider.captureCurrentState()
        }
    }

    private func captureScreenshot() {
        Task {
            do {
                let result = try await ScreenCapturer.captureWindow()
                screenshotData = result.imageData
            } catch ScreenCaptureError.unsupportedPlatform {
                errorMessage = "Screenshots not supported on this platform"
            } catch ScreenCaptureError.noWindowAvailable {
                errorMessage = "No window available for capture"
            } catch {
                errorMessage = "Screenshot failed: \(error.localizedDescription)"
            }
        }
    }

    private func saveCapture() {
        guard let provider = selectedProvider else { return }

        let tags = tagText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let capture = IssueCapture(
            providerID: provider.id,
            providerName: provider.displayName,
            capturedState: capturedState,
            expectedState: expectedValues,
            notes: notes.isEmpty ? nil : notes,
            tags: tags,
            screenshotData: screenshotData
        )

        do {
            try store.save(capture)
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

// MARK: - View Modifier

extension View {
    /// Presents a quick capture sheet for reporting issue discrepancies.
    ///
    /// - Parameters:
    ///   - isPresented: Binding controlling sheet visibility.
    ///   - store: The issue capture store to save to.
    ///   - providers: Available providers for capture.
    /// - Returns: The modified view.
    ///
    /// Since 0.5.0
    public func quickCaptureSheet(
        isPresented: Binding<Bool>,
        store: IssueCaptureStore,
        providers: [any IssueCaptureProvider]
    ) -> some View {
        sheet(isPresented: isPresented) {
            QuickCaptureView(store: store, providers: providers)
        }
    }
}
