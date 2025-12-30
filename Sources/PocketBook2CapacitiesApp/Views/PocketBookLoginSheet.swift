import SwiftUI
import PocketBook2CapacitiesCore

struct PocketBookLoginSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var shops: [Shop] = []
    @State private var selectedShop: Shop?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var step: LoginStep = .email

    enum LoginStep {
        case email
        case shop
        case password
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("PocketBook Cloud Login")
                .font(.headline)

            switch step {
            case .email:
                emailStep
            case .shop:
                shopStep
            case .password:
                passwordStep
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

                if step != .email {
                    Button("Back") {
                        goBack()
                    }
                }
            }
        }
        .padding()
        .frame(width: 350)
    }

    private var emailStep: some View {
        VStack(spacing: 12) {
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)

            Button(action: fetchShops) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Continue")
                }
            }
            .disabled(email.isEmpty || isLoading)
            .buttonStyle(.borderedProminent)
        }
    }

    private var shopStep: some View {
        VStack(spacing: 12) {
            Text("Select your PocketBook shop:")
                .font(.subheadline)

            Picker("Shop", selection: $selectedShop) {
                ForEach(shops) { shop in
                    Text(shop.name).tag(Optional(shop))
                }
            }
            .pickerStyle(.radioGroup)

            Button("Continue") {
                step = .password
            }
            .disabled(selectedShop == nil)
            .buttonStyle(.borderedProminent)
        }
    }

    private var passwordStep: some View {
        VStack(spacing: 12) {
            if let shop = selectedShop {
                Text("Logging in to \(shop.name)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Button(action: login) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Login")
                }
            }
            .disabled(password.isEmpty || isLoading)
            .buttonStyle(.borderedProminent)
        }
    }

    private func fetchShops() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let credentialStore = CredentialStore()
                let client = PocketBookClient(credentialStore: credentialStore)
                let fetchedShops = try await client.getShops(username: email)

                await MainActor.run {
                    isLoading = false
                    shops = fetchedShops
                    if shops.count == 1 {
                        selectedShop = shops[0]
                        step = .password
                    } else if shops.isEmpty {
                        errorMessage = "No shops available for this email"
                    } else {
                        step = .shop
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func login() {
        guard let shop = selectedShop else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let credentialStore = CredentialStore()
                let client = PocketBookClient(credentialStore: credentialStore)
                _ = try await client.login(email: email, password: password, shop: shop)

                await MainActor.run {
                    isLoading = false
                    appState.refreshCredentialStatus()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func goBack() {
        switch step {
        case .email:
            break
        case .shop:
            step = .email
        case .password:
            step = shops.count > 1 ? .shop : .email
        }
    }
}
