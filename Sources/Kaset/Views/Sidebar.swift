import SwiftUI

/// Sidebar navigation for the main window, styled like Apple Music.
struct Sidebar: View {
    private enum SidebarSelection: Hashable {
        case navigation(NavigationItem)
        case pinned(SidebarPinnedItem)
    }

    @Binding var selection: NavigationItem?
    @Binding var pinnedSelection: SidebarPinnedItem?
    let client: any YTMusicClientProtocol
    var onReselectNavigationItem: ((NavigationItem) -> Void)?
    var onReselectPinnedItem: ((SidebarPinnedItem) -> Void)?
    @Environment(AuthService.self) private var authService
    @Environment(PlayerService.self) private var playerService
    @Environment(SidebarPinnedItemsManager.self) private var sidebarPinnedItemsManager
    @State private var isCreatingPlaylist = false
    @State private var isHoveringPlaylistsHeader = false

    var body: some View {
        List {
            // Main navigation: Home hosts search and the Discover menu.
            Section {
                self.navigationRow(.home)
                    .accessibilityIdentifier(AccessibilityID.Sidebar.homeItem)
            }

            if self.hasPersonalAccount {
                // Collection section
                Section(String(localized: "Collection")) {
                    self.navigationRow(.library)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.libraryItem)

                    self.navigationRow(.likedMusic)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.likedMusicItem)

                    self.navigationRow(.history)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.historyItem)
                }
            }

            if self.hasPersonalAccount {
                Section {
                    ForEach(self.sidebarPinnedItemsManager.items) { item in
                        self.sidebarPinnedRow(item)
                    }
                    .onMove { source, destination in
                        self.sidebarPinnedItemsManager.move(from: source, to: destination)
                    }
                } header: {
                    self.playlistsSectionHeader
                }
            }
        }
        .listStyle(.sidebar)
        .compatTranslucentSidebar()
        .accessibilityIdentifier(AccessibilityID.Sidebar.container)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // Source toggle + profile section at bottom (shared with YouTubeSidebar)
            SidebarFooterView()
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
    }

    private var hasPersonalAccount: Bool {
        self.authService.hasPersonalAccount
    }

    private var currentSidebarSelection: SidebarSelection? {
        if let pinnedSelection {
            return .pinned(pinnedSelection)
        }

        if let selection {
            return .navigation(selection)
        }

        return nil
    }

    private func navigationRow(_ item: NavigationItem) -> some View {
        KasetSidebarRow(
            title: item.displayName,
            systemImage: item.icon,
            isSelected: self.isRowSelected(item)
        ) {
            self.selectNavigationItem(item)
        }
    }

    /// Discover pages and search have no rows of their own; Home stays highlighted for them.
    private func isRowSelected(_ item: NavigationItem) -> Bool {
        if item == .home, self.pinnedSelection == nil, let selection {
            return selection == .home || selection == .search || NavigationItem.discoverItems.contains(selection)
        }
        return self.currentSidebarSelection == .navigation(item)
    }

    private func selectNavigationItem(_ item: NavigationItem) {
        let newSelection = SidebarSelection.navigation(item)
        if self.currentSidebarSelection == newSelection {
            self.onReselectNavigationItem?(item)
            HapticService.navigation()
            return
        }
        self.selection = item
        self.pinnedSelection = nil
        HapticService.navigation()
    }

    private func selectPinnedItem(_ item: SidebarPinnedItem) {
        let newSelection = SidebarSelection.pinned(item)
        if self.currentSidebarSelection == newSelection {
            self.onReselectPinnedItem?(item)
            HapticService.navigation()
            return
        }
        self.selection = nil
        self.pinnedSelection = item
        HapticService.navigation()
    }

    private var playlistsSectionHeader: some View {
        HStack {
            Text(String(localized: "Playlists"))

            Spacer()

            if self.isCreatingPlaylist {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 8)
            } else {
                Button {
                    self.presentCreatePlaylistDialog()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .opacity(self.isHoveringPlaylistsHeader ? 1 : 0)
                .padding(.trailing, 8)
                .help(String(localized: "Create Playlist"))
                .accessibilityLabel(String(localized: "Create Playlist"))
            }
        }
        .onHover { hovering in
            withAnimation(AppAnimation.quick) {
                self.isHoveringPlaylistsHeader = hovering
            }
        }
    }

    private func presentCreatePlaylistDialog() {
        guard !self.isCreatingPlaylist else { return }
        let owner = self.playerService.currentAccountMutationOwner

        SongActionsHelper.presentCreatePlaylistDialog(
            informativeText: "Create a new playlist.",
            request: SongActionsHelper.PlaylistCreationRequest(
                client: self.client,
                videoIds: [],
                whileValid: { self.playerService.acceptsAccountMutationOwner(owner) }
            ),
            onWillCreate: {
                guard !self.isCreatingPlaylist else { return false }
                self.isCreatingPlaylist = true
                return true
            },
            completion: { result in
                self.isCreatingPlaylist = false
                guard self.playerService.acceptsAccountMutationOwner(owner) else { return }

                switch result {
                case let .success(playlist):
                    let pinnedItem = SidebarPinnedItem.from(playlist)
                    self.sidebarPinnedItemsManager.add(pinnedItem)
                    self.selectPinnedItem(pinnedItem)
                case let .failure(failure):
                    SongActionsHelper.presentPlaylistCreationError(failure)
                }
            }
        )
    }

    private func sidebarPinnedRow(_ item: SidebarPinnedItem) -> some View {
        KasetSidebarRow(
            title: item.title,
            systemImage: item.systemImage,
            isSelected: self.currentSidebarSelection == .pinned(item)
        ) {
            self.selectPinnedItem(item)
        }
        .contextMenu {
            Button {
                self.sidebarPinnedItemsManager.moveUp(contentId: item.contentId)
            } label: {
                Label(String(localized: "Move Up"), systemImage: "chevron.up")
            }

            Button {
                self.sidebarPinnedItemsManager.moveDown(contentId: item.contentId)
            } label: {
                Label(String(localized: "Move Down"), systemImage: "chevron.down")
            }

            Button {
                self.sidebarPinnedItemsManager.moveToTop(contentId: item.contentId)
            } label: {
                Label(String(localized: "Move to Top"), systemImage: "arrow.up.to.line")
            }

            Button {
                self.sidebarPinnedItemsManager.moveToEnd(contentId: item.contentId)
            } label: {
                Label(String(localized: "Move to End"), systemImage: "arrow.down.to.line")
            }

            Divider()

            Button(role: .destructive) {
                if self.pinnedSelection?.contentId == item.contentId {
                    self.pinnedSelection = nil
                }
                self.sidebarPinnedItemsManager.remove(contentId: item.contentId)
            } label: {
                Label(String(localized: "Remove from Sidebar"), systemImage: "sidebar.left")
            }
        }
    }
}

#Preview {
    let authService = AuthService()
    let client = YTMusicClient(authService: authService, webKitManager: .shared)
    Sidebar(selection: .constant(.home), pinnedSelection: .constant(nil), client: client)
        .frame(width: 220)
        .environment(authService)
        .environment(PlayerService())
        .environment(SidebarPinnedItemsManager(skipLoad: true))
        .environment(PodcastsAvailabilityService())
}
