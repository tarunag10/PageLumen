import SwiftUI

struct ProcessingView: View {
    @EnvironmentObject private var store: DocumentStore

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text(store.statusMessage)
                .font(.headline)
            Text("Pages are processed locally where macOS APIs support extraction.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
