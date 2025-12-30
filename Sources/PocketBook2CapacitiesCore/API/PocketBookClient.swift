import Foundation

/// Client for PocketBook Cloud API
public actor PocketBookClient {
    private let baseURL = "https://cloud.pocketbook.digital/api/v1.0"
    private let clientId = "qNAx1RDb"
    private let clientSecret = "K3YYSjCgDJNoWKdGVOyO1mrROp3MMZqqRNXNXTmh"

    private let credentialStore: CredentialStore
    private let session: URLSession

    // Store username for shop discovery
    private var pendingUsername: String?

    public init(credentialStore: CredentialStore) {
        self.credentialStore = credentialStore
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Authentication

    /// Get available shops for login (requires username to be set first)
    public func getShops(username: String) async throws -> [Shop] {
        self.pendingUsername = username

        var components = URLComponents(string: "\(baseURL)/auth/login")!
        components.queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret)
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        let shopsResponse = try JSONDecoder().decode(ShopsResponse.self, from: data)
        return shopsResponse.providers
    }

    /// Login with email and password
    public func login(email: String, password: String, shop: Shop) async throws -> AuthTokens {
        let url = URL(string: "\(baseURL)/auth/login/\(shop.alias)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Build form-urlencoded body - use shopId from response (it's a string like "1")
        let shopId = shop.shopId ?? "1"
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "shop_id", value: shopId),
            URLQueryItem(name: "username", value: email),
            URLQueryItem(name: "password", value: password),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "grant_type", value: "password"),
            URLQueryItem(name: "language", value: "en")
        ]

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        let tokens = try JSONDecoder().decode(AuthTokens.self, from: data)

        // Store tokens
        credentialStore.storePocketBookTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresIn: tokens.expiresIn,
            shopAlias: shop.alias
        )

        return tokens
    }

    /// Refresh access token using stored refresh token
    public func refreshAccessToken() async throws {
        guard let refreshToken = credentialStore.pocketBookRefreshToken,
              let shopAlias = credentialStore.pocketBookShopAlias,
              let accessToken = credentialStore.pocketBookAccessToken else {
            throw PocketBookError.notAuthenticated
        }

        let url = URL(string: "\(baseURL)/auth/renew-token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        // Build form-urlencoded body
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        let tokens = try JSONDecoder().decode(AuthTokens.self, from: data)

        // Update stored tokens
        credentialStore.storePocketBookTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            expiresIn: tokens.expiresIn,
            shopAlias: shopAlias
        )
    }

    /// Ensure we have a valid access token
    private func ensureValidToken() async throws -> String {
        if !credentialStore.isPocketBookTokenValid {
            try await refreshAccessToken()
        }

        guard let token = credentialStore.pocketBookAccessToken else {
            throw PocketBookError.notAuthenticated
        }

        return token
    }

    // MARK: - Books

    /// Fetch all books from the user's library
    public func getBooks() async throws -> [Book] {
        let token = try await ensureValidToken()

        let url = URL(string: "\(baseURL)/books?limit=500")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        let booksResponse = try JSONDecoder().decode(BooksResponse.self, from: data)
        return booksResponse.items
    }

    // MARK: - Highlights

    /// Get highlight IDs for a book
    func getHighlightIds(forBook book: Book) async throws -> [String] {
        let token = try await ensureValidToken()

        guard let encodedHash = book.fastHash.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw PocketBookError.invalidResponse
        }

        let url = URL(string: "\(baseURL)/notes?fast_hash=\(encodedHash)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        // API returns array directly, not wrapped in {"data": [...]}
        let highlights = try JSONDecoder().decode([HighlightIdEntry].self, from: data)
        return highlights.map { $0.uuid }
    }

    /// Get full highlight details
    func getHighlight(uuid: String, fastHash: String) async throws -> PocketBookNoteResponse? {
        let token = try await ensureValidToken()

        guard let encodedHash = fastHash.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw PocketBookError.invalidResponse
        }

        let url = URL(string: "\(baseURL)/notes/\(uuid)?fast_hash=\(encodedHash)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let (data, response) = try await session.data(for: request)

        // 404 means highlight not found, return nil
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            return nil
        }

        try checkResponse(response, data: data)

        return try JSONDecoder().decode(PocketBookNoteResponse.self, from: data)
    }

    /// Get all highlights for a book
    public func getHighlights(forBook book: Book) async throws -> [Highlight] {
        let highlightIds = try await getHighlightIds(forBook: book)

        var highlights: [Highlight] = []

        for uuid in highlightIds {
            if let response = try await getHighlight(uuid: uuid, fastHash: book.fastHash),
               let highlight = response.toHighlight(bookId: book.id, bookFastHash: book.fastHash) {
                highlights.append(highlight)
            }
        }

        return highlights
    }

    // MARK: - Helpers

    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PocketBookError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw PocketBookError.unauthorized
        case 403:
            let message = String(data: data, encoding: .utf8) ?? "No details"
            throw PocketBookError.forbidden(message)
        case 404:
            throw PocketBookError.notFound
        case 429:
            throw PocketBookError.rateLimited
        case 500...599:
            throw PocketBookError.serverError(httpResponse.statusCode)
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw PocketBookError.httpError(httpResponse.statusCode, message)
        }
    }
}

// MARK: - Response Types

struct ShopsResponse: Codable {
    let providers: [Shop]
}

public struct Shop: Codable, Identifiable, Hashable {
    public let alias: String
    public let name: String
    public let shopId: String?
    public var id: String { alias }

    enum CodingKeys: String, CodingKey {
        case alias
        case name
        case shopId = "shop_id"
    }
}

public struct AuthTokens: Codable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int
    public let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct BooksResponse: Codable {
    let total: Int
    let items: [Book]
}

struct HighlightIdsResponse: Codable {
    let data: [HighlightIdEntry]
}

struct HighlightIdEntry: Codable {
    let uuid: String
}

// MARK: - Errors

public enum PocketBookError: Error, CustomStringConvertible {
    case notAuthenticated
    case unauthorized
    case forbidden(String)
    case notFound
    case rateLimited
    case serverError(Int)
    case httpError(Int, String)
    case invalidResponse

    public var description: String {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please run 'pocketbook2capacities login' first."
        case .unauthorized:
            return "Unauthorized. Your credentials may have expired."
        case .forbidden(let details):
            return "Access forbidden. Details: \(details)"
        case .notFound:
            return "Resource not found."
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .httpError(let code, let message):
            return "HTTP error \(code): \(message)"
        case .invalidResponse:
            return "Invalid response from server."
        }
    }
}
