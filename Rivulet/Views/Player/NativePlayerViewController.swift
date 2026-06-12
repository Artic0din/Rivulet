//
//  NativePlayerViewController.swift
//  Rivulet
//
//  Native Apple-TV playback container. Hosts a child `AVPlayerViewController`
//  via composition — Apple documents subclassing AVPlayerViewController as
//  unsupported, so this is a plain UIViewController that owns and embeds one.
//  Uses UniversalPlayerViewModel only for route/URL selection, then hands the
//  AVPlayer to the system player UI.
//
//  AVPlayerViewController handles everything natively:
//  - Transport controls (scrub bar, play/pause, skip)
//  - Now Playing / MPRemoteCommandCenter
//  - AirPlay A/V sync
//  - Audio session management
//
//  It also drives native "Up Next": the VM publishes an `AVContentProposal`,
//  which we attach to the current item. When playback reaches the proposal's
//  transition time, AVKit asks us (the delegate) to present it — we supply a
//  `NextEpisodeProposalViewController` for the Apple-TV-style card. Accept (manual
//  or auto) routes back through the VM so Plex headers/markers/progress survive.
//

import AVKit
import Combine
import UIKit

@MainActor
final class NativePlayerViewController: UIViewController, AVPlayerViewControllerDelegate {

    private let viewModel: UniversalPlayerViewModel
    private let avPlayerVC = AVPlayerViewController()
    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?
    private var lastReportedTime: TimeInterval = -1
    var onDismiss: (() -> Void)?

    init(viewModel: UniversalPlayerViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        // Plain container needs an explicit full-screen style (the
        // AVPlayerViewController subclass previously inherited this default).
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Embed the native player as a child (composition, not subclassing).
        addChild(avPlayerVC)
        avPlayerVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(avPlayerVC.view)
        NSLayoutConstraint.activate([
            avPlayerVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            avPlayerVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            avPlayerVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            avPlayerVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        avPlayerVC.didMove(toParent: self)
        avPlayerVC.delegate = self

        // Observe when the VM creates its AVPlayer and hand it to the native UI.
        viewModel.$player
            .compactMap { $0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] avPlayer in
                self?.avPlayerVC.player = avPlayer
            }
            .store(in: &cancellables)

        // Show/hide skip button via contextualActions (native AVPlayerViewController pattern)
        viewModel.$activeMarker
            .receive(on: DispatchQueue.main)
            .sink { [weak self] marker in
                guard let self else { return }
                if marker != nil {
                    let label = self.viewModel.skipButtonLabel
                    self.avPlayerVC.contextualActions = [
                        UIAction(title: label, image: UIImage(systemName: "forward.fill")) { [weak self] _ in
                            guard let self else { return }
                            Task { await self.viewModel.skipActiveMarker() }
                        }
                    ]
                } else {
                    self.avPlayerVC.contextualActions = []
                }
            }
            .store(in: &cancellables)

        // Native "Up Next" — attach the VM's published proposal to the current item.
        viewModel.$avContentProposal
            .receive(on: DispatchQueue.main)
            .sink { [weak self] proposal in
                self?.avPlayerVC.player?.currentItem?.nextContentProposal = proposal
            }
            .store(in: &cancellables)
    }

    // MARK: - AVPlayerViewControllerDelegate (Up Next content proposals)

    func playerViewController(_ playerViewController: AVPlayerViewController,
                              shouldPresent proposal: AVContentProposal) -> Bool {
        print("[UpNext] shouldPresent — presenting native card")
        // AVKit has no built-in proposal UI; supply our Apple-TV-style card.
        playerViewController.contentProposalViewController = NextEpisodeProposalViewController()
        return true
    }

    func playerViewController(_ playerViewController: AVPlayerViewController,
                              didAccept proposal: AVContentProposal) {
        print("[UpNext] didAccept — advancing to next episode")
        // Manual select AND auto-advance (automaticAcceptanceInterval) both land
        // here, so this is the single advance path. Route through the VM so Plex
        // headers/metadata/markers/progress are preserved.
        Task { @MainActor in
            await viewModel.playNextEpisode()
        }
    }

    func playerViewController(_ playerViewController: AVPlayerViewController,
                              didReject proposal: AVContentProposal) {
        print("[UpNext] didReject")
        viewModel.cancelAutoAdvanceProposal()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Pause hub polling while playing
        NotificationCenter.default.post(name: .plexPlaybackStarted, object: nil)

        // Do NOT attach NowPlayingService — AVPlayerViewController handles
        // Now Playing, remote commands, and audio session natively.

        Task { @MainActor in
            await viewModel.startPlayback()
        }

        // Report progress to Plex every 10 seconds
        startProgressReporting()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isBeingDismissed || isMovingFromParent {
            stopProgressReporting()
            reportFinalProgress()
            NotificationCenter.default.post(name: .plexPlaybackStopped, object: nil)
            viewModel.stopPlayback()
            onDismiss?()
        }
    }

    // MARK: - Plex Progress Reporting

    private func startProgressReporting() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reportCurrentProgress()
            }
        }
    }

    private func stopProgressReporting() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func reportCurrentProgress() {
        let time = viewModel.currentTime
        guard abs(time - lastReportedTime) >= 5 else { return }
        lastReportedTime = time

        let ratingKey = viewModel.metadata.ratingKey ?? ""
        let duration = viewModel.duration
        let state = viewModel.isPlaying ? "playing" : "paused"

        Task {
            await PlexProgressReporter.shared.reportProgress(
                ratingKey: ratingKey,
                time: time,
                duration: duration,
                state: state
            )
        }
    }

    private func reportFinalProgress() {
        let ratingKey = viewModel.metadata.ratingKey ?? ""
        let time = viewModel.currentTime
        let duration = viewModel.duration

        Task {
            await PlexProgressReporter.shared.reportProgress(
                ratingKey: ratingKey,
                time: time,
                duration: duration,
                state: "stopped",
                forceReport: true
            )

            if duration > 0 && time / duration > 0.9 {
                await PlexProgressReporter.shared.markAsWatched(ratingKey: ratingKey)
            }

            try? await Task.sleep(nanoseconds: 2_000_000_000)

            await MainActor.run {
                NotificationCenter.default.post(name: .plexDataNeedsRefresh, object: nil)
            }
        }
    }
}
