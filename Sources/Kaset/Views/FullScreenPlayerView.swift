import SwiftUI

// MARK: - FullScreenPlayerView

/// Now-playing view that covers the main window: large artwork, track info and transport
/// controls over a blurred copy of the artwork. Closing it reveals the untouched window below.
struct FullScreenPlayerView: View {
    @Environment(PlayerService.self) private var playerService
    @Environment(AuthService.self) private var authService
    @State private var seekState = MiniPlayerSeekState()

    var body: some View {
        GeometryReader { geometry in
            let isWide = geometry.size.width > geometry.size.height * 1.25

            ZStack {
                self.backdrop

                if isWide {
                    // Artwork on the left, info and controls on the right (Apple Music style).
                    let artworkSize = max(200, min(geometry.size.height - 160, geometry.size.width * 0.45))
                    HStack(spacing: 72) {
                        self.artwork(size: artworkSize)

                        VStack(alignment: .leading, spacing: 28) {
                            self.trackInfo(alignment: .leading, titleSize: 38, artistSize: 22)

                            MiniPlayerSeekSection(state: self.seekState)

                            self.transportControls
                        }
                        .frame(maxWidth: 480, alignment: .leading)
                    }
                    .padding(64)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Leave room below the artwork for title, seek bar and controls.
                    let artworkSize = max(160, min(geometry.size.height - 340, geometry.size.width - 96, 560))
                    VStack(spacing: 24) {
                        Spacer(minLength: 0)

                        self.artwork(size: artworkSize)

                        self.trackInfo(alignment: .center, titleSize: 26, artistSize: 17)

                        MiniPlayerSeekSection(state: self.seekState)
                            .frame(width: max(artworkSize, 360))

                        self.transportControls

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 32)
                }
            }
            .overlay(alignment: .topLeading) {
                self.closeButton
            }
        }
    }

    // MARK: - Views

    private var backdrop: some View {
        ZStack {
            Color.black

            if let track = self.playerService.currentTrack {
                SongThumbnailView(song: track, size: 320, cornerRadius: 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(1.6)
                    .blur(radius: 80)
                    .opacity(0.7)
                    .clipped()
            }

            Color.black.opacity(0.35)
        }
        .ignoresSafeArea()
        .overlay { WindowDragHandle() }
    }

    private func artwork(size: CGFloat) -> some View {
        Group {
            if let track = self.playerService.currentTrack {
                SongThumbnailView(song: track, size: size, cornerRadius: 16)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white.opacity(0.12))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.32, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(width: size, height: size)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 30, y: 12)
    }

    private func trackInfo(alignment: HorizontalAlignment, titleSize: CGFloat, artistSize: CGFloat) -> some View {
        VStack(alignment: alignment, spacing: 8) {
            Text(self.playerService.currentTrack?.title ?? String(localized: "Not Playing"))
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            // Closes the full screen view and lets the visible player bar open the artist page.
            Button {
                withAnimation(AppAnimation.standard) {
                    self.playerService.showFullScreenPlayer = false
                }
                self.playerService.requestArtistNavigation()
            } label: {
                Text(self.artistName)
                    .font(.system(size: artistSize))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .disabled(self.playerService.currentTrack == nil)
            .pointerStyle(.link)
        }
        .multilineTextAlignment(alignment == .leading ? .leading : .center)
    }

    private var transportControls: some View {
        HStack(spacing: 28) {
            self.controlButton(
                systemName: "shuffle",
                size: 18,
                isActive: self.playerService.shuffleEnabled,
                label: String(localized: "Shuffle")
            ) {
                self.playerService.toggleShuffle()
            }

            self.controlButton(systemName: "backward.fill", size: 26, label: String(localized: "Previous track")) {
                Task { await self.playerService.previous() }
            }
            .disabled(self.playerService.currentEpisode != nil)

            self.controlButton(
                systemName: self.playerService.displaysAsPlaying ? "pause.circle.fill" : "play.circle.fill",
                size: 64,
                label: self.playerService.displaysAsPlaying ? String(localized: "Pause") : String(localized: "Play")
            ) {
                Task { await self.playerService.playPause() }
            }

            self.controlButton(systemName: "forward.fill", size: 26, label: String(localized: "Next track")) {
                Task { await self.playerService.next() }
            }
            .disabled(self.playerService.currentEpisode != nil)

            self.controlButton(
                systemName: self.playerService.repeatMode == .one ? "repeat.1" : "repeat",
                size: 18,
                isActive: self.playerService.repeatMode != .off,
                label: String(localized: "Repeat")
            ) {
                self.playerService.cycleRepeatMode()
            }

            if self.authService.hasPersonalAccount {
                self.controlButton(
                    systemName: self.playerService.currentTrackLikeStatus == .like ? "hand.thumbsup.fill" : "hand.thumbsup",
                    size: 18,
                    isActive: self.playerService.currentTrackLikeStatus == .like,
                    label: String(localized: "Like")
                ) {
                    HapticService.toggle()
                    self.playerService.likeCurrentTrack()
                }
                .disabled(self.playerService.currentTrack == nil)
            }
        }
    }

    private var closeButton: some View {
        Button {
            self.close()
        } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 36, height: 36)
                .compatGlass(interactive: true, in: .circle)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .help(String(localized: "Close"))
        .accessibilityLabel(String(localized: "Close"))
        .padding(.leading, 20)
        // Clear the window's traffic lights, which float over the hidden title bar.
        .padding(.top, 48)
    }

    private func controlButton(
        systemName: String,
        size: CGFloat,
        isActive: Bool = false,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(isActive ? PackageResourceLookup.brandAccent : .white.opacity(0.92))
                .frame(minWidth: 36, minHeight: 36)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    // MARK: - Helpers

    private var artistName: String {
        guard let track = self.playerService.currentTrack else { return "" }
        return track.artistsDisplay.isEmpty ? String(localized: "Unknown Artist") : track.artistsDisplay
    }

    private func close() {
        withAnimation(AppAnimation.standard) {
            self.playerService.showFullScreenPlayer = false
        }
    }
}
