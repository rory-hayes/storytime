import SwiftUI

struct StorySeriesDetailView: View {
    let seriesId: UUID
    @ObservedObject var store: StoryLibraryStore

    @State private var showDeleteConfirmation = false

    var body: some View {
        Group {
            if let series {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(series)
                        continuityCard(series)
                        actionsRow(series)
                        episodeList(series)
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
        .toolbar {
            if series != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .alert("Delete this series?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                store.deleteSeries(seriesId)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved episodes and local continuity memory for this series.")
        }
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

    private func continuityCard(_ series: StorySeries) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Series memory")
                .font(.system(size: 16, weight: .bold, design: .rounded))

            if let arcSummary = series.arcSummary, !arcSummary.isEmpty {
                Text(arcSummary)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }

            if let places = series.favoritePlaces, !places.isEmpty {
                Text("Places: \(places.prefix(3).joined(separator: ", "))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let relationships = series.relationshipFacts, !relationships.isEmpty {
                Text("Relationships: \(relationships.prefix(2).joined(separator: " • "))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if let threads = series.unresolvedThreads, !threads.isEmpty {
                Text("Open threads: \(threads.prefix(2).joined(separator: " • "))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.88))
        )
    }

    private func actionsRow(_ series: StorySeries) -> some View {
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
