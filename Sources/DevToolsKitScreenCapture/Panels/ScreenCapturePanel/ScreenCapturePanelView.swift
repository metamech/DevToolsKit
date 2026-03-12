#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import DevToolsKit
import SwiftUI

/// Main panel view for browsing, filtering, and exporting screen captures.
@MainActor
public struct ScreenCapturePanelView: View {
    @Bindable var store: ScreenCaptureStore
    @State private var selectedEntry: ScreenCaptureEntry?
    @State private var entryPendingDeletion: ScreenCaptureEntry?

    /// - Parameter store: The shared screen capture store.
    public init(store: ScreenCaptureStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if store.entries.isEmpty {
                ContentUnavailableView(
                    "No Screen Captures",
                    systemImage: "photo.on.rectangle",
                    description: Text("Screen captures will appear here after you take them.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                NavigationSplitView {
                    thumbnailGrid
                } detail: {
                    if let entry = selectedEntry {
                        ScreenCaptureDetailView(
                            entry: entry,
                            store: store,
                            entryPendingDeletion: $entryPendingDeletion
                        )
                    } else {
                        ContentUnavailableView(
                            "Select a Capture",
                            systemImage: "sidebar.left",
                            description: Text("Choose a capture from the grid to view details.")
                        )
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            try? store.loadAll()
        }
        .confirmationDialog(
            "Delete Capture",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { if !$0 { entryPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let entry = entryPendingDeletion {
                    if selectedEntry?.id == entry.id {
                        selectedEntry = nil
                    }
                    store.delete(id: entry.id)
                    entryPendingDeletion = nil
                }
            }
        } message: {
            Text("This capture and its image files will be permanently deleted.")
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker("Mode", selection: $store.filterMode) {
                Text("All Modes").tag(ScreenCaptureMode?.none)
                ForEach(ScreenCaptureMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(ScreenCaptureMode?.some(mode))
                }
            }
            .labelsHidden()
            .frame(width: 140)

            Spacer()

            Text("\(store.filteredEntries.count) captures")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formattedStorageSize)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Thumbnail Grid

    private var thumbnailGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 160, maximum: 200))],
                spacing: 12
            ) {
                ForEach(store.filteredEntries) { entry in
                    Button {
                        selectedEntry = entry
                    } label: {
                        ScreenCaptureThumbnailCard(entry: entry, store: store)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "\(entry.mode.displayName) capture, \(Int(entry.imageSize.width)) by \(Int(entry.imageSize.height)) points"
                    )
                    .accessibilityHint("Show capture details")
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                selectedEntry?.id == entry.id ? Color.accentColor : .clear,
                                lineWidth: 2
                            )
                    )
                    .contextMenu {
                        Button {
                            copyToClipboard(entry: entry)
                        } label: {
                            Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                        }
                        Divider()
                        Button(role: .destructive) {
                            entryPendingDeletion = entry
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private var formattedStorageSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(store.totalStorageBytes))
    }

    private func copyToClipboard(entry: ScreenCaptureEntry) {
        guard let data = store.imageData(for: entry) else { return }
        let result = ScreenCaptureResult(
            imageData: data,
            size: entry.imageSize,
            mode: entry.mode,
            timestamp: entry.timestamp,
            displayScale: entry.displayScale
        )
        try? ScreenCaptureExporter.copyToClipboard(result)
    }
}

// MARK: - ScreenCaptureEntry + Hashable (for selection)

extension ScreenCaptureEntry: Hashable {
    public static func == (lhs: ScreenCaptureEntry, rhs: ScreenCaptureEntry) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Thumbnail Card

private struct ScreenCaptureThumbnailCard: View {
    let entry: ScreenCaptureEntry
    let store: ScreenCaptureStore

    var body: some View {
        VStack(spacing: 4) {
            thumbnailImage
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 4) {
                Text(entry.mode.displayName)
                    .font(.caption2.bold())
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.fill, in: Capsule())

                Spacer()

                Text(dimensionsLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var thumbnailImage: some View {
        if let data = store.thumbnailData(for: entry),
           let image = platformImage(from: data) {
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "photo")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var dimensionsLabel: String {
        "\(Int(entry.imageSize.width))×\(Int(entry.imageSize.height))"
    }
}

// MARK: - Detail View

private struct ScreenCaptureDetailView: View {
    let entry: ScreenCaptureEntry
    let store: ScreenCaptureStore
    @Binding var entryPendingDeletion: ScreenCaptureEntry?
    @State private var fullImageData: Data?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Full image
                if let data = fullImageData, let image = platformImage(from: data) {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(
                            "\(entry.mode.displayName) capture, \(Int(entry.imageSize.width)) by \(Int(entry.imageSize.height)) points"
                        )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }

                Divider()

                // Metadata table
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Mode")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.mode.displayName)
                            .font(.caption.bold())
                    }
                    GridRow {
                        Text("Dimensions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(entry.imageSize.width)) × \(Int(entry.imageSize.height)) pt")
                            .font(.caption.bold())
                    }
                    GridRow {
                        Text("Scale")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(entry.displayScale, specifier: "%.1f")×")
                            .font(.caption.bold())
                    }
                    GridRow {
                        Text("File Size")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formattedFileSize)
                            .font(.caption.bold())
                    }
                    GridRow {
                        Text("Captured")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                            .font(.caption.bold())
                    }
                }

                Divider()

                // Actions
                HStack(spacing: 12) {
                    Button {
                        copyToClipboard()
                    } label: {
                        Label("Copy to Clipboard", systemImage: "doc.on.clipboard")
                    }

                    Button(role: .destructive) {
                        entryPendingDeletion = entry
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
            .padding()
        }
        .onAppear { loadFullImage() }
        .onChange(of: entry.id) { loadFullImage() }
    }

    private var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(entry.imageDataSize))
    }

    private func loadFullImage() {
        fullImageData = store.imageData(for: entry)
    }

    private func copyToClipboard() {
        guard let data = fullImageData ?? store.imageData(for: entry) else { return }
        let result = ScreenCaptureResult(
            imageData: data,
            size: entry.imageSize,
            mode: entry.mode,
            timestamp: entry.timestamp,
            displayScale: entry.displayScale
        )
        try? ScreenCaptureExporter.copyToClipboard(result)
    }
}

// MARK: - ScreenCaptureMode Display Name

extension ScreenCaptureMode {
    var displayName: String {
        switch self {
        case .window: "Window"
        case .area: "Area"
        case .fullScreen: "Full Screen"
        }
    }
}

// MARK: - Platform Image Helper

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
