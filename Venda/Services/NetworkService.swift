import Foundation

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case unauthorized
}

protocol NetworkServiceProtocol {
    func register(businessName: String, businessType: String, phone: String, pin: String) async throws -> String
    func login(phone: String, pin: String) async throws -> String
}

class NetworkService: NetworkServiceProtocol {
    static let shared = NetworkService()
    
    // Using the Tailscale Funnel public URL for the homeserver
    private let baseURL = "https://homeserver.taildbc5d3.ts.net/api/v1"
    
    private init() {}
    
    func register(businessName: String, businessType: String, phone: String, pin: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/auth/register") else { throw NetworkError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "business_name": businessName,
            "business_type": businessType,
            "phone": phone,
            "pin": pin
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.serverError("Invalid response type") }
        
        if httpResponse.statusCode == 201 {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String {
                return token
            }
            throw NetworkError.decodingError
        } else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["error"] as? String {
                throw NetworkError.serverError(errorMsg)
            }
            throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }
    
    func login(phone: String, pin: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/auth/login") else { throw NetworkError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "phone": phone,
            "pin": pin
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else { throw NetworkError.serverError("Invalid response type") }
        
        if httpResponse.statusCode == 200 {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String {
                return token
            }
            throw NetworkError.decodingError
        } else if httpResponse.statusCode == 401 {
            throw NetworkError.unauthorized
        } else {
             if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["error"] as? String {
                throw NetworkError.serverError(errorMsg)
            }
            throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }
}
