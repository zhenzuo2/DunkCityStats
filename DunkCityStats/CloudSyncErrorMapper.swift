import Foundation
import CloudKit

enum CloudSyncErrorMapper {
    static func userMessage(from error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain,
           let code = CKError.Code(rawValue: nsError.code) {
            switch code {
            case .notAuthenticated:
                return "iCloud is not signed in on this device."
            case .badContainer, .permissionFailure:
                return "CloudKit is not configured for this app yet. Configure iCloud container and CloudKit in Signing & Capabilities."
            case .networkUnavailable, .networkFailure:
                return "Network unavailable. Cloud sync will retry when online."
            default:
                break
            }
        }

        let lowerDescription = nsError.localizedDescription.lowercased()
        if lowerDescription.contains("unknown container") {
            return "CloudKit container not found. In Xcode, enable iCloud + CloudKit and select/create container iCloud.zz.DunkCityStats."
        }

        return nsError.localizedDescription
    }
}
