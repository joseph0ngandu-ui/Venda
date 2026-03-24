import Foundation

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case unauthorized
}

extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The app could not build a valid server URL."
        case .noData:
            return "The server returned an empty response."
        case .decodingError:
            return "The app could not understand the server response."
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Your session is no longer valid. Please sign in again."
        }
    }
}

struct MerchantProfileResponse: Codable {
    let id: UUID
    let businessName: String
    let businessType: String
    let phone: String
    let currency: String?
    let companyCode: String
    let createdAt: String
    let updatedAt: String
}

struct StaffProfileResponse: Codable {
    let id: UUID
    let merchantId: UUID
    let name: String
    let role: StaffRole
    let companyCode: String
    let isActive: Bool
    let createdAt: String
    let updatedAt: String
    let phone: String?
}

struct AuthSessionResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let expiresAt: String
    let authType: String
    let companyCode: String
    let merchantID: UUID
    let staffID: UUID
    let role: StaffRole
}

struct AuthIdentityResponse: Codable {
    let message: String?
    let authenticated: Bool?
    let authType: String?
    let token: String?
    let tokenType: String?
    let expiresIn: Int?
    let expiresAt: String?
    let companyCode: String
    let merchant: MerchantProfileResponse
    let staff: StaffProfileResponse
    let user: StaffProfileResponse
    let session: AuthSessionResponse?
}

private struct ErrorResponse: Codable {
    let error: String
}

protocol NetworkServiceProtocol {
    var apiBaseURL: URL { get }
    func register(businessName: String, ownerName: String, businessType: String, phone: String, pin: String) async throws -> AuthenticatedSession
    func loginMerchant(phone: String, pin: String) async throws -> AuthenticatedSession
    func joinBusiness(companyCode: String, pin: String) async throws -> AuthenticatedSession
    func getMe(token: String) async throws -> AuthIdentityResponse
}

final class NetworkService: NetworkServiceProtocol {
    static let shared = NetworkService()
    static let apiBaseURLString = "https://homeserver.taildbc5d3.ts.net/api/v1"

    let apiBaseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        guard let url = URL(string: Self.apiBaseURLString) else {
            fatalError("Invalid API base URL")
        }

        apiBaseURL = url
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    func register(
        businessName: String,
        ownerName: String,
        businessType: String,
        phone: String,
        pin: String
    ) async throws -> AuthenticatedSession {
        let payload: [String: String] = [
            "business_name": businessName,
            "owner_name": ownerName,
            "business_type": businessType,
            "phone": phone,
            "pin": pin
        ]

        let response: AuthIdentityResponse = try await performRequest(
            path: "auth/register",
            method: "POST",
            body: payload,
            expectedStatusCodes: [201]
        )

        return try makeSession(from: response)
    }

    func loginMerchant(phone: String, pin: String) async throws -> AuthenticatedSession {
        let payload: [String: String] = [
            "phone": phone,
            "pin": pin
        ]

        let response: AuthIdentityResponse = try await performRequest(
            path: "auth/login",
            method: "POST",
            body: payload,
            expectedStatusCodes: [200]
        )

        return try makeSession(from: response)
    }

    func joinBusiness(companyCode: String, pin: String) async throws -> AuthenticatedSession {
        let payload: [String: String] = [
            "company_code": companyCode.uppercased(),
            "pin": pin
        ]

        let response: AuthIdentityResponse = try await performRequest(
            path: "auth/join",
            method: "POST",
            body: payload,
            expectedStatusCodes: [200]
        )

        return try makeSession(from: response)
    }

    func getMe(token: String) async throws -> AuthIdentityResponse {
        try await performRequest(
            path: "auth/me",
            method: "GET",
            token: token,
            expectedStatusCodes: [200]
        )
    }

    private func makeSession(from response: AuthIdentityResponse) throws -> AuthenticatedSession {
        guard let token = response.token, !token.isEmpty else {
            throw NetworkError.decodingError
        }

        return AuthenticatedSession(
            token: token,
            currentUser: CurrentUser(identity: response)
        )
    }

    private func performRequest<Response: Decodable>(
        path: String,
        method: String,
        token: String? = nil,
        body: Encodable? = nil,
        expectedStatusCodes: Set<Int>
    ) async throws -> Response {
        let url = apiBaseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError("Invalid response type")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw NetworkError.unauthorized
        }

        guard expectedStatusCodes.contains(httpResponse.statusCode) else {
            if let serverError = try? decoder.decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(serverError.error)
            }

            throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
        }

        guard !data.isEmpty else {
            throw NetworkError.noData
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }

    private func encode(_ value: Encodable) throws -> Data {
        let wrapped = AnyEncodable(value)
        return try encoder.encode(wrapped)
    }
}

private struct AnyEncodable: Encodable {
    private let encodeBlock: (Encoder) throws -> Void

    init(_ value: Encodable) {
        encodeBlock = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeBlock(encoder)
    }
}
