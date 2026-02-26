import SwiftUI

/// A tree view for inspecting JSON or key-value data.
public struct DataInspectorView: View {
    private let title: String
    private let data: Any

    @State private var expandedPaths: Set<String> = []

    public init(title: String = "Data", json: Any) {
        self.title = title
        self.data = json
    }

    public init(title: String = "Data", dictionary: [String: Any]) {
        self.title = title
        self.data = dictionary
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Expand All") {
                    expandAll(data, path: "root")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Collapse All") {
                    expandedPaths.removeAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    nodeView(value: data, key: "root", path: "root", depth: 0)
                }
                .padding(8)
            }
        }
        .font(.system(.caption, design: .monospaced))
        .frame(minWidth: 400, minHeight: 300)
    }

    private func nodeView(value: Any, key: String, path: String, depth: Int) -> AnyView {
        if let dict = value as? [String: Any] {
            AnyView(disclosureRow(key: key, summary: "{\(dict.count)}", path: path, depth: depth) {
                ForEach(dict.keys.sorted(), id: \.self) { childKey in
                    if let childValue = dict[childKey] {
                        nodeView(value: childValue, key: childKey, path: "\(path).\(childKey)", depth: depth + 1)
                    }
                }
            })
        } else if let array = value as? [Any] {
            AnyView(disclosureRow(key: key, summary: "[\(array.count)]", path: path, depth: depth) {
                ForEach(Array(array.enumerated()), id: \.offset) { index, element in
                    nodeView(value: element, key: "[\(index)]", path: "\(path).[\(index)]", depth: depth + 1)
                }
            })
        } else {
            AnyView(leafRow(key: key, value: "\(value)", depth: depth))
        }
    }

    @ViewBuilder
    private func disclosureRow<Content: View>(
        key: String,
        summary: String,
        path: String,
        depth: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isExpanded = expandedPaths.contains(path)

        Button {
            if isExpanded {
                expandedPaths.remove(path)
            } else {
                expandedPaths.insert(path)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8))
                    .frame(width: 12)
                Text(key)
                    .foregroundStyle(.primary)
                Text(summary)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, CGFloat(depth) * 16)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)

        if isExpanded {
            content()
        }
    }

    private func leafRow(key: String, value: String, depth: Int) -> some View {
        HStack(spacing: 4) {
            Color.clear.frame(width: 12) // alignment spacer
            Text(key)
                .foregroundStyle(.primary)
            Text(":")
                .foregroundStyle(.secondary)
            Text(value)
                .foregroundStyle(.blue)
                .textSelection(.enabled)
        }
        .padding(.leading, CGFloat(depth) * 16)
        .padding(.vertical, 2)
    }

    private func expandAll(_ value: Any, path: String) {
        expandedPaths.insert(path)
        if let dict = value as? [String: Any] {
            for (childKey, childValue) in dict {
                expandAll(childValue, path: "\(path).\(childKey)")
            }
        } else if let array = value as? [Any] {
            for (index, element) in array.enumerated() {
                expandAll(element, path: "\(path).[\(index)]")
            }
        }
    }
}
