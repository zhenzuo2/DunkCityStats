import Foundation
import Combine
import CloudKit
import AuthenticationServices

struct PlayerFeedback: Identifiable, Hashable {
    let id: String
    let rating: Int
    let comment: String
    let createdAt: Date
    let authorName: String
    let userIdentifier: String

    init(
        id: String,
        rating: Int,
        comment: String,
        createdAt: Date,
        authorName: String,
        userIdentifier: String
    ) {
        self.id = id
        self.rating = max(1, min(5, rating))
        self.comment = comment
        self.createdAt = createdAt
        self.authorName = authorName
        self.userIdentifier = userIdentifier
    }
}

@MainActor
final class PlayerFeedbackStore: ObservableObject {
    @Published private(set) var feedbackByPlayer: [String: [PlayerFeedback]] = [:]
    @Published private(set) var loadingPlayers: Set<String> = []
    @Published private(set) var isSignedInWithApple = false
    @Published private(set) var signedInUserIdentifier: String?
    @Published private(set) var signedInDisplayName: String?
    @Published private(set) var statusMessage: String?

    private let userIdentifierKey = "dunk_city_apple_user_identifier"
    private let userDisplayNameKey = "dunk_city_apple_display_name"

    private let recordType = "PlayerFeedback"
    private let fieldPlayerName = "playerName"
    private let fieldRating = "rating"
    private let fieldComment = "comment"
    private let fieldCreatedAt = "createdAt"
    private let fieldAuthorName = "authorName"
    private let fieldUserIdentifier = "userIdentifier"

    private let database = CKContainer.default().publicCloudDatabase

    init() {
        restoreSignInSession()
    }

    func feedback(for playerName: String) -> [PlayerFeedback] {
        feedbackByPlayer[playerName] ?? []
    }

    func averageRating(for playerName: String) -> Double? {
        averageRating(for: playerName, excludingUserIdentifier: nil)
    }

    func averageRating(for playerName: String, excludingUserIdentifier: String?) -> Double? {
        let trimmedExcludedUserIdentifier = excludingUserIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let items = feedback(for: playerName).filter { item in
            guard let trimmedExcludedUserIdentifier, !trimmedExcludedUserIdentifier.isEmpty else {
                return true
            }
            return item.userIdentifier != trimmedExcludedUserIdentifier
        }
        guard !items.isEmpty else { return nil }
        let total = items.reduce(0) { $0 + $1.rating }
        return Double(total) / Double(items.count)
    }

    func isLoadingFeedback(for playerName: String) -> Bool {
        loadingPlayers.contains(playerName)
    }

    func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                statusMessage = "Sign in failed. Please try again."
                return
            }

            let userIdentifier = credential.user
            var displayName = signedInDisplayName

            let formatter = PersonNameComponentsFormatter()
            let formattedName = formatter
                .string(from: credential.fullName ?? PersonNameComponents())
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !formattedName.isEmpty {
                displayName = formattedName
            }
            if displayName?.isEmpty != false {
                displayName = "Apple User"
            }

            signedInUserIdentifier = userIdentifier
            signedInDisplayName = displayName
            isSignedInWithApple = true
            statusMessage = nil

            UserDefaults.standard.set(userIdentifier, forKey: userIdentifierKey)
            UserDefaults.standard.set(displayName, forKey: userDisplayNameKey)
            validateAppleCredentialState(for: userIdentifier)

        case .failure(let error):
            statusMessage = error.localizedDescription
        }
    }

    func loadFeedback(for playerName: String) {
        let trimmedPlayerName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPlayerName.isEmpty else { return }
        guard !loadingPlayers.contains(trimmedPlayerName) else { return }

        statusMessage = nil
        loadingPlayers.insert(trimmedPlayerName)

        fetchFeedbackPage(
            for: trimmedPlayerName,
            cursor: nil,
            accumulator: []
        )
    }

    func addFeedback(for playerName: String, rating: Int, comment: String) {
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPlayerName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPlayerName.isEmpty, !trimmedComment.isEmpty else {
            return
        }
        guard isSignedInWithApple, let userIdentifier = signedInUserIdentifier else {
            statusMessage = "Please sign in with Apple to comment."
            return
        }

        statusMessage = nil

        let record = CKRecord(recordType: recordType)
        record[fieldPlayerName] = trimmedPlayerName as CKRecordValue
        record[fieldRating] = Int64(max(1, min(5, rating))) as CKRecordValue
        record[fieldComment] = trimmedComment as CKRecordValue
        record[fieldCreatedAt] = Date() as CKRecordValue
        record[fieldUserIdentifier] = userIdentifier as CKRecordValue
        record[fieldAuthorName] = (signedInDisplayName ?? "Apple User") as CKRecordValue

        database.save(record) { [weak self] savedRecord, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.statusMessage = CloudSyncErrorMapper.userMessage(from: error)
                    return
                }
                if let savedRecord, let parsed = self.parseFeedback(from: savedRecord) {
                    var items = self.feedbackByPlayer[trimmedPlayerName] ?? []
                    items.insert(parsed, at: 0)
                    self.feedbackByPlayer[trimmedPlayerName] = items.sorted { $0.createdAt > $1.createdAt }
                } else {
                    self.loadFeedback(for: trimmedPlayerName)
                }
            }
        }
    }

    private func restoreSignInSession() {
        guard let userIdentifier = UserDefaults.standard.string(forKey: userIdentifierKey),
              !userIdentifier.isEmpty else {
            return
        }
        signedInUserIdentifier = userIdentifier
        signedInDisplayName = UserDefaults.standard.string(forKey: userDisplayNameKey) ?? "Apple User"
        isSignedInWithApple = true
        validateAppleCredentialState(for: userIdentifier)
    }

    private func validateAppleCredentialState(for userIdentifier: String) {
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userIdentifier) { [weak self] state, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .authorized:
                    self.isSignedInWithApple = true
                case .revoked, .notFound, .transferred:
                    self.clearSignInSession()
                @unknown default:
                    break
                }
            }
        }
    }

    private func clearSignInSession() {
        isSignedInWithApple = false
        signedInUserIdentifier = nil
        signedInDisplayName = nil
        UserDefaults.standard.removeObject(forKey: userIdentifierKey)
        UserDefaults.standard.removeObject(forKey: userDisplayNameKey)
    }

    private func fetchFeedbackPage(
        for playerName: String,
        cursor: CKQueryOperation.Cursor?,
        accumulator: [PlayerFeedback]
    ) {
        let operation: CKQueryOperation
        if let cursor {
            operation = CKQueryOperation(cursor: cursor)
        } else {
            let predicate = NSPredicate(format: "%K == %@", fieldPlayerName, playerName)
            let query = CKQuery(recordType: recordType, predicate: predicate)
            query.sortDescriptors = [NSSortDescriptor(key: fieldCreatedAt, ascending: false)]
            operation = CKQueryOperation(query: query)
            operation.resultsLimit = 200
        }

        let lock = NSLock()
        var nextAccumulator = accumulator

        operation.recordMatchedBlock = { [weak self] _, result in
            guard let self else { return }
            switch result {
            case .success(let record):
                if let feedback = self.parseFeedback(from: record) {
                    lock.lock()
                    nextAccumulator.append(feedback)
                    lock.unlock()
                }
            case .failure(let error):
                print("CloudKit record parse error: \(error.localizedDescription)")
            }
        }

        operation.queryResultBlock = { [weak self] result in
            Task { @MainActor in
                guard let self else { return }

                switch result {
                case .success(let nextCursor):
                    if let nextCursor {
                        self.fetchFeedbackPage(
                            for: playerName,
                            cursor: nextCursor,
                            accumulator: nextAccumulator
                        )
                    } else {
                        self.feedbackByPlayer[playerName] = nextAccumulator.sorted { $0.createdAt > $1.createdAt }
                        self.loadingPlayers.remove(playerName)
                    }
                case .failure(let error):
                    self.loadingPlayers.remove(playerName)
                    self.statusMessage = CloudSyncErrorMapper.userMessage(from: error)
                }
            }
        }

        database.add(operation)
    }

    private func parseFeedback(from record: CKRecord) -> PlayerFeedback? {
        guard let playerName = record[fieldPlayerName] as? String,
              !playerName.isEmpty,
              let comment = record[fieldComment] as? String else {
            return nil
        }

        let rating: Int
        if let intValue = record[fieldRating] as? Int {
            rating = intValue
        } else if let int64Value = record[fieldRating] as? Int64 {
            rating = Int(int64Value)
        } else if let numberValue = record[fieldRating] as? NSNumber {
            rating = numberValue.intValue
        } else {
            rating = 0
        }
        let createdAt = (record[fieldCreatedAt] as? Date) ?? record.creationDate ?? Date()
        let authorName = (record[fieldAuthorName] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userIdentifier = (record[fieldUserIdentifier] as? String) ?? ""
        let displayName = authorName.flatMap { $0.isEmpty ? nil : $0 } ?? "Apple User"

        return PlayerFeedback(
            id: record.recordID.recordName,
            rating: rating,
            comment: comment,
            createdAt: createdAt,
            authorName: displayName,
            userIdentifier: userIdentifier
        )
    }
}
