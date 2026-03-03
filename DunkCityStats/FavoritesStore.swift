import Foundation
import Combine
import CloudKit
import CryptoKit

@MainActor
final class FavoritesStore: ObservableObject {
    enum ToggleResult {
        case updated
        case requiresSignIn
    }

    @Published private(set) var favoritePlayerNames: Set<String> = []
    @Published private(set) var syncStatusMessage: String?
    @Published private(set) var isSyncing = false

    private let legacyFavoritesKey = "dunk_city_favorite_player_names"
    private let favoritesKeyPrefix = "dunk_city_favorite_player_names_user_"

    private let recordType = "PlayerFavorite"
    private let fieldPlayerName = "playerName"
    private let fieldUserIdentifier = "userIdentifier"
    private let fieldCreatedAt = "createdAt"
    private let database = CKContainer.default().publicCloudDatabase

    private var currentUserIdentifier: String?
    private var didLoadCloudForCurrentUser = false
    private var recordNameByPlayer: [String: String] = [:]

    func isFavorite(_ playerName: String) -> Bool {
        favoritePlayerNames.contains(normalizedName(playerName))
    }

    func configureSession(isSignedIn: Bool, userIdentifier: String?) {
        guard isSignedIn, let userIdentifier = normalizedUserIdentifier(userIdentifier) else {
            clearSession()
            return
        }

        if currentUserIdentifier != userIdentifier {
            currentUserIdentifier = userIdentifier
            didLoadCloudForCurrentUser = false
            recordNameByPlayer = [:]

            favoritePlayerNames = restoreFavorites(for: userIdentifier)
            migrateLegacyFavoritesIfNeeded(for: userIdentifier)
        }

        guard !didLoadCloudForCurrentUser else { return }
        didLoadCloudForCurrentUser = true
        fetchCloudFavorites(for: userIdentifier)
    }

    @discardableResult
    func toggleFavorite(
        _ playerName: String,
        isSignedIn: Bool,
        userIdentifier: String?
    ) -> ToggleResult {
        guard isSignedIn, let userIdentifier = normalizedUserIdentifier(userIdentifier) else {
            return .requiresSignIn
        }

        configureSession(isSignedIn: isSignedIn, userIdentifier: userIdentifier)

        let name = normalizedName(playerName)
        guard !name.isEmpty else { return .updated }

        if favoritePlayerNames.contains(name) {
            favoritePlayerNames.remove(name)
            persistFavorites(for: userIdentifier)
            removeFavoriteFromCloud(playerName: name, userIdentifier: userIdentifier)
        } else {
            favoritePlayerNames.insert(name)
            persistFavorites(for: userIdentifier)
            upsertFavoriteInCloud(playerName: name, userIdentifier: userIdentifier)
        }
        return .updated
    }

    private func normalizedName(_ playerName: String) -> String {
        playerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedUserIdentifier(_ userIdentifier: String?) -> String? {
        guard let userIdentifier else { return nil }
        let trimmed = userIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func cacheKey(for userIdentifier: String) -> String {
        "\(favoritesKeyPrefix)\(userIdentifier)"
    }

    private func restoreFavorites(for userIdentifier: String) -> Set<String> {
        let names = UserDefaults.standard.stringArray(forKey: cacheKey(for: userIdentifier)) ?? []
        return Set(names.map(normalizedName).filter { !$0.isEmpty })
    }

    private func persistFavorites(for userIdentifier: String) {
        let names = Array(favoritePlayerNames).sorted()
        UserDefaults.standard.set(names, forKey: cacheKey(for: userIdentifier))
    }

    private func migrateLegacyFavoritesIfNeeded(for userIdentifier: String) {
        guard favoritePlayerNames.isEmpty else { return }
        let names = UserDefaults.standard.stringArray(forKey: legacyFavoritesKey) ?? []
        let legacyFavorites = Set(names.map(normalizedName).filter { !$0.isEmpty })
        guard !legacyFavorites.isEmpty else { return }

        favoritePlayerNames = legacyFavorites
        persistFavorites(for: userIdentifier)
        UserDefaults.standard.removeObject(forKey: legacyFavoritesKey)

        for playerName in legacyFavorites {
            upsertFavoriteInCloud(playerName: playerName, userIdentifier: userIdentifier)
        }
    }

    private func clearSession() {
        currentUserIdentifier = nil
        didLoadCloudForCurrentUser = false
        recordNameByPlayer = [:]
        favoritePlayerNames = []
        syncStatusMessage = nil
        isSyncing = false
    }

    private func fetchCloudFavorites(for userIdentifier: String) {
        isSyncing = true
        syncStatusMessage = nil

        let predicate = NSPredicate(format: "%K == %@", fieldUserIdentifier, userIdentifier)
        let query = CKQuery(recordType: recordType, predicate: predicate)
        let operation = CKQueryOperation(query: query)
        operation.resultsLimit = 500

        var cloudFavorites = Set<String>()
        var cloudRecordNames: [String: String] = [:]

        operation.recordMatchedBlock = { [weak self] _, result in
            guard let self else { return }
            switch result {
            case .success(let record):
                guard let rawName = record[self.fieldPlayerName] as? String else { return }
                let name = self.normalizedName(rawName)
                guard !name.isEmpty else { return }
                cloudFavorites.insert(name)
                cloudRecordNames[name] = record.recordID.recordName
            case .failure(let error):
                print("Favorite record parse error: \(error.localizedDescription)")
            }
        }

        operation.queryResultBlock = { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSyncing = false

                switch result {
                case .success:
                    guard self.currentUserIdentifier == userIdentifier else { return }

                    let merged = self.favoritePlayerNames.union(cloudFavorites)
                    self.favoritePlayerNames = merged
                    self.recordNameByPlayer.merge(cloudRecordNames) { _, new in new }
                    self.persistFavorites(for: userIdentifier)

                    let missingFromCloud = merged.subtracting(cloudFavorites)
                    for playerName in missingFromCloud {
                        self.upsertFavoriteInCloud(
                            playerName: playerName,
                            userIdentifier: userIdentifier
                        )
                    }

                case .failure(let error):
                    self.syncStatusMessage = CloudSyncErrorMapper.userMessage(from: error)
                }
            }
        }

        database.add(operation)
    }

    private func upsertFavoriteInCloud(playerName: String, userIdentifier: String) {
        let recordName = cloudRecordName(playerName: playerName, userIdentifier: userIdentifier)
        let recordID = CKRecord.ID(recordName: recordName)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record[fieldPlayerName] = playerName as CKRecordValue
        record[fieldUserIdentifier] = userIdentifier as CKRecordValue
        record[fieldCreatedAt] = Date() as CKRecordValue

        database.save(record) { [weak self] savedRecord, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.currentUserIdentifier == userIdentifier else { return }
                if let error {
                    self.syncStatusMessage = CloudSyncErrorMapper.userMessage(from: error)
                    return
                }
                self.syncStatusMessage = nil
                self.recordNameByPlayer[playerName] = savedRecord?.recordID.recordName ?? recordName
            }
        }
    }

    private func removeFavoriteFromCloud(playerName: String, userIdentifier: String) {
        let recordName = recordNameByPlayer[playerName]
        ?? cloudRecordName(playerName: playerName, userIdentifier: userIdentifier)
        let recordID = CKRecord.ID(recordName: recordName)

        database.delete(withRecordID: recordID) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.currentUserIdentifier == userIdentifier else { return }
                if let ckError = error as? CKError, ckError.code == .unknownItem {
                    self.recordNameByPlayer.removeValue(forKey: playerName)
                    return
                }
                if let error {
                    self.syncStatusMessage = CloudSyncErrorMapper.userMessage(from: error)
                    return
                }
                self.syncStatusMessage = nil
                self.recordNameByPlayer.removeValue(forKey: playerName)
            }
        }
    }

    private func cloudRecordName(playerName: String, userIdentifier: String) -> String {
        let composite = "\(userIdentifier.lowercased())::\(playerName.lowercased())"
        let digest = SHA256.hash(data: Data(composite.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return "favorite_\(hex)"
    }
}
