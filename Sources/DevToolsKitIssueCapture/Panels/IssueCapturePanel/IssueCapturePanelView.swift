import DevToolsKit
import SwiftUI

/// Main panel view for browsing, filtering, and analyzing issue captures.
@MainActor
public struct IssueCapturePanelView: View {
    @Bindable var store: IssueCaptureStore
    let providers: [any IssueCaptureProvider]
    @State private var selectedCapture: IssueCapture?
    @State private var showingQuickCapture = false
    @State private var showingAnalysis = false

    /// - Parameters:
    ///   - store: The shared issue capture store.
    ///   - providers: Available providers for new captures.
    public init(store: IssueCaptureStore, providers: [any IssueCaptureProvider]) {
        self.store = store
        self.providers = providers
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if store.captures.isEmpty {
                ContentUnavailableView(
                    "No Issue Captures",
                    systemImage: "camera.viewfinder",
                    description: Text("Capture discrepancies between actual and expected state.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    captureList
                        .frame(minWidth: 300)

                    if let capture = selectedCapture {
                        captureDetail(capture)
                            .frame(minWidth: 300)
                    } else {
                        ContentUnavailableView(
                            "Select a Capture",
                            systemImage: "sidebar.left",
                            description: Text("Choose a capture from the list to view details.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .sheet(isPresented: $showingQuickCapture) {
            QuickCaptureView(store: store, providers: providers)
        }
        .sheet(isPresented: $showingAnalysis) {
            analysisView
        }
        .onAppear {
            try? store.loadAll()
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("Provider", selection: $store.filterProviderID) {
                Text("All Providers").tag(String?.none)
                ForEach(store.knownProviderIDs, id: \.self) { id in
                    Text(id).tag(String?.some(id))
                }
            }
            .frame(width: 160)

            Picker("Tag", selection: $store.filterTag) {
                Text("All Tags").tag(String?.none)
                ForEach(store.knownTags, id: \.self) { tag in
                    Text(tag).tag(String?.some(tag))
                }
            }
            .frame(width: 120)

            TextField("Search...", text: $store.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)

            Spacer()

            Text("\(store.filteredCaptures.count) captures")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showingAnalysis = true
            } label: {
                Image(systemName: "chart.bar")
            }
            .help("View analysis")

            Button {
                showingQuickCapture = true
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .help("New capture")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - List

    private var captureList: some View {
        List(store.filteredCaptures, selection: $selectedCapture) { capture in
            CaptureListRow(capture: capture)
                .tag(capture)
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        if selectedCapture?.id == capture.id {
                            selectedCapture = nil
                        }
                        store.delete(id: capture.id)
                    }
                }
        }
        .listStyle(.plain)
    }

    // MARK: - Detail

    private func captureDetail(_ capture: IssueCapture) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Label(capture.providerName, systemImage: "app.badge")
                        .font(.headline)
                    Spacer()
                    Text(capture.timestamp.formatted(date: .abbreviated, time: .standard))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Tags
                if !capture.tags.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(capture.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.fill, in: Capsule())
                        }
                    }
                }

                Divider()

                // State comparison
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Captured State")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        ForEach(capture.capturedState.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            StateRow(key: key, value: value)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Expected State")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        ForEach(capture.expectedState.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            let matches = capture.capturedState[key] == value
                            StateRow(key: key, value: value, highlight: !matches)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Notes
                if let notes = capture.notes, !notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notes")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        Text(notes)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }

                // Screenshot
                if let data = capture.screenshotData, let nsImage = platformImage(from: data) {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Screenshot")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                        nsImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Analysis

    private var analysisView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Captures by provider
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Captures by Provider")
                            .font(.headline)
                        ForEach(store.capturesByProvider.sorted(by: { $0.key < $1.key }), id: \.key) { provider, captures in
                            HStack {
                                Text(provider)
                                Spacer()
                                Text("\(captures.count)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    // Capture frequency
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Capture Frequency")
                            .font(.headline)
                        ForEach(store.captureFrequency, id: \.date) { entry in
                            HStack {
                                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                Spacer()
                                Text("\(entry.count) captures")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if store.captureFrequency.isEmpty {
                            Text("No data")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Analysis")
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showingAnalysis = false }
                }
            }
            #endif
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func platformImage(from data: Data) -> Image? {
        #if canImport(AppKit)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #elseif canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }
}

// MARK: - IssueCapture + Hashable (for List selection)

extension IssueCapture: Hashable {
    public static func == (lhs: IssueCapture, rhs: IssueCapture) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Supporting Views

private struct CaptureListRow: View {
    let capture: IssueCapture

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(capture.providerName)
                    .font(.subheadline.bold())
                Spacer()
                if capture.screenshotData != nil {
                    Image(systemName: "photo")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(capture.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !capture.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(capture.tags.prefix(3), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.fill, in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct StateRow: View {
    let key: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(highlight ? .red : .primary)
        }
    }
}

/// Simple flow layout for tags.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for row in rows {
            height += row.map { subviews[$0].sizeThatFits(proposal) }.map(\.height).max() ?? 0
        }
        height += CGFloat(max(rows.count - 1, 0)) * spacing
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            var rowHeight: CGFloat = 0
            for index in row {
                let size = subviews[index].sizeThatFits(proposal)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Int]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[Int]] = [[]]
        var currentWidth: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(proposal)
            if currentWidth + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(index)
            currentWidth += size.width + spacing
        }

        return rows
    }
}

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
