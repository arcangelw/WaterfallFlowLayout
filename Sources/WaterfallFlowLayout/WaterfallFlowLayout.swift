import UIKit

public extension WaterfallFlowLayout {
    /// 单元填充方式
    @objc(WaterfallItemRenderDirection)
    enum ItemRenderDirection: Int {
        /// 填充最短 优先填充最短列
        case shortestFirst
        /// 从左到右
        case leftToRight
        /// 从右到左
        case rightToLeft
    }
}

@objc
public protocol WaterfallDelegateFlowLayout: UICollectionViewDelegateFlowLayout {
    /// 列数
    /// - Parameters:
    ///   - collectionView: collectionView
    ///   - section: section
    /// - Returns: 当前section 列数
    @objc
    optional func collectionView(_ collectionView: UICollectionView, numberOfColumnInSection section: Int) -> Int

    /// 填充方式
    /// - Parameters:
    ///   - collectionView: collectionView
    ///   - section: section
    /// - Returns: 当前section填充方式
    @objc
    optional func collectionView(_ collectionView: UICollectionView, itemRenderDirectionInSection section: Int) -> WaterfallFlowLayout.ItemRenderDirection
}

/// 流水布局
public final class WaterfallFlowLayout: UICollectionViewFlowLayout {
    // MARK: Publics

    /// 辅助让`UICollectionView`实现 `UITableView.tableHeaderView`功能
    public var headerOffset: CGFloat = 0 {
        didSet {
            invalidateLayout()
        }
    }

    /// 辅助让`UICollectionView`实现 `UITableView.tableFooterView`功能
    public var footerOffset: CGFloat = 0 {
        didSet {
            invalidateLayout()
        }
    }

    /// 列数
    public var columnCount: Int = 2

    /// item 填充方式
    public var itemRenderDirection: ItemRenderDirection = .shortestFirst {
        didSet {
            invalidateLayout()
        }
    }

    override public var scrollDirection: UICollectionView.ScrollDirection {
        didSet {
            assert(scrollDirection == .vertical, "暂不支持横向布局")
        }
    }

    override public init() {
        super.init()
        scrollDirection = .vertical
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        scrollDirection = .vertical
    }

    override public func prepare() {
        super.prepare()

        headersAttributes = [:]
        footersAttributes = [:]
        unionRects = []
        sectionRects = []
        allItemAttributes = []
        sectionItemAttributes = []
        columnHeights = []
        let collectionView = currentCollectionView

        let numberOfSections = collectionView.numberOfSections
        guard numberOfSections > 0 else { return }

        columnHeights = (0 ..< numberOfSections).map { section in
            let columnCount = self.columnCount(forSection: section)
            let sectionColumnHeights = (0 ..< columnCount).map { CGFloat($0) }
            return sectionColumnHeights
        }

        /// 顶部偏移量
        var top: CGFloat = headerOffset
        var attributes = UICollectionViewLayoutAttributes()

        for section in 0 ..< numberOfSections {
            // MARK: section top

            let itemCount = collectionView.numberOfItems(inSection: section)
            let sectionTop = top

            // MARK: 1. Get (minimumLineSpacing, minimumInteritemSpacing, sectionInset)

            let lineSpacing = delegate?.collectionView?(
                collectionView, layout: self, minimumLineSpacingForSectionAt: section
            ) ?? minimumLineSpacing
            let interitemSpacing = delegate?.collectionView?(
                collectionView, layout: self, minimumInteritemSpacingForSectionAt: section
            ) ?? minimumInteritemSpacing
            let sectionInsets = delegate?.collectionView?(
                collectionView, layout: self, insetForSectionAt: section
            ) ?? sectionInset

            let columnCount = columnHeights[section].count
            let itemWidth = self.itemWidth(inSection: section, interitemSpacing: interitemSpacing)

            // MARK: 2. Section header

            let heightHeader = delegate?.collectionView?(
                collectionView, layout: self, referenceSizeForHeaderInSection: section
            ).height ?? headerReferenceSize.height

            if heightHeader > 0 {
                attributes = UICollectionViewLayoutAttributes(
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    with: .init(item: 0, section: section)
                )
                attributes.zIndex = itemCount + 1
                attributes.frame = CGRect(x: 0, y: top, width: collectionView.bounds.width, height: heightHeader)
                headersAttributes[section] = attributes
                allItemAttributes.append(attributes)
                top = attributes.frame.maxY
            }
            top += sectionInsets.top
            columnHeights[section] = [CGFloat](repeating: top, count: columnCount)

            // MARK: 3. Section items

            var itemAttributes: [UICollectionViewLayoutAttributes] = []

            // 查找插入位置
            for idx in 0 ..< itemCount {
                let indexPath = IndexPath(item: idx, section: section)
                let columnIndex = nextColumnIndexForItem(idx, inSection: section)
                let xOffset = sectionInsets.left + (itemWidth + interitemSpacing) * CGFloat(columnIndex)

                let yOffset = columnHeights[section][columnIndex]
                var itemHeight: CGFloat = 0.0

                if
                    let itemSize = delegate?.collectionView?(collectionView, layout: self, sizeForItemAt: indexPath),
                    itemSize.height > 0
                {
                    itemHeight = itemSize.height
                    if itemSize.width > 0 {
                        /// 针对原始宽高 宽高比缩放处理
                        itemHeight = floor(itemHeight * itemWidth / itemSize.width)
                    }
                }

                attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                attributes.zIndex = itemCount - idx
                attributes.frame = CGRect(x: xOffset, y: yOffset, width: itemWidth, height: itemHeight)
                itemAttributes.append(attributes)
                allItemAttributes.append(attributes)
                columnHeights[section][columnIndex] = attributes.frame.maxY + lineSpacing
            }
            sectionItemAttributes.append(itemAttributes)

            // MARK: 4. Section footer

            let columnIndex = longestColumnIndex(inSection: section)
            top = columnHeights[section][columnIndex] - lineSpacing + sectionInsets.bottom
            let footerHeight = delegate?.collectionView?(
                collectionView, layout: self, referenceSizeForFooterInSection: section
            ).height ?? footerReferenceSize.height

            if footerHeight > 0 {
                attributes = UICollectionViewLayoutAttributes(
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                    with: .init(item: 0, section: section)
                )
                attributes.zIndex = itemCount + 1
                attributes.frame = CGRect(x: 0, y: top, width: collectionView.bounds.width, height: footerHeight)
                footersAttributes[section] = attributes
                allItemAttributes.append(attributes)
                top = attributes.frame.maxY
            }
            columnHeights[section] = [CGFloat](repeating: top, count: columnCount)

            // MARK: section bottom

            let sectionBottom = top
            if sectionBottom != sectionTop {
                let sectionRect = CGRect(
                    x: 0, y: sectionTop,
                    width: collectionView.bounds.width, height: sectionBottom - sectionTop
                )
                sectionRects.append(.init(section: section, rect: sectionRect))
            }
        }

        var idx = 0
        let itemCounts = allItemAttributes.count
        while idx < itemCounts {
            let rect1 = allItemAttributes[idx].frame
            idx = min(idx + unionSize, itemCounts) - 1
            let rect2 = allItemAttributes[idx].frame
            unionRects.append(rect1.union(rect2))
            idx += 1
        }
    }

    override public var collectionViewContentSize: CGSize {
        let collectionView = currentCollectionView
        var contentSize = collectionView.bounds.size
        contentSize.width = collectionViewContentWidth
        guard collectionView.numberOfSections > 0, let columnHeight = columnHeights.last?.first else {
            contentSize.height = min(headerOffset + footerOffset, contentSize.height)
            return contentSize
        }
        contentSize.height = columnHeight + footerOffset
        return contentSize
    }

    override public func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard 0 ..< sectionItemAttributes.endIndex ~= indexPath.section else { return nil }
        let list = sectionItemAttributes[indexPath.section]
        guard 0 ..< list.endIndex ~= indexPath.item else { return nil }
        return list[indexPath.item]
    }

    override public func layoutAttributesForSupplementaryView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        switch elementKind {
        case UICollectionView.elementKindSectionHeader:
            if sectionHeadersPinToVisibleBounds {
                findCalculationPinnedHeaderAttributes(in: currentVisibleBounds)
            }
            return headersAttributes[indexPath.section]
        case UICollectionView.elementKindSectionFooter:
            if sectionFootersPinToVisibleBounds {
                findCalculationPinnedFooterAttributes(in: currentVisibleBounds)
            }
            return footersAttributes[indexPath.section]
        default: return nil
        }
    }

    override public func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var begin = 0, end = unionRects.count
        if let index = unionRects.firstIndex(where: { rect.intersects($0) }) {
            begin = index * unionSize
        }
        if let index = unionRects.lastIndex(where: { rect.intersects($0) }) {
            end = min((index + 1) * unionSize, allItemAttributes.count)
        }
        let allAttributes = allItemAttributes[begin ..< end]
            .filter { rect.intersects($0.frame) }
        let hasPinned = sectionHeadersPinToVisibleBounds || sectionFootersPinToVisibleBounds
        if hasPinned {
            let visibleBounds = currentVisibleBounds
            if sectionHeadersPinToVisibleBounds {
                findCalculationPinnedHeaderAttributes(in: visibleBounds)
            }
            if sectionFootersPinToVisibleBounds {
                findCalculationPinnedFooterAttributes(in: visibleBounds)
            }
        }
        return allAttributes
    }

    override public func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        let hasPinned = sectionHeadersPinToVisibleBounds || sectionFootersPinToVisibleBounds
        return hasPinned || newBounds.width != collectionView?.bounds.width
    }

    /// 获取item宽度
    /// - Parameters:
    ///   - section: section
    ///   - interitemSpacing: 间距
    /// - Returns: 宽
    public func itemWidth(inSection section: Int, interitemSpacing: CGFloat) -> CGFloat {
        let columnCount = self.columnCount(forSection: section)
        let spaceColumCount = CGFloat(columnCount - 1)
        let width = collectionViewContentWidth(ofSection: section)
        return floor((width - (spaceColumCount * interitemSpacing)) / CGFloat(columnCount))
    }

    // MARK: - Privates

    private var waterfallDelegate: WaterfallDelegateFlowLayout? {
        return collectionView?.delegate as? WaterfallDelegateFlowLayout
    }

    private var delegate: UICollectionViewDelegateFlowLayout? {
        return collectionView?.delegate as? UICollectionViewDelegateFlowLayout
    }

    /// 列高度缓存
    /// `[setcion:[columnCount:maxHeight]]`
    private var columnHeights: [[CGFloat]] = []
    /// 单元属性缓存
    /// `[section:[item:layoutAttributes]]`
    private var sectionItemAttributes: [[UICollectionViewLayoutAttributes]] = []
    /// 存储所有的单元属性
    private var allItemAttributes: [UICollectionViewLayoutAttributes] = []
    /// header属性缓存
    /// [sectionIndex: UICollectionViewLayoutAttributes]
    private var headersAttributes: [Int: UICollectionViewLayoutAttributes] = [:]
    /// footer属性缓存
    /// [sectionIndex: UICollectionViewLayoutAttributes]
    private var footersAttributes: [Int: UICollectionViewLayoutAttributes] = [:]
    /// 单元块位置缓存 用来快速索引单元属性
    private var unionRects: [CGRect] = []
    /// 每块矩阵单元格基数
    private let unionSize = 20
    /// 单元区域缓存 顺序
    private var sectionRects: [SectionRect] = []
}

extension WaterfallFlowLayout {
    /// 单元区域缓存
    private struct SectionRect {
        let section: Int
        let rect: CGRect
    }

    /// pinned headers and footers
    private var currentVisibleBounds: CGRect {
        let collectionView = currentCollectionView
        let contentInset = collectionView.adjustedContentInset
        let refreshControlHeight: CGFloat
        #if os(iOS)
            if
                let refreshControl = currentCollectionView.refreshControl,
                refreshControl.isRefreshing
            {
                refreshControlHeight = refreshControl.bounds.height
            } else {
                refreshControlHeight = 0
            }
        #else
            refreshControlHeight = 0
        #endif

        return CGRect(
            x: collectionView.bounds.minX + contentInset.left,
            y: collectionView.bounds.minY + contentInset.top - refreshControlHeight,
            width: collectionView.bounds.width - contentInset.left - contentInset.right,
            height: collectionView.bounds.height - contentInset.top - contentInset.bottom + refreshControlHeight
        )
    }

    /// 悬浮header查找计算
    /// - Parameter visibleBounds: 展示区域
    /// - Returns: header属性
    private func findCalculationPinnedHeaderAttributes(in visibleBounds: CGRect) {
        for sectionRect in sectionRects {
            guard let header = headersAttributes[sectionRect.section] else {
                continue
            }
            let footer = footersAttributes[sectionRect.section]
            header.frame.origin.y = min(
                max(visibleBounds.minY, sectionRect.rect.minY),
                sectionRect.rect.maxY - (footer?.frame.height ?? 0) - header.frame.height
            )
        }
    }

    /// 悬浮footer查找计算
    /// - Parameter visibleBounds: 展示区域
    /// - Returns: header属性
    private func findCalculationPinnedFooterAttributes(in visibleBounds: CGRect) {
        for sectionRect in sectionRects {
            guard let footer = footersAttributes[sectionRect.section] else {
                continue
            }
            let header = footersAttributes[sectionRect.section]
            footer.frame.origin.y = max(
                min(visibleBounds.maxY - footer.frame.height, sectionRect.rect.maxY - footer.frame.height),
                sectionRect.rect.minY + (header?.frame.height ?? 0)
            )
        }
    }
}

extension WaterfallFlowLayout {
    /// 当前CollectionView
    private var currentCollectionView: UICollectionView {
        guard let collectionView = collectionView else {
            preconditionFailure("`collectionView` should not be `nil`")
        }

        return collectionView
    }

    /// 所在`section`支持的列数
    /// - Parameter section: section
    /// - Returns: columnCount
    private func columnCount(forSection section: Int) -> Int {
        return waterfallDelegate?.collectionView?(
            currentCollectionView, numberOfColumnInSection: section
        ) ?? columnCount
    }

    /// 所在`section`支持的渲染填充方式
    /// - Parameter section: section
    /// - Returns: 填充方式
    private func itemRenderDirection(forSection section: Int) -> ItemRenderDirection {
        return waterfallDelegate?.collectionView?(
            currentCollectionView, itemRenderDirectionInSection: section
        ) ?? itemRenderDirection
    }

    /// 展示内容宽度
    private var collectionViewContentWidth: CGFloat {
        let collectionView = currentCollectionView
        let insets: UIEdgeInsets
        switch sectionInsetReference {
        case .fromContentInset:
            insets = collectionView.contentInset
        case .fromSafeArea:
            if #available(iOS 11.0, *) {
                insets = collectionView.safeAreaInsets
            } else {
                insets = .zero
            }
        case .fromLayoutMargins:
            insets = collectionView.layoutMargins
        @unknown default:
            insets = .zero
        }
        return collectionView.bounds.size.width - insets.left - insets.right
    }

    /// 所在section宽度
    /// - Parameter section: section description
    /// - Returns: description
    private func collectionViewContentWidth(ofSection section: Int) -> CGFloat {
        let collectionView = currentCollectionView
        let insets = delegate?.collectionView?(collectionView, layout: self, insetForSectionAt: section) ?? sectionInset
        return collectionViewContentWidth - insets.left - insets.right
    }

    /// 查找最短列
    ///
    /// - Returns: index for the shortest column
    private func shortestColumnIndex(inSection section: Int) -> Int {
        return columnHeights[section].enumerated()
            .min(by: { $0.element < $1.element })?
            .offset ?? 0
    }

    /// 查找最长列
    ///
    /// - Returns: index for the longest column
    private func longestColumnIndex(inSection section: Int) -> Int {
        return columnHeights[section].enumerated()
            .max(by: { $0.element < $1.element })?
            .offset ?? 0
    }

    /// 查找下一列索引
    ///
    /// - Returns: index for the next column
    private func nextColumnIndexForItem(_ item: Int, inSection section: Int) -> Int {
        var index = 0
        let columnCount = self.columnCount(forSection: section)
        let itemRenderDirection = itemRenderDirection(forSection: section)
        switch itemRenderDirection {
        case .shortestFirst:
            index = shortestColumnIndex(inSection: section)
        case .leftToRight:
            index = item % columnCount
        case .rightToLeft:
            index = (columnCount - 1) - (item % columnCount)
        }
        return index
    }
}

// swiftlint:enable file_length function_body_length cyclomatic_complexity
