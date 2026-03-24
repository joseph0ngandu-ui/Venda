import LocalAuthentication
import Foundation

public final class BiometricAuthManager {
    public static let shared = BiometricAuthManager()
    private init() {}

    public enum BiometricError: Error, LocalizedError {
        case biometryNotAvailable
        case biometryNotEnrolled
        case biometryLockedout
        case canceled
        case fallback
        case systemCancel
        case appCancel
        case unknown(NSError)

        public var errorDescription: String? {
            switch self {
            case .biometryNotAvailable:
                return "Biometric authentication is not available on this device."
            case .biometryNotEnrolled:
                return "No biometric identities are enrolled."
            case .biometryLockedout:
                return "Biometric authentication is locked out due to too many failed attempts."
            case .canceled:
                return "Authentication was canceled by the user."
            case .fallback:
                return "Fallback authentication method was selected."
            case .systemCancel:
                return "Authentication was canceled by the system."
            case .appCancel:
                return "Authentication was canceled by the application."
            case .unknown(let error):
                return error.localizedDescription
            }
        }
    }

    @discardableResult
    public func authenticate(reason: String = "Authenticate to continue") async -> Result<Bool, BiometricError> {
        let context = LAContext()
        context.localizedFallbackTitle = ""

        var nsError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &nsError) else {
            if let error = nsError {
                return .failure(Self.mapError(error))
            } else {
                return .failure(.biometryNotAvailable)
            }
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
                if success {
                    continuation.resume(returning: .success(true))
                } else if let error = error as NSError? {
                    continuation.resume(returning: .failure(Self.mapError(error)))
                } else {
                    continuation.resume(returning: .failure(.unknown(NSError(domain: "BiometricAuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred."]))))
                }
            }
        }
    }

    private static func mapError(_ error: NSError) -> BiometricError {
        guard error.domain == LAError.errorDomain else {
            return .unknown(error)
        }

        switch LAError.Code(rawValue: error.code) {
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .biometryLockedout
        case .userCancel:
            return .canceled
        case .userFallback:
            return .fallback
        case .systemCancel:
            return .systemCancel
        case .appCancel:
            return .appCancel
        default:
            return .unknown(error)
        }
    }
}
