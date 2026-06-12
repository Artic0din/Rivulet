//
//  ContinueWatchingInfoViewController.swift
//  Rivulet
//
//  A custom content tab for the native AVPlayerViewController info panel showing
//  the user's Continue Watching (On Deck) items as a horizontal shelf.
//
//  Implemented as a UIKit `UICollectionView` (not a SwiftUI UIHostingController):
//  SwiftUI focus does NOT work inside AVKit's info panel — it falls back to
//  screen-based focus and asserts (`_screenBasedFocusUnsupported`), so cards can't
//  be focused. UIKit collection-view focus works natively in the panel. The card
//  visuals still reuse the SwiftUI `LandscapeContentCard` via `UIHostingConfiguration`,
//  with the cell's focus state driving the card's focus emphasis.
//
//  Selecting a card swaps the current item in place via `playItem(_:)`. Wired
//  through `AVPlayerViewController.customInfoViewControllers`.
//

import AVKit
import SwiftUI
import UIKit

@MainActor
final class ContinueWatchingInfoViewController: UIViewController {

    private let viewModel: UniversalPlayerViewModel
    private var items: [PlexMetadata] = []
    private var collectionView: UICollectionView!

    // Reference shelf size: 392×280 home card scaled to ≈228pt tall (uiScale 0.80).
    private let cardWidth: CGFloat = 314
    private let cardHeight: CGFloat = 224
    private static let cellID = "ContinueWatchingCard"

    init(viewModel: UniversalPlayerViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        // AVKit uses this as the content tab's title.
        title = "Continue Watching"
        // The system clamps all tabs to the tallest; keep this just tall enough
        // for the card + insets so the transport bar isn't pushed up.
        preferredContentSize = CGSize(width: 1920, height: cardHeight + 40)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .horizontal
        let layout = UICollectionViewCompositionalLayout(section: makeSection(), configuration: config)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsHorizontalScrollIndicator = false
        // Let the focused card's scale grow beyond the cell/row bounds (matches
        // the app's shelves) instead of being clipped.
        collectionView.clipsToBounds = false
        collectionView.register(CardCell.self, forCellWithReuseIdentifier: Self.cellID)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        Task {
            items = await viewModel.loadContinueWatchingItems()
            collectionView.reloadData()
        }
    }

    private func makeSection() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .absolute(cardWidth),
                                          heightDimension: .absolute(cardHeight))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = ScaledDimensions.rowItemSpacing
        // Leading inset aligns the first card with the tab pills / Info content.
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 18, bottom: 8, trailing: 48)
        return section
    }

    // MARK: - Card model

    fileprivate func cardModel(for item: PlexMetadata) -> ContentCardModel {
        let base = PlexContentCardMapper.model(
            from: item,
            serverURL: viewModel.serverURL,
            authToken: viewModel.authToken
        )
        return ContentCardModel(
            title: base.title,
            titleTreatment: base.titleTreatment,
            artwork: base.artwork,
            posterURL: base.posterURL,
            infoLine: infoLine(for: item),
            badges: []
        )
    }

    private func infoLine(for item: PlexMetadata) -> [String] {
        let remaining: String? = {
            guard let offset = item.viewOffset, let duration = item.duration, duration > offset else { return nil }
            return "\(Int(ceil(Double(duration - offset) / 60_000.0)))m"
        }()
        if item.type == "episode", let s = item.parentIndex, let e = item.index {
            return remaining.map { ["S\(s), E\(e)", $0] } ?? ["S\(s), E\(e)"]
        }
        if let remaining { return ["\(remaining) left"] }
        if let duration = item.duration { return ["\(Int(ceil(Double(duration) / 60_000.0)))m"] }
        return []
    }
}

// MARK: - Data source / delegate

extension ContinueWatchingInfoViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.cellID, for: indexPath) as! CardCell
        cell.model = cardModel(for: items[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = items[indexPath.item]
        Task { await viewModel.playItem(item) }
    }
}

// MARK: - Cell (UIKit focus + SwiftUI card via UIHostingConfiguration)

private final class CardCell: UICollectionViewCell {
    var model: ContentCardModel? {
        didSet { setNeedsUpdateConfiguration() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Don't clip the focus scale — let the card grow over its neighbours.
        clipsToBounds = false
        contentView.clipsToBounds = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        guard let model else {
            contentConfiguration = nil
            return
        }
        // Card draws at rest size; the focus lift is a cell transform (below) so
        // it isn't constrained by the hosting configuration's fixed bounds.
        contentConfiguration = UIHostingConfiguration {
            LandscapeContentCard(model: model, isFocused: false)
                .environment(\.uiScale, 0.80)
        }
        .margins(.all, 0)
    }

    /// Pronounced focus lift (tvOS-standard cell transform) — grows over
    /// neighbours and isn't clipped (clipsToBounds is off).
    override func didUpdateFocus(in context: UIFocusUpdateContext,
                                 with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        let focused = isFocused
        layer.zPosition = focused ? 1 : 0
        coordinator.addCoordinatedAnimations {
            self.transform = focused
                ? CGAffineTransform(scaleX: 1.12, y: 1.12)
                : .identity
        }
    }
}
