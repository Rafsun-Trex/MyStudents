import CoreData
import UIKit

/// Top-level dashboard. A compositional-layout collection view lays out a
/// welcome header, a 2-column grid of stat cards, and one full-width
/// "feature" card for monthly revenue.
final class DashboardViewController: UIViewController {
    private let viewModel: DashboardViewModel

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<Int, String>!

    /// Card lookup keyed by the diffable identifier we put in the snapshot.
    /// The identifier is the card's `Kind` raw value, or `"header"` for the
    /// welcome row.
    private var cardsByID: [String: DashboardCardItem] = [:]

    private var reloadIsPending = false

    private static let headerID = "header"
    private static let headerSection = 0
    private static let statsSection = 1
    private static let featureSection = 2

    init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(viewModel:) to create DashboardViewController.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .systemGroupedBackground
        configureCollectionView()
        configureDataSource()
        observeContextChanges()
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    // MARK: - Layout

    private func configureCollectionView() {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            self?.makeLayoutSection(for: sectionIndex)
        }
        layout.configuration.interSectionSpacing = 16

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func makeLayoutSection(for sectionIndex: Int) -> NSCollectionLayoutSection? {
        switch sectionIndex {
        case Self.headerSection:
            let item = NSCollectionLayoutItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(80)
                )
            )
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .estimated(80)
                ),
                subitems: [item]
            )
            let layoutSection = NSCollectionLayoutSection(group: group)
            layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 0, trailing: 20)
            return layoutSection

        case Self.statsSection:
            let item = NSCollectionLayoutItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.5),
                    heightDimension: .fractionalHeight(1)
                )
            )
            item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .absolute(140)
                ),
                subitems: [item]
            )

            let layoutSection = NSCollectionLayoutSection(group: group)
            layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 14, bottom: 0, trailing: 14)
            return layoutSection

        case Self.featureSection:
            let item = NSCollectionLayoutItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .fractionalHeight(1)
                )
            )
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1),
                    heightDimension: .absolute(150)
                ),
                subitems: [item]
            )
            let layoutSection = NSCollectionLayoutSection(group: group)
            layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 20, bottom: 24, trailing: 20)
            return layoutSection

        default:
            return nil
        }
    }

    // MARK: - Data source

    private func configureDataSource() {
        let headerRegistration = UICollectionView.CellRegistration<DashboardHeaderCell, String> { [weak self] cell, _, _ in
            guard let self else { return }
            cell.configure(greeting: self.viewModel.greeting, dateText: self.viewModel.todayLabel)
        }

        let statRegistration = UICollectionView.CellRegistration<DashboardStatCell, String> { [weak self] cell, _, identifier in
            guard let card = self?.cardsByID[identifier] else { return }
            cell.configure(with: card)
        }

        let featureRegistration = UICollectionView.CellRegistration<DashboardFeatureCell, String> { [weak self] cell, _, identifier in
            guard let card = self?.cardsByID[identifier] else { return }
            cell.configure(with: card)
        }

        dataSource = UICollectionViewDiffableDataSource<Int, String>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, identifier in
            if identifier == Self.headerID {
                return collectionView.dequeueConfiguredReusableCell(
                    using: headerRegistration, for: indexPath, item: identifier
                )
            }
            let style = self?.cardsByID[identifier]?.style ?? .compact
            switch style {
            case .compact:
                return collectionView.dequeueConfiguredReusableCell(
                    using: statRegistration, for: indexPath, item: identifier
                )
            case .feature:
                return collectionView.dequeueConfiguredReusableCell(
                    using: featureRegistration, for: indexPath, item: identifier
                )
            }
        }
    }

    // MARK: - Reload

    private func reload() {
        do {
            try viewModel.reload()
            applySnapshot()
        } catch {
            showError(error)
        }
    }

    private func applySnapshot() {
        let cards = viewModel.cards()
        cardsByID = Dictionary(uniqueKeysWithValues: cards.map { ($0.kind.rawValue, $0) })

        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([Self.headerSection, Self.statsSection, Self.featureSection])
        snapshot.appendItems([Self.headerID], toSection: Self.headerSection)

        let compactIDs = cards.filter { $0.style == .compact }.map(\.kind.rawValue)
        let featureIDs = cards.filter { $0.style == .feature }.map(\.kind.rawValue)
        snapshot.appendItems(compactIDs, toSection: Self.statsSection)
        snapshot.appendItems(featureIDs, toSection: Self.featureSection)
        snapshot.reconfigureItems([Self.headerID] + compactIDs + featureIDs)

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func observeContextChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleContextDidSave(_:)),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }

    @objc private func handleContextDidSave(_ notification: Notification) {
        guard !reloadIsPending else { return }
        reloadIsPending = true
        RunLoop.main.perform { [weak self] in
            self?.reloadIsPending = false
            guard self?.view.window != nil else { return }
            self?.reload()
        }
    }
}

// MARK: - UICollectionViewDelegate

extension DashboardViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard let identifier = dataSource.itemIdentifier(for: indexPath) else { return false }
        return cardsByID[identifier] != nil
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard
            let identifier = dataSource.itemIdentifier(for: indexPath),
            let card = cardsByID[identifier]
        else { return }

        let destination = viewModel.destinationTab(for: card.kind)
        guard let tabBarController = tabBarController,
              let viewControllers = tabBarController.viewControllers else { return }
        let index = AppTab.allCases.firstIndex(of: destination) ?? 0
        guard index < viewControllers.count else { return }
        tabBarController.selectedIndex = index
    }
}

// MARK: - Header Cell

private final class DashboardHeaderCell: UICollectionViewCell {
    private let greetingLabel = UILabel()
    private let dateLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(greeting: String, dateText: String) {
        greetingLabel.text = greeting
        dateLabel.text = dateText
    }

    private func setup() {
        greetingLabel.translatesAutoresizingMaskIntoConstraints = false
        greetingLabel.font = .systemFont(ofSize: 28, weight: .bold)
        greetingLabel.adjustsFontForContentSizeCategory = true
        greetingLabel.numberOfLines = 1
        greetingLabel.textColor = .label

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .preferredFont(forTextStyle: .subheadline)
        dateLabel.adjustsFontForContentSizeCategory = true
        dateLabel.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [greetingLabel, dateLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
}

// MARK: - Stat Cell

private final class DashboardStatCell: UICollectionViewCell {
    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.contentView.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                    : .identity
            }
        }
    }

    func configure(with item: DashboardCardItem) {
        iconView.image = UIImage(systemName: item.systemImageName)
        iconView.tintColor = item.tintColor
        iconBackground.backgroundColor = item.tintColor.withAlphaComponent(0.15)
        titleLabel.text = item.title
        valueLabel.text = item.value
        subtitleLabel.text = item.subtitle
    }

    private func setup() {
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 18
        contentView.layer.cornerCurve = .continuous

        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.05
        contentView.layer.shadowRadius = 8
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)

        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.layer.cornerRadius = 18
        iconBackground.layer.cornerCurve = .continuous

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        iconBackground.addSubview(iconView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .preferredFont(forTextStyle: .footnote)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .secondaryLabel
        titleLabel.numberOfLines = 1

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 30, weight: .bold)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6
        valueLabel.numberOfLines = 1
        valueLabel.textColor = .label

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2

        contentView.addSubview(iconBackground)
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            iconBackground.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            iconBackground.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            iconBackground.widthAnchor.constraint(equalToConstant: 36),
            iconBackground.heightAnchor.constraint(equalToConstant: 36),

            iconView.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleLabel.topAnchor.constraint(equalTo: iconBackground.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            valueLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),

            subtitleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -14)
        ])
    }
}

// MARK: - Feature Cell

private final class DashboardFeatureCell: UICollectionViewCell {
    private let gradientLayer = CAGradientLayer()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = contentView.bounds
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.contentView.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.98, y: 0.98)
                    : .identity
            }
        }
    }

    func configure(with item: DashboardCardItem) {
        iconView.image = UIImage(systemName: item.systemImageName)
        titleLabel.text = item.title.uppercased()
        valueLabel.text = item.value
        subtitleLabel.text = item.subtitle

        let base = item.tintColor
        gradientLayer.colors = [
            base.cgColor,
            base.withAlphaComponent(0.78).cgColor
        ]
    }

    private func setup() {
        contentView.backgroundColor = .clear
        contentView.layer.cornerRadius = 20
        contentView.layer.cornerCurve = .continuous
        contentView.layer.masksToBounds = false

        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.12
        contentView.layer.shadowRadius = 14
        contentView.layer.shadowOffset = CGSize(width: 0, height: 6)

        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 20
        gradientLayer.cornerCurve = .continuous
        gradientLayer.masksToBounds = true
        contentView.layer.insertSublayer(gradientLayer, at: 0)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        titleLabel.adjustsFontForContentSizeCategory = true

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 32, weight: .bold)
        valueLabel.textColor = .white
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.5
        valueLabel.numberOfLines = 1

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.numberOfLines = 2

        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = UIColor.white.withAlphaComponent(0.9)
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)

        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(chevron)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevron.leadingAnchor, constant: -8),

            chevron.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            chevron.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            valueLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            valueLabel.bottomAnchor.constraint(equalTo: subtitleLabel.topAnchor, constant: -4),

            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])
    }
}
