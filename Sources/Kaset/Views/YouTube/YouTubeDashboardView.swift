import SwiftUI

// MARK: - YouTubeDashboardView

/// Signed-in YouTube home: rails for subscriptions, the user's playlists and Watch Later,
/// each linking to its full sidebar section.
struct YouTubeDashboardView: View {
    let store: YouTubeViewModelStore
    var onShowAll: ((YouTubeNavigationItem) -> Void)?

    private static let railLimit = 20

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                self.subscriptionsRail
                self.playlistsRail
                self.watchLaterRail
            }
            .padding(.vertical, 20)
        }
        .pullToRefresh {
            await self.refresh()
        }
        .navigationTitle(Text("Home", comment: "YouTube home feed title"))
        .accessibilityIdentifier(AccessibilityID.YouTubeContent.homeGrid)
        // Keyed on the store's model identities so an account switch reloads the fresh models.
        .task(id: ObjectIdentifier(self.store.subscriptions)) {
            await self.store.subscriptions.load()
        }
        .task(id: ObjectIdentifier(self.store.playlists)) {
            await self.store.playlists.load()
        }
        .task(id: ObjectIdentifier(self.store.watchLater)) {
            if self.store.watchLater.loadingState == .idle {
                await self.store.watchLater.load()
            }
        }
    }

    // MARK: - Rails

    private var subscriptionsRail: some View {
        self.rail(
            title: String(localized: "Subscriptions"),
            destination: .subscriptions,
            state: self.store.subscriptions.loadingState,
            isEmpty: self.store.subscriptions.videos.isEmpty
        ) {
            self.videoShelf(
                title: String(localized: "Subscriptions"),
                videos: Array(self.store.subscriptions.videos.prefix(Self.railLimit))
            )
        }
    }

    private var playlistsRail: some View {
        self.rail(
            title: String(localized: "Playlists"),
            destination: .playlists,
            state: self.store.playlists.loadingState,
            isEmpty: self.store.playlists.playlists.isEmpty
        ) {
            CarouselShelfSection(
                accessibilityLabel: String(localized: "Playlists"),
                items: self.store.playlists.playlists,
                itemAlignment: .top,
                contentInset: DetailContentLayout.horizontalInset
            ) {
                EmptyView()
            } itemContent: { playlist in
                NavigationLink(value: YouTubeRoute.playlist(playlistId: playlist.playlistId)) {
                    YouTubePlaylistCard(playlist: playlist)
                        .frame(width: 240)
                }
                .buttonStyle(.interactiveCard)
            }
        }
    }

    private var watchLaterRail: some View {
        let videos = self.store.watchLater.detail?.videos ?? []
        return self.rail(
            title: String(localized: "Watch Later"),
            destination: .watchLater,
            state: self.store.watchLater.loadingState,
            isEmpty: videos.isEmpty
        ) {
            self.videoShelf(
                title: String(localized: "Watch Later"),
                videos: Array(videos.prefix(Self.railLimit))
            )
        }
    }

    // MARK: - Building Blocks

    private func rail(
        title: String,
        destination: YouTubeNavigationItem,
        state: LoadingState,
        isEmpty: Bool,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                if let onShowAll {
                    Button(String(localized: "Show All")) {
                        onShowAll(destination)
                    }
                    .buttonStyle(.link)
                }
            }
            .padding(.horizontal, DetailContentLayout.horizontalInset)

            switch state {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 120)
            case let .error(error):
                Text(error.message)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DetailContentLayout.horizontalInset)
            case .loaded, .loadingMore:
                if isEmpty {
                    Text("No videos", comment: "Empty YouTube dashboard rail")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DetailContentLayout.horizontalInset)
                } else {
                    content()
                }
            }
        }
    }

    private func videoShelf(title: String, videos: [YouTubeVideo]) -> some View {
        CarouselShelfSection(
            accessibilityLabel: title,
            items: videos,
            itemAlignment: .top,
            contentInset: DetailContentLayout.horizontalInset
        ) {
            EmptyView()
        } itemContent: { video in
            NavigationLink(value: YouTubeRoute.watch(video)) {
                VideoCard(video: video)
                    .frame(width: 284)
            }
            .buttonStyle(.interactiveCard)
        }
    }

    private func refresh() async {
        async let subscriptions: Void = self.store.subscriptions.refresh()
        async let playlists: Void = self.store.playlists.refresh()
        async let watchLater: Void = self.store.watchLater.load()
        _ = await (subscriptions, playlists, watchLater)
    }
}
