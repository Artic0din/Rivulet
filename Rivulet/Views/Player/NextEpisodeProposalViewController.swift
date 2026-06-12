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
    static let widthFraction: CGFloat = 0.34
    static let marginFraction: CGFloat = 0.06
    static let aspect: CGFloat = 9.0 / 16.0
    static let cornerRadius: CGFloat = 14

    static func frame(in size: CGSize) -> CGRect {
        let width = size.width * widthFraction
        let height = width * aspect
        let margin = size.width * marginFraction
        return CGRect(x: size.width - width - margin,
                      y: margin,
                      width: width,
                      height: height)
    }
}

// MARK: - SwiftUI card

@MainActor
private final class ProposalCardModel: ObservableObject {
    @Published var showTitle: String = ""
    @Published var episodeLine: String = ""
    @Published var previewImage: UIImage?
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
            // Darken bottom-left for text legibility.
            LinearGradient(
                colors: [.black.opacity(0.85), .black.opacity(0.35), .clear],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
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
        VStack(alignment: .leading, spacing: 14) {
                Text(model.showTitle)
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(radius: 8)

                if !model.episodeLine.isEmpty {
                    Text(model.episodeLine)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .shadow(radius: 6)
                }

                NextEpisodeButton(progress: model.progress,
                                  isFocused: focused,
                                  action: onPlayNext)
                    .focused($focused)
                    .padding(.top, 16)
        }
        .padding(.leading, 90)
        .padding(.bottom, 90)
        .padding(.trailing, 40)
    }
}

/// Pill button with the countdown ring drawn around the play glyph.
private struct NextEpisodeButton: View {
    let progress: Double
    let isFocused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(foreground.opacity(0.3), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(foreground, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(foreground)
                }
                .frame(width: 38, height: 38)
                .animation(.linear(duration: 0.5), value: progress)

                Text("Next Episode")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(foreground)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 18)
            .background {
                Capsule().fill(isFocused ? Color.white : Color.white.opacity(0.18))
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isFocused ? 1.06 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }

    private var foreground: Color { isFocused ? .black : .white }
}
