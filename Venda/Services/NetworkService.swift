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
    let id: String
    let businessName: String
    let businessType: String
    let phone: String
    let currency: String?
    let companyCode: String
    let createdAt: String
    let updatedAt: String
}

struct StaffProfileResponse: Codable, Identifiable {
    let id: String
    let merchantId: String
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
    let merchantId: String
    let staffId: String
    let role: String
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

struct StaffDirectoryResponse: Codable {
    let staff: [StaffProfileResponse]
}

struct StaffMutationResponse: Codable {
    let message: String?
    let staff: StaffProfileResponse
}

struct ReportsSummaryResponse: Codable {
    let timeframe: String
    let generatedAt: String
    let summary: ReportsSummaryMetrics
    let paymentBreakdown: [ReportPaymentBreakdown]
    let topProducts: [ReportTopProduct]
    let trend: [ReportTrendPoint]
    let recentSales: [ReportRecentSale]
}

struct ReportsSummaryMetrics: Codable {
    let totalRevenue: Decimal
    let salesCount: Int
    let averageSale: Decimal
}

struct ReportPaymentBreakdown: Codable, Identifiable {
    var id: String { method }
    let method: String
    let amount: Decimal
    let salesCount: Int
}

struct ReportTopProduct: Codable, Identifiable {
    let id: String?
    let name: String
    let unitsSold: Decimal
    let revenue: Decimal
}

struct ReportTrendPoint: Codable, Identifiable {
    var id: String { bucket + label }
    let label: String
    let amount: Decimal
    let salesCount: Int
    let bucket: String
}

struct ReportRecentSale: Codable, Identifiable {
    let id: String
    let reference: String
    let totalAmount: Decimal
    let paymentMethod: String
    let staffName: String
    let createdAt: String
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
    func fetchStaff(token: String) async throws -> [StaffProfileResponse]
    func createStaff(token: String, name: String, role: StaffRole, pin: String) async throws -> StaffProfileResponse
    func updateStaff(token: String, staffID: String, name: String?, role: StaffRole?, pin: String?, isActive: Bool?) async throws -> StaffProfileResponse
    func fetchReportsSummary(token: String, timeframe: String) async throws -> ReportsSummaryResponse
}

final class NetworkService: NetworkServiceProtocol {
    static let shared = NetworkService()
    static let defaultAPIBaseURLString = "https://venda.kynto.me/api/v1"
    static let apiBaseURLEnvironmentKey = "VENDA_API_BASE_URL"
    static let apiBaseURLInfoPlistKeys = ["VENDA_API_BASE_URL", "API_BASE_URL"]
    static let apiBaseURLUserDefaultsKey = "venda.api.base.url"
    private static let requiredAPIPath = "/api/v1"

    let apiBaseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let iso8601Formatter = ISO8601DateFormatter()

    private init() {
        apiBaseURL = Self.resolveAPIBaseURL()
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

    func fetchStaff(token: String) async throws -> [StaffProfileResponse] {
        let response: StaffDirectoryResponse = try await performRequest(
            path: "staff",
            method: "GET",
            token: token,
            expectedStatusCodes: [200]
        )
        return response.staff
    }

    func createStaff(token: String, name: String, role: StaffRole, pin: String) async throws -> StaffProfileResponse {
        let payload: [String: String] = [
            "name": name,
            "role": role.rawValue,
            "pin": pin
        ]

        let response: StaffMutationResponse = try await performRequest(
            path: "staff",
            method: "POST",
            token: token,
            body: payload,
            expectedStatusCodes: [201]
        )
        return response.staff
    }

    func updateStaff(
        token: String,
        staffID: String,
        name: String?,
        role: StaffRole?,
        pin: String?,
        isActive: Bool?
    ) async throws -> StaffProfileResponse {
        struct UpdatePayload: Encodable {
            let name: String?
            let role: String?
            let isActive: Bool?
        }

        let shouldPatchProfile = name != nil || role != nil || isActive != nil
        var latestStaff: StaffProfileResponse?

        if shouldPatchProfile {
            let response: StaffMutationResponse = try await performRequest(
                path: "staff/\(staffID)",
                method: "PATCH",
                token: token,
                body: UpdatePayload(
                    name: name,
                    role: role?.rawValue,
                    isActive: isActive
                ),
                expectedStatusCodes: [200]
            )
            latestStaff = response.staff
        }

        if let pin, !pin.isEmpty {
            struct PinPayload: Encodable {
                let pin: String
            }

            let response: StaffMutationResponse = try await performRequest(
                path: "staff/\(staffID)/pin",
                method: "POST",
                token: token,
                body: PinPayload(pin: pin),
                expectedStatusCodes: [200]
            )
            latestStaff = response.staff
        }

        if let latestStaff {
            return latestStaff
        }

        throw NetworkError.serverError("No staff changes were submitted.")
    }

    func fetchReportsSummary(token: String, timeframe: String) async throws -> ReportsSummaryResponse {
        var components = URLComponents(url: apiBaseURL.appendingPathComponent("reports/summary"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "timeframe", value: timeframe)]

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        return try await performRequest(
            url: url,
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
            currentUser: CurrentUser(identity: response),
            expiresAt: response.session.flatMap { iso8601Formatter.date(from: $0.expiresAt) }
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
        return try await performRequest(
            url: url,
            method: method,
            token: token,
            body: body,
            expectedStatusCodes: expectedStatusCodes
        )
    }

    private func performRequest<Response: Decodable>(
        url: URL,
        method: String,
        token: String? = nil,
        body: Encodable? = nil,
        expectedStatusCodes: Set<Int>
    ) async throws -> Response {
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

    static func resolveAPIBaseURL(
        environment: [String: String],
        infoDictionary: [String: Any],
        userDefaultsValue: String?,
        fallbackURLString: String = defaultAPIBaseURLString
    ) -> URL {
        let candidates = [
            environment[apiBaseURLEnvironmentKey],
            infoDictionary[apiBaseURLInfoPlistKeys[0]] as? String,
            infoDictionary[apiBaseURLInfoPlistKeys[1]] as? String,
            userDefaultsValue,
            fallbackURLString
        ]

        for candidate in candidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }) {
            if let url = normalizedAPIBaseURL(from: candidate) {
                return url
            }
        }

        fatalError("Invalid API base URL configuration")
    }

    private static func normalizedAPIBaseURL(from candidate: String) -> URL? {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var components = URLComponents(string: trimmed),
              let rawScheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty,
              components.query == nil,
              components.fragment == nil else {
            return nil
        }

        guard rawScheme == "https" || rawScheme == "http" else {
            return nil
        }

        if rawScheme == "http" && !isLocalDevelopmentHost(host) {
            return nil
        }

        guard let normalizedPath = normalizedAPIPath(from: components.path) else {
            return nil
        }

        components.scheme = rawScheme
        components.host = host
        components.path = normalizedPath

        return components.url
    }

    private static func normalizedAPIPath(from path: String) -> String? {
        let trimmedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if trimmedPath.isEmpty {
            return requiredAPIPath
        }

        let normalizedPath = "/" + trimmedPath
        return normalizedPath == requiredAPIPath ? normalizedPath : nil
    }

    private static func isLocalDevelopmentHost(_ host: String) -> Bool {
        if host == "localhost" || host == "::1" || host.hasSuffix(".local") {
            return true
        }

        if host.hasPrefix("127.") || host.hasPrefix("10.") || host.hasPrefix("192.168.") {
            return true
        }

        let octets = host.split(separator: ".")
        if octets.count == 4,
           octets[0] == "172",
           let secondOctet = Int(octets[1]),
           (16...31).contains(secondOctet) {
            return true
        }

        return !host.contains(".")
    }

    private static func resolveAPIBaseURL() -> URL {
        resolveAPIBaseURL(
            environment: ProcessInfo.processInfo.environment,
            infoDictionary: Bundle.main.infoDictionary ?? [:],
            userDefaultsValue: UserDefaults.standard.string(forKey: apiBaseURLUserDefaultsKey)
        )
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
