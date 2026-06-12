//
//  NextEpisodeProposalViewController.swift
//  Rivulet
//
//  Native tvOS "Up Next" card for the AVPlayer route. AVKit provides no
//  pre-built proposal UI — you subclass `AVContentProposalViewController` and
//  compose the card yourself. AVKit hands us the `contentProposal` data, the
//  `preferredPlayerViewFrame` shrink hook, and `dateOfAutomaticAcceptance`
//  (the scheduled auto-accept time we drive the countdown ring against).
//
//  Layout mirrors the Apple TV app:
//  - The currently-playing video shrinks into the TOP-RIGHT corner
//    (via `preferredPlayerViewFrame`).
//  - The next episode's still fills the background (`contentProposal.previewImage`).
//  - Show title + "S# E# · Title" + a "Next Episode" pill (with the countdown
//    ring drawn around the play glyph) sit at the BOTTOM-LEFT.
//
//  Accept/Reject are reported via `dismissContentProposal(for:…)`; the actual
//  next-episode playback is handled by `NativePlayerViewController`'s
//  `AVPlayerViewControllerDelegate.didAccept` → `viewModel.playNextEpisode()`.
//

import AVKit
import Combine
import SwiftUI
import UIKit

@MainActor
final class NextEpisodeProposalViewController: AVContentProposalViewController {

    private let model = ProposalCardModel()
    private var hosting: UIHostingController<ProposalCardView>?
    private var tickTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let card = ProposalCardView(
            model: model,
            onPlayNext: { [weak self] in
                self?.dismissContentProposal(for: .accept, animated: true, completion: nil)
            }
        )
        let host = UIHostingController(rootView: card)
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        // Fill our own view. (Do NOT constrain to `playerLayoutGuide` here — it
        // isn't attached to this hierarchy at viewDidLoad and crashes.)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        hosting = host
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let proposal = contentProposal {
            model.showTitle = proposal.title
            model.previewImage = proposal.previewImage
            model.episodeLine = proposal.metadata
                .first { $0.identifier == .commonIdentifierDescription }?
                .value as? String ?? ""
            if let logoString = proposal.metadata
                .first(where: { $0.identifier == .commonIdentifierSource })?
                .value as? String {
                model.logoURL = URL(string: logoString)
            }
        }
        startCountdown()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tickTimer?.invalidate()
        tickTimer = nil
    }

    /// Shrink the playing video into a 16:9 window in the TOP-RIGHT corner so the
    /// next-episode artwork and card fill the rest. AVKit animates the player view
    /// to this frame on presentation. The card masks a matching hole so the video
    /// (which AVKit composites *behind* the proposal view) shows through.
    override var preferredPlayerViewFrame: CGRect {
        PlayerFrameMetrics.frame(in: view.bounds.size)
    }

    // MARK: - Countdown (driven by the system's scheduled auto-accept date)

    private func startCountdown() {
        tick()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func tick() {
        guard let date = dateOfAutomaticAcceptance else {
            model.remaining = nil
            return
        }
        let remaining = max(0, date.timeIntervalSinceNow)
        if model.total == nil { model.total = max(remaining, 1) }
        model.remaining = remaining
    }
}

// MARK: - Shared player-frame geometry

/// The shrunk-video rectangle, shared by `preferredPlayerViewFrame` (where AVKit
/// places the player) and the card's mask (where it punches a hole for it).
private enum PlayerFrameMetrics {
    static let widthFraction: CGFloat = 0.25      // of screen width
    static let rightMarginFraction: CGFloat = 0.042  // of screen width
    static let topMarginFraction: CGFloat = 0.056    // of screen height
    static let aspect: CGFloat = 9.0 / 16.0
    static let cornerRadius: CGFloat = 12

    static func frame(in size: CGSize) -> CGRect {
        let width = size.width * widthFraction
        let height = width * aspect
        let x = size.width - width - size.width * rightMarginFraction
        let y = size.height * topMarginFraction
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - SwiftUI card

@MainActor
private final class ProposalCardModel: ObservableObject {
    @Published var showTitle: String = ""
    @Published var episodeLine: String = ""
    @Published var previewImage: UIImage?
    @Published var logoURL: URL?
    @Published var remaining: TimeInterval?
    @Published var total: TimeInterval?

    /// Ring fill, 1 → 0 as the countdown elapses.
    var progress: Double {
        guard let remaining, let total, total > 0 else { return 1 }
        return max(0, min(1, remaining / total))
    }
}

private struct ProposalCardView: View {
    @ObservedObject var model: ProposalCardModel
    let onPlayNext: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        GeometryReader { geo in
            let videoRect = PlayerFrameMetrics.frame(in: geo.size)
            ZStack(alignment: .bottomLeading) {
                // Next-episode still + legibility gradient, with a transparent
                // hole cut where the shrunk video sits (AVKit composites the
                // player behind us, so the hole reveals it).
                background
                    .mask(holeMask(full: geo.size, hole: videoRect))

                overlay
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .onAppear { focused = true }
    }

    @ViewBuilder private var background: some View {
        ZStack {
            if let image = model.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.black
            }
            // Soft bottom-left darkening for legibility — kept light so the
            // artwork stays bright like the Apple TV reference.
            LinearGradient(
                colors: [.black.opacity(0.75), .clear],
                startPoint: .bottomLeading,
                endPoint: UnitPoint(x: 0.55, y: 0.45)
            )
        }
    }

    /// Opaque everywhere except a rounded hole at `hole` (even-odd fill).
    private func holeMask(full: CGSize, hole: CGRect) -> some View {
        Path { p in
            p.addRect(CGRect(origin: .zero, size: full))
            p.addRoundedRect(in: hole,
                             cornerSize: CGSize(width: PlayerFrameMetrics.cornerRadius,
                                                height: PlayerFrameMetrics.cornerRadius))
        }
        .fill(style: FillStyle(eoFill: true))
    }

    private var overlay: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Show branding: clearLogo if available, else styled show title.
            if let logoURL = model.logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 380, maxHeight: 108, alignment: .leading)
                            .shadow(radius: 8)
                    default:
                        showTitleText
                    }
                }
            } else {
                showTitleText
            }

            if !model.episodeLine.isEmpty {
                Text(model.episodeLine)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .shadow(radius: 6)
            }

            NextEpisodeButton(progress: model.progress,
                              isFocused: focused,
                              action: onPlayNext)
                .focused($focused)
                .padding(.top, 4)
        }
        .padding(.leading, 80)
        .padding(.bottom, 64)
        .padding(.trailing, 40)
    }

    private var showTitleText: some View {
        Text(model.showTitle)
            .font(.system(size: 44, weight: .heavy))
            .foregroundStyle(.white)
            .lineLimit(2)
            .shadow(radius: 8)
    }
}

/// Pill button with the countdown ring drawn around the play glyph. Uses the
/// app-wide `AppStoreActionButtonStyle` (same as the hero/detail action pills) so
/// focus is handled consistently — white fill + black content on focus, glass at
/// rest, token-driven scale — instead of the tvOS default focus halo.
private struct NextEpisodeButton: View {
    let progress: Double
    let isFocused: Bool
    let action: () -> Void

    private let height: CGFloat = 72

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(foreground.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(foreground, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .bold))
                }
                .frame(width: 34, height: 34)
                .animation(.linear(duration: 0.5), value: progress)

                Text("Next Episode")
                    .font(.system(size: 26, weight: .semibold))
            }
            .padding(.horizontal, 28)
            .frame(height: height)
        }
        .buttonStyle(AppStoreActionButtonStyle(isFocused: isFocused, cornerRadius: height / 2))
    }

    /// Ring/glyph color tracks the style's fill (black on white focus fill).
    private var foreground: Color { isFocused ? .black : .white }
}
