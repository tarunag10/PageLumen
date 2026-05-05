import SwiftUI

struct SettingsView: View {
    @AppStorage("privacyMode") private var privacyMode = true

    var body: some View {
        Form {
            Toggle("Privacy mode", isOn: $privacyMode)
            Text("Privacy mode keeps the MVP workflow local and disables future network-assisted processing by default.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 420)
    }
}
