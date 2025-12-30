import Foundation

/// Client for Capacities API
public actor CapacitiesClient {
    private let baseURL = "https://api.capacities.io"
    private let credentialStore: CredentialStore
    private let session: URLSession

    // Rate limiting
    private var lastRequestTime: Date = .distantPast
    private let minRequestInterval: TimeInterval = 0.5 // 500ms between requests

    public init(credentialStore: CredentialStore) {
        self.credentialStore = credentialStore
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }

    // MARK: - Spaces

    /// Get all spaces the user has access to
    public func getSpaces() async throws -> [CapacitiesSpace] {
        let token = try getToken()

        let url = URL(string: "\(baseURL)/spaces")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        await throttle()
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        let spacesResponse = try JSONDecoder().decode(SpacesResponse.self, from: data)
        return spacesResponse.spaces
    }

    /// Get information about a specific space including structures
    func getSpaceInfo(spaceId: String) async throws -> SpaceInfo {
        let token = try getToken()

        var components = URLComponents(string: "\(baseURL)/space-info")!
        components.queryItems = [URLQueryItem(name: "spaceid", value: spaceId)]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        await throttle()
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        return try JSONDecoder().decode(SpaceInfo.self, from: data)
    }

    // MARK: - Content

    /// Save a weblink with content to Capacities
    public func saveWeblink(
        spaceId: String,
        url: String,
        title: String? = nil,
        description: String? = nil,
        tags: [String]? = nil,
        markdown: String? = nil
    ) async throws -> SaveWeblinkResponse {
        let token = try getToken()

        let requestUrl = URL(string: "\(baseURL)/save-weblink")!
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "spaceId": spaceId,
            "url": url
        ]

        if let title = title {
            body["titleOverwrite"] = title
        }

        if let description = description {
            body["descriptionOverwrite"] = description
        }

        if let tags = tags, !tags.isEmpty {
            body["tags"] = Array(tags.prefix(30)) // Max 30 tags
        }

        if let markdown = markdown {
            body["mdText"] = markdown
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        await throttle()
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        return try JSONDecoder().decode(SaveWeblinkResponse.self, from: data)
    }

    /// Look up content by title
    func lookup(spaceId: String, searchTerm: String) async throws -> [LookupResult] {
        let token = try getToken()

        let url = URL(string: "\(baseURL)/lookup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "spaceId": spaceId,
            "searchTerm": searchTerm
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        await throttle()
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        let lookupResponse = try JSONDecoder().decode(LookupResponse.self, from: data)
        return lookupResponse.results
    }

    /// Save content to daily note
    func saveToDailyNote(
        spaceId: String,
        markdown: String,
        origin: String? = nil,
        noTimestamp: Bool = false
    ) async throws {
        let token = try getToken()

        let url = URL(string: "\(baseURL)/save-to-daily-note")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "spaceId": spaceId,
            "mdText": markdown
        ]

        if let origin = origin {
            body["origin"] = origin
        }

        if noTimestamp {
            body["noTimeStamp"] = true
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        await throttle()
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
    }

    // MARK: - Helpers

    private func getToken() throws -> String {
        guard let token = credentialStore.capacitiesApiToken else {
            throw CapacitiesError.notAuthenticated
        }
        return token
    }

    private func throttle() async {
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        if elapsed < minRequestInterval {
            let delay = minRequestInterval - elapsed
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        lastRequestTime = Date()
    }

    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CapacitiesError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw CapacitiesError.unauthorized
        case 403:
            throw CapacitiesError.forbidden
        case 404:
            throw CapacitiesError.notFound
        case 429:
            // Try to extract retry-after header
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
            throw CapacitiesError.rateLimited(retryAfter: retryAfter)
        case 500...599:
            throw CapacitiesError.serverError(httpResponse.statusCode)
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CapacitiesError.httpError(httpResponse.statusCode, message)
        }
    }
}

// MARK: - Response Types

struct SpacesResponse: Codable {
    let spaces: [CapacitiesSpace]
}

public struct CapacitiesSpace: Codable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let icon: SpaceIcon?

    // Custom decoding to handle missing/malformed icon
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        icon = try? container.decode(SpaceIcon.self, forKey: .icon)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, icon
    }
}

public struct SpaceIcon: Codable, Hashable {
    public let type: String?
    public let value: String?
    public let emoji: String?

    public var displayValue: String {
        emoji ?? value ?? "📁"
    }
}

struct SpaceInfo: Codable {
    let structures: [Structure]
    let collections: [Collection]?
}

struct Structure: Codable {
    let id: String
    let title: String
    let properties: [Property]?
}

struct Property: Codable {
    let id: String
    let title: String
    let type: String
}

struct Collection: Codable {
    let id: String
    let title: String
    let structureId: String
}

public struct SaveWeblinkResponse: Codable {
    public let id: String
    public let structureId: String
}

struct LookupResponse: Codable {
    let results: [LookupResult]
}

struct LookupResult: Codable {
    let id: String
    let structureId: String
    let title: String
}

// MARK: - Errors

public enum CapacitiesError: Error, CustomStringConvertible {
    case notAuthenticated
    case unauthorized
    case forbidden
    case notFound
    case rateLimited(retryAfter: String?)
    case serverError(Int)
    case httpError(Int, String)
    case invalidResponse

    public var description: String {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please run 'pocketbook2capacities login' first."
        case .unauthorized:
            return "Unauthorized. Your API token may be invalid."
        case .forbidden:
            return "Access forbidden."
        case .notFound:
            return "Resource not found."
        case .rateLimited(let retryAfter):
            if let after = retryAfter {
                return "Rate limited. Try again after \(after) seconds."
            }
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
