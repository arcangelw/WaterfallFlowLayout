//
//  ViewController.swift
//  Example
//
//  Created by 吴哲 on 2023/8/2.
//

import UIKit
import WaterfallFlowLayout

extension UIColor {
    /// 随机色
    static var randomColor: UIColor {
        UIColor(
            red: CGFloat.random(in: 0.0 ... 255.0) / 255.0,
            green: CGFloat.random(in: 0.0 ... 255.0) / 255.0,
            blue: CGFloat.random(in: 0.0 ... 255.0) / 255.0,
            alpha: 1.0
        )
    }
}

final class SupplementaryView: UICollectionReusableView {
    var text: String? {
        didSet {
            label.text = text
            layoutIfNeeded()
        }
    }

    let label: UILabel = .init()
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        label.textColor = .randomColor
        label.font = .systemFont(ofSize: 30)
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        layer.cornerRadius = 10
        layer.borderWidth = 5
        layer.borderColor = UIColor.randomColor.cgColor
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class Cell: UICollectionViewCell {
    var text: String? {
        didSet {
            label.text = text
            contentView.layoutIfNeeded()
        }
    }

    let label: UILabel = .init()
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .white
        label.textColor = .randomColor
        label.font = .systemFont(ofSize: 30)
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        contentView.layer.cornerRadius = 10
        contentView.layer.borderWidth = 5
        contentView.layer.borderColor = UIColor.randomColor.cgColor
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ViewController: UIViewController, UICollectionViewDataSource, WaterfallDelegateFlowLayout {
    private lazy var layout: WaterfallFlowLayout = {
        let layout = WaterfallFlowLayout()
        layout.sectionHeadersPinToVisibleBounds = true
        layout.sectionFootersPinToVisibleBounds = true
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.columnCount = 3
        layout.headerOffset = 100
        layout.footerOffset = 100
        layout.sectionInset = .init(top: 10, left: 10, bottom: 10, right: 10)
        layout.headerReferenceSize = .init(width: 200, height: 60)
        layout.footerReferenceSize = .init(width: 200, height: 60)
        return layout
    }()

    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

    private lazy var headerView: UILabel = {
        let label = UILabel()
        label.text = "collectionHeaderView"
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 30)
        label.backgroundColor = .randomColor
        return label
    }()

    private lazy var footerView: UILabel = {
        let label = UILabel()
        label.text = "collectionFooterView"
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 30)
        label.backgroundColor = .randomColor
        return label
    }()

    private var observation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.frame = view.bounds
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(Cell.self, forCellWithReuseIdentifier: "cell")
        collectionView.register(SupplementaryView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "header")
        collectionView.register(SupplementaryView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "footer")
        headerView.frame = .init(origin: .zero, size: .init(width: view.bounds.width, height: 100))
        collectionView.addSubview(headerView)
        footerView.frame = .init(origin: .zero, size: .init(width: view.bounds.width, height: 100))
        collectionView.addSubview(footerView)
        observation = collectionView.observe(\.contentSize, options: [.initial, .new, .old]) { [weak self] _, change in
            guard let self = self, let newSize = change.newValue else { return }
            self.collectionViewContentSizeChange(newSize)
        }
    }

    private func collectionViewContentSizeChange(_ contentSize: CGSize) {
        headerView.frame.origin.y = 0
        footerView.frame.origin.y = contentSize.height - footerView.frame.height
    }

    func numberOfSections(in _: UICollectionView) -> Int {
        return 20
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        return 10
    }

    func collectionView(_: UICollectionView, numberOfColumnInSection section: Int) -> Int {
        switch section % 3 {
        case 0: return 3
        case 1: return 4
        case 2: return 5
        default: return 3
        }
    }

    func collectionView(_: UICollectionView, itemRenderDirectionInSection section: Int) -> WaterfallFlowLayout.ItemRenderDirection {
        switch section % 3 {
        case 0: return .shortestFirst
        case 1: return .leftToRight
        case 2: return .rightToLeft
        default: return .shortestFirst
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! Cell
        cell.text = "\(indexPath.section)-\(indexPath.item)"
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! SupplementaryView
            header.text = "\(indexPath.section)"
            return header
        case UICollectionView.elementKindSectionFooter:
            let footer = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "footer", for: indexPath) as! SupplementaryView
            footer.text = "\(indexPath.section)"
            return footer
        default:
            fatalError()
        }
    }

    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let itemWidth = layout.itemWidth(inSection: indexPath.section, interitemSpacing: layout.minimumInteritemSpacing)
        let ratios: Set<CGFloat> = [1.2, 1.5, 1.7]
        return .init(width: itemWidth, height: ratios.randomElement()! * itemWidth)
    }
}
