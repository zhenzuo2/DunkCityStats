import SwiftUI
import AuthenticationServices

struct PlayerDetailView: View {
    fileprivate enum MetricCategory {
        case offense
        case defense
        case athleticism

        var color: Color {
            switch self {
            case .offense:
                return .orange
            case .defense:
                return .blue
            case .athleticism:
                return .green
            }
        }
    }

    fileprivate struct PlayerMetric: Identifiable {
        let id: String
        let titleKey: String
        let keyPath: KeyPath<Player, Int>
        let category: MetricCategory

        func value(for player: Player) -> Int {
            player[keyPath: keyPath]
        }
    }

    private enum CommentSortOption: String, CaseIterable, Identifiable {
        case date
        case rating

        var id: String { rawValue }

        var localizedTitleKey: String {
            switch self {
            case .date:
                return "player_detail.feedback.sort_date"
            case .rating:
                return "player_detail.feedback.sort_rating"
            }
        }
    }

    let player: Player
    @EnvironmentObject private var dataLoader: DataLoader
    @EnvironmentObject private var feedbackStore: PlayerFeedbackStore
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @Environment(\.locale) private var locale
    @State private var selectedRating = 5
    @State private var commentText = ""
    @State private var commentSortOption: CommentSortOption = .date
    @State private var showFavoriteSignInSheet = false

    private var feedbackItems: [PlayerFeedback] {
        feedbackStore.feedback(for: player.name)
    }

    private var sortedFeedbackItems: [PlayerFeedback] {
        switch commentSortOption {
        case .date:
            return feedbackItems.sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.rating > $1.rating
                }
                return $0.createdAt > $1.createdAt
            }
        case .rating:
            return feedbackItems.sorted {
                if $0.rating == $1.rating {
                    return $0.createdAt > $1.createdAt
                }
                return $0.rating > $1.rating
            }
        }
    }

    private var averageRating: Double? {
        feedbackStore.averageRating(for: player.name)
    }

    private var otherUsersAverageRating: Double? {
        guard let userIdentifier = feedbackStore.signedInUserIdentifier,
              !userIdentifier.isEmpty else {
            return nil
        }
        return feedbackStore.averageRating(
            for: player.name,
            excludingUserIdentifier: userIdentifier
        )
    }

    private var totalText: String {
        L10n.format("player_detail.total_format", locale: locale, player.total)
    }

    private var avgText: String {
        L10n.format("player_detail.avg_format", locale: locale, player.avgAttribute)
    }

    private var isFavorite: Bool {
        favoritesStore.isFavorite(player.name)
    }

    private var summaryMetrics: [PlayerMetric] {
        [
            PlayerMetric(
                id: "offense",
                titleKey: "stat.full.offense",
                keyPath: \.offense,
                category: .offense
            ),
            PlayerMetric(
                id: "defense",
                titleKey: "stat.full.defense",
                keyPath: \.defense,
                category: .defense
            ),
            PlayerMetric(
                id: "athleticism",
                titleKey: "stat.full.athleticism",
                keyPath: \.athleticism,
                category: .athleticism
            )
        ]
    }

    private var offenseCoreMetrics: [PlayerMetric] {
        [
            PlayerMetric(id: "dunk", titleKey: "stat.full.dunk", keyPath: \.dunk, category: .offense),
            PlayerMetric(id: "layupClose", titleKey: "stat.full.layup_close", keyPath: \.layupClose, category: .offense),
            PlayerMetric(id: "midRange", titleKey: "stat.full.mid_range", keyPath: \.midRange, category: .offense),
            PlayerMetric(id: "threePoint", titleKey: "stat.full.three_pt", keyPath: \.threePoint, category: .offense),
            PlayerMetric(id: "dribble", titleKey: "stat.full.dribble", keyPath: \.dribble, category: .offense),
            PlayerMetric(id: "pass", titleKey: "stat.full.pass", keyPath: \.pass, category: .offense)
        ]
    }

    private var defenseCoreMetrics: [PlayerMetric] {
        [
            PlayerMetric(id: "steal", titleKey: "stat.full.steal", keyPath: \.steal, category: .defense),
            PlayerMetric(id: "block", titleKey: "stat.full.block", keyPath: \.block, category: .defense),
            PlayerMetric(id: "rebound", titleKey: "stat.full.rebound", keyPath: \.rebound, category: .defense),
            PlayerMetric(id: "contest", titleKey: "stat.full.contest", keyPath: \.contest, category: .defense),
            PlayerMetric(id: "consistency", titleKey: "stat.full.consistency", keyPath: \.consistency, category: .defense)
        ]
    }

    private var athleticismCoreMetrics: [PlayerMetric] {
        [
            PlayerMetric(id: "vertical", titleKey: "stat.full.vertical", keyPath: \.vertical, category: .athleticism),
            PlayerMetric(id: "movement", titleKey: "stat.full.movement", keyPath: \.movement, category: .athleticism),
            PlayerMetric(id: "strength", titleKey: "stat.full.strength", keyPath: \.strength, category: .athleticism)
        ]
    }

    private func maxValue(for metric: PlayerMetric) -> Int {
        let loadedMax = dataLoader.players.map { metric.value(for: $0) }.max() ?? 0
        return max(1, max(loadedMax, metric.value(for: player)))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                PlayerHeadshotView(player: player, size: 108, cornerRadius: 16)

                VStack(alignment: .leading, spacing: 6) {
                    Text(player.position)
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .foregroundStyle(.orange)
                    HStack(spacing: 16) {
                        Label(totalText, systemImage: "star.fill")
                            .foregroundStyle(.primary)
                        Text(avgText)
                            .foregroundStyle(.secondary)
                    }
                    .font(.headline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var summaryAttributesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("player_detail.summary_attributes")
                .font(.headline)

            VStack(spacing: 10) {
                ForEach(summaryMetrics) { metric in
                    StatRow(
                        titleKey: metric.titleKey,
                        value: metric.value(for: player),
                        maxValue: maxValue(for: metric),
                        tintColor: metric.category.color,
                        titleLineLimit: 1
                    )
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var groupedAttributesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("player_detail.attributes")
                .font(.headline)

            MetricGroupSection(
                groupTitleKey: "stat.full.offense",
                titleColor: MetricCategory.offense.color,
                tintColor: MetricCategory.offense.color,
                metrics: offenseCoreMetrics,
                player: player,
                maxValue: maxValue(for:)
            )

            MetricGroupSection(
                groupTitleKey: "stat.full.defense",
                titleColor: MetricCategory.defense.color,
                tintColor: MetricCategory.defense.color,
                metrics: defenseCoreMetrics,
                player: player,
                maxValue: maxValue(for:)
            )

            MetricGroupSection(
                groupTitleKey: "stat.full.athleticism",
                titleColor: MetricCategory.athleticism.color,
                tintColor: MetricCategory.athleticism.color,
                metrics: athleticismCoreMetrics,
                player: player,
                maxValue: maxValue(for:)
            )
        }
        .padding()
        .background(Color.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    summaryAttributesCard
                    groupedAttributesCard

                    feedbackSection
                }
                .padding()
            }
        }
        .navigationTitle(player.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let result = favoritesStore.toggleFavorite(
                        player.name,
                        isSignedIn: feedbackStore.isSignedInWithApple,
                        userIdentifier: feedbackStore.signedInUserIdentifier
                    )
                    if result == .requiresSignIn {
                        showFavoriteSignInSheet = true
                    }
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : .secondary)
                }
                .accessibilityLabel(
                    isFavorite
                    ? Text("player_detail.favorite.remove")
                    : Text("player_detail.favorite.add")
                )
            }
        }
        .onAppear {
            favoritesStore.configureSession(
                isSignedIn: feedbackStore.isSignedInWithApple,
                userIdentifier: feedbackStore.signedInUserIdentifier
            )
            feedbackStore.loadFeedback(for: player.name)
        }
        .onChange(of: feedbackStore.isSignedInWithApple) { _, _ in
            favoritesStore.configureSession(
                isSignedIn: feedbackStore.isSignedInWithApple,
                userIdentifier: feedbackStore.signedInUserIdentifier
            )
        }
        .onChange(of: feedbackStore.signedInUserIdentifier) { _, _ in
            favoritesStore.configureSession(
                isSignedIn: feedbackStore.isSignedInWithApple,
                userIdentifier: feedbackStore.signedInUserIdentifier
            )
        }
        .sheet(isPresented: $showFavoriteSignInSheet) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 14) {
                    Text("player_detail.favorite.sign_in_required")
                        .font(.headline)
                    Text("player_detail.favorite.sign_in_hint")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        feedbackStore.handleSignInResult(result)
                        favoritesStore.configureSession(
                            isSignedIn: feedbackStore.isSignedInWithApple,
                            userIdentifier: feedbackStore.signedInUserIdentifier
                        )
                        if feedbackStore.isSignedInWithApple {
                            if !favoritesStore.isFavorite(player.name) {
                                _ = favoritesStore.toggleFavorite(
                                    player.name,
                                    isSignedIn: feedbackStore.isSignedInWithApple,
                                    userIdentifier: feedbackStore.signedInUserIdentifier
                                )
                            }
                            showFavoriteSignInSheet = false
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 48)

                    Spacer(minLength: 0)
                }
                .padding()
                .navigationTitle("player_detail.favorite.sign_in_title")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("common.cancel") {
                            showFavoriteSignInSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.height(250)])
        }
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("player_detail.feedback.title")
                .font(.headline)

            if feedbackStore.isLoadingFeedback(for: player.name) {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("player_detail.feedback.loading")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                StarRatingView(rating: Int((averageRating ?? 0).rounded()), size: 14)
                if let averageRating {
                    Text(L10n.format("player_detail.feedback.avg_rating", locale: locale, averageRating))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(
                        L10n.format("player_detail.feedback.rating_count", locale: locale, feedbackItems.count)
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("player_detail.feedback.no_ratings")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let otherUsersAverageRating {
                Text(
                    L10n.format(
                        "player_detail.feedback.others_avg_rating",
                        locale: locale,
                        otherUsersAverageRating
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            HStack {
                Text("player_detail.feedback.sort_by")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Picker("player_detail.feedback.sort_by", selection: $commentSortOption) {
                    ForEach(CommentSortOption.allCases) { option in
                        Text(LocalizedStringKey(option.localizedTitleKey))
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 12) {
                if feedbackStore.isSignedInWithApple {
                    if let displayName = feedbackStore.signedInDisplayName {
                        Text(L10n.format("player_detail.feedback.signed_in_as", locale: locale, displayName))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Text("player_detail.feedback.your_rating")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    StarRatingPicker(rating: $selectedRating)

                    Text("player_detail.feedback.your_comment")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    ZStack(alignment: .topLeading) {
                        if commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("player_detail.feedback.comment_placeholder")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 12)
                        }
                        TextEditor(text: $commentText)
                            .frame(minHeight: 88)
                            .padding(4)
                            .background(.clear)
                    }
                    .background(Color.white.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button {
                        feedbackStore.addFeedback(
                            for: player.name,
                            rating: selectedRating,
                            comment: commentText
                        )
                        commentText = ""
                    } label: {
                        Text("player_detail.feedback.submit")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(.white)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Text("player_detail.feedback.sign_in_required")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        feedbackStore.handleSignInResult(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 44)
                }
            }
            .padding()
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let statusMessage = feedbackStore.statusMessage, !statusMessage.isEmpty {
                Text("\(L10n.string("player_detail.feedback.sync_error", locale: locale)) \(statusMessage)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let favoritesStatusMessage = favoritesStore.syncStatusMessage, !favoritesStatusMessage.isEmpty {
                Text("\(L10n.string("favorites.sync_error", locale: locale)) \(favoritesStatusMessage)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if sortedFeedbackItems.isEmpty {
                Text("player_detail.feedback.no_comments")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedFeedbackItems) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                StarRatingView(rating: entry.rating, size: 13)
                                Spacer()
                                Text(entry.createdAt, format: .dateTime.year().month().day().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.authorName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(entry.comment)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct StatRow: View {
    let titleKey: String
    let value: Int
    let maxValue: Int
    let tintColor: Color
    let titleLineLimit: Int

    init(
        titleKey: String,
        value: Int,
        maxValue: Int,
        tintColor: Color,
        titleLineLimit: Int = 2
    ) {
        self.titleKey = titleKey
        self.value = value
        self.maxValue = maxValue
        self.tintColor = tintColor
        self.titleLineLimit = titleLineLimit
    }

    private var progress: CGFloat {
        guard maxValue > 0 else { return 0 }
        return min(1, max(0, CGFloat(value) / CGFloat(maxValue)))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(titleKey))
                    .foregroundColor(.secondary)
                    .lineLimit(titleLineLimit)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)
                    .allowsTightening(true)
                    .layoutPriority(1)
                Spacer()
                Text(String(value))
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .fixedSize()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(tintColor)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.72))
        .cornerRadius(8)
    }
}

private struct MetricGroupSection: View {
    let groupTitleKey: String
    let titleColor: Color
    let tintColor: Color
    let metrics: [PlayerDetailView.PlayerMetric]
    let player: Player
    let maxValue: (PlayerDetailView.PlayerMetric) -> Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(groupTitleKey))
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(titleColor)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(metrics) { metric in
                    StatRow(
                        titleKey: metric.titleKey,
                        value: metric.value(for: player),
                        maxValue: maxValue(metric),
                        tintColor: tintColor
                    )
                }
            }
        }
    }
}

struct StarRatingPicker: View {
    @Binding var rating: Int
    @Environment(\.locale) private var locale
    var maxRating: Int = 5
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...maxRating, id: \.self) { value in
                Button {
                    rating = value
                } label: {
                    Image(systemName: value <= rating ? "star.fill" : "star")
                        .font(.system(size: size))
                        .foregroundStyle(value <= rating ? .yellow : .gray.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityLabel(
            L10n.format("player_detail.feedback.rating_accessibility", locale: locale, rating, maxRating)
        )
    }
}

struct StarRatingView: View {
    let rating: Int
    var maxRating: Int = 5
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...maxRating, id: \.self) { value in
                Image(systemName: value <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(value <= rating ? .yellow : .gray.opacity(0.4))
            }
        }
    }
}
