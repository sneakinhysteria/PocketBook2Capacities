import SwiftUI
import PocketBook2CapacitiesCore

struct CapacitiesSetupSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var apiToken = ""
    @State private var spaces: [CapacitiesSpace] = []
    @State private var selectedSpace: CapacitiesSpace?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var step: SetupStep = .token

    enum SetupStep {
        case token
        case space
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Capacities Setup")
                .font(.headline)

            switch step {
            case .token:
                tokenStep
            case .space:
                spaceStep
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                if step == .space {
                    Button("Back") {
                        step = .token
                    }
                }
            }
        }
        .padding()
        .frame(width: 400)
    }

    private var tokenStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Get your API token from:")
                .font(.subheadline)

            Text("Capacities Desktop App Settings API")
                .font(.caption)
                .foregroundColor(.secondary)

            SecureField("API Token", text: $apiToken)
                .textFieldStyle(.roundedBorder)

            Button(action: validateToken) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Continue")
                }
            }
            .disabled(apiToken.isEmpty || isLoading)
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var spaceStep: some View {
        VStack(spacing: 12) {
            Text("Select your Capacities space:")
                .font(.subheadline)

            Picker("Space", selection: $selectedSpace) {
                ForEach(spaces) { space in
                    HStack {
                        Text(space.icon?.displayValue ?? "")
                        Text(space.title)
                    }
                    .tag(Optional(space))
                }
            }
            .pickerStyle(.radioGroup)

            Button(action: saveConfiguration) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Save")
                }
            }
            .disabled(selectedSpace == nil || isLoading)
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func validateToken() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let credentialStore = CredentialStore()
                credentialStore.capacitiesApiToken = apiToken

                let client = CapacitiesClient(credentialStore: credentialStore)
                let fetchedSpaces = try await client.getSpaces()

                await MainActor.run {
                    isLoading = false
                    spaces = fetchedSpaces
                    if spaces.isEmpty {
                        errorMessage = "No spaces found"
                        // Clear the token since it didn't work
                        credentialStore.capacitiesApiToken = nil
                    } else if spaces.count == 1 {
                        selectedSpace = spaces[0]
                        step = .space
                    } else {
                        step = .space
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    // Clear the token since it didn't work
                    let credentialStore = CredentialStore()
                    credentialStore.capacitiesApiToken = nil
                }
            }
        }
    }

    private func saveConfiguration() {
        guard let space = selectedSpace else { return }

        let credentialStore = CredentialStore()
        credentialStore.capacitiesSpaceId = space.id

        appState.refreshCredentialStatus()
        appState.capacitiesSpaceName = space.title
        dismiss()
    }
}
