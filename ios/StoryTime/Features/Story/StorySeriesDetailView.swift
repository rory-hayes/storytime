import SwiftUI

struct StorySeriesDetailView: View {
    let seriesId: UUID
    @ObservedObject var store: StoryLibraryStore

    var body: some View {
        Group {
            if let series {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(series)
                        continueStoryCard(series)
                        continuityCard(series)
                        episodeList(series)
                        managementCard
                    }
                    .padding(20)
                }
            } else {
                Text("Series not found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("seriesNotFoundLabel")
            }
        }
        .navigationTitle("Story Series")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func header(_ series: StorySeries) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(series.title)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .accessibilityIdentifier("seriesDetailTitle")

            Text("Episodes: \(series.episodeCount)")
                .foregroundStyle(.secondary)

            if let profileName = store.profileById(series.childProfileId)?.displayName {
                Text(profileName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white))
            }
        }
    }

    private func continueStoryCard(_ series: StorySeries) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Continue this story")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .accessibilityIdentifier("seriesDetailContinueTitle")

            Text("Replay the latest adventure or start a new episode that keeps this world, these characters, and this child's saved continuity together.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("seriesDetailContinueSummary")

            HStack(spacing: 10) {
                NavigationLink {
                    VoiceSessionView(
                        plan: StoryLaunchPlan(
                            mode: .repeatEpisode(seriesId: series.id),
                            childProfileId: store.activeProfile?.id ?? series.childProfileId ?? UUID(),
                            experienceMode: store.activeProfile?.preferredMode ?? .classic,
                            usePastStory: true,
                            selectedSeriesId: series.id,
                            usePastCharacters: true,
                            lengthMinutes: max(1, min(10, (series.latestEpisode?.estimatedDurationSec ?? 240) / 60))
                        ),
                        sourceSeries: series,
                        store: store
                    )
                } label: {
                    Label("Repeat", systemImage: "repeat")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("repeatEpisodeButton")

                NavigationLink {
                    VoiceSessionView(
                        plan: StoryLaunchPlan(
                            mode: .extend(seriesId: series.id),
                            childProfileId: store.activeProfile?.id ?? series.childProfileId ?? UUID(),
                            experienceMode: store.activeProfile?.preferredMode ?? .classic,
                            usePastStory: true,
                            selectedSeriesId: series.id,
                            usePastCharacters: true,
                            lengthMinutes: 4
                        ),
                        sourceSeries: series,
                        store: store
                    )
                } label: {
                    Label("New Episode", systemImage: "plus.app")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("newEpisodeButton")
            }

            Text("New episodes stay linked to this saved series for the selected child.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("seriesDetailContinueScopeHint")
        }
        .padding(16)
        .background(cardBackground)
    }

    private func continuityCard(_ series: StorySeries) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Story memory for the next episode")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .accessibilityIdentifier("seriesDetailContinuityTitle")

            Text("StoryTime uses these saved details to keep future episodes familiar without changing earlier ones.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("seriesDetailContinuitySummary")

            if let arcSummary = series.arcSummary, !arcSummary.isEmpty {
                Text(arcSummary)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }

            if let places = series.favoritePlaces, !places.isEmpty {
                Text("Places to revisit: \(places.prefix(3).joined(separator: ", "))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let relationships = series.relationshipFacts, !relationships.isEmpty {
                Text("Important relationships: \(relationships.prefix(2).joined(separator: " • "))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let threads = series.unresolvedThreads, !threads.isEmpty {
                Text("Open story threads: \(threads.prefix(2).joined(separator: " • "))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var managementCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saved-story management")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .accessibilityIdentifier("seriesDetailManagementTitle")

            Text("Parents can remove saved stories or clear all saved story history from Parent Controls.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("seriesDetailParentControlsHint")
        }
        .padding(.top, 4)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.white.opacity(0.88))
    }

    private func episodeList(_ series: StorySeries) -> some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(series.episodes.reversed()) { episode in
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.title)
                        .font(.headline)
                    Text(episode.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Scenes: \(episode.scenes.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white)
                )
            }
        }
    }

    private var series: StorySeries? {
        store.seriesById(seriesId)
    }
}
