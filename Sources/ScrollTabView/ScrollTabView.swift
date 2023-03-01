//
//  ScrollTabView.swift
//  ScrollTabView
//
//  Created by Quentin Fasquel on 17/01/2023.
//

import SwiftUI
import ScrollViewEvents

public protocol ScrollTabItem: Identifiable, Equatable {
    var title: String { get }
    var systemImage: String { get }
}

public struct ScrollTabView<TabItem: ScrollTabItem, TabItemView: View>: View {

    // MARK: Public Properties

    let alignment: HorizontalAlignment
    @Binding public var items: [TabItem]
    @Binding public var selectedItem: TabItem?

    public init(
        alignment: HorizontalAlignment = .center,
        items: Binding<[TabItem]>,
        selectedItem: Binding<TabItem?>,
        onSelectItem: ((TabItem) -> Void)? = nil,
        itemViewBuilder: @escaping (TabItem) -> TabItemView
    ) {
        self.alignment = alignment
        self._items = items
        self._selectedItem = selectedItem
        self.onSelectItem = onSelectItem
        self.itemViewBuilder = itemViewBuilder
    }

    public init(
        alignment: HorizontalAlignment = .center,
        items: Binding<[TabItem]>,
        selectedItem: Binding<TabItem?>,
        onSelectItem: ((TabItem) -> Void)? = nil
    ) where TabItemView == ScrollTabItemView<TabItem> {
        self.alignment = alignment
        self._items = items
        self._selectedItem = selectedItem
        self.onSelectItem = onSelectItem
        self.itemViewBuilder = TabItemView.init(item:)
    }

    // MARK: Private Properties

    private var onSelectItem: ((TabItem) -> Void)?
    private var itemViewBuilder: (TabItem) -> TabItemView

    @State private var contentOffset: CGPoint = .zero
    @State private var contentSize: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    @State private var focusedItem: TabItem?
    @State private var focusedItemWidth: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isDecelerating: Bool = false

    @Environment(\.scrollIndicatorStyle) private var scrollIndicatorStyle

    // MARK: Private Constants

    private let feedbackGenerator = UISelectionFeedbackGenerator()
    private let itemSpacing: CGFloat = 0
    private let itemWidth: CGFloat = 90
    private let tabHeight: CGFloat = 64
    private let scrollSpaceName = "_ScrollTabView_"

    private var showSpacers: Bool { contentSize.width <= viewSize.width }
    private var showLeadingSpacer: Bool { showSpacers && alignment == .trailing }
    private var showTrailingSpacer: Bool { showSpacers && alignment == .leading }

    // MARK: -

    public var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: itemSpacing) {
                        if showLeadingSpacer {
                            Spacer()
                        }
                        ForEach(items) { item in
                            Button {
                                didSelectTabItem(item, proxy: proxy)
                            } label: {
                                tabItemView(item)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundStyle(.foreground)
                            .tag(item.id)
                        }
                        if showTrailingSpacer {
                            Spacer()
                        }
                    }
                    .frame(minWidth: geometry.size.width)
                    .readingScrollView(
                        coordinateSpace: scrollSpaceName,
                        contentOffset: $contentOffset,
                        contentSize: $contentSize)
                }
                .scrollWillBeginDragging {
                    isDragging = true
                } willEndDragging: { velocity, contentOffset in
                    if velocity.x != 0 {
                        let index = indexOfItem(at: contentOffset)
                        contentOffset.x = scrollOffset(index: index)
                    }
                } didEndDragging: { decelerate in
                    isDragging = false
                    isDecelerating = decelerate
                    if !decelerate {
                        snapToSelection(proxy: proxy)
                    }
                } didEndDecelerating: {
                    isDecelerating = false
                }
                .coordinateSpace(name: scrollSpaceName)
                .overlay(alignment: .bottom) {
                    scrollIndicator(focusedItemWidth, viewSize: geometry.size)
                        .animation(.spring(), value: focusedItemWidth)
                        .animation(.spring(), value: focusedItem)
                }
            }
            .onAppear {
                if focusedItem == nil {
                    // Autoselect first item
                    focusedItem = items.first
                    updateSelection()
                }
            }
            .onChange(of: contentSize) { _ in
                viewSize = geometry.frame(in: .local).size
            }
            .onChange(of: contentOffset) { contentOffset in
                if contentSize.width > viewSize.width, let item = item(at: contentOffset) {
                    setFocusedItem(item)
                }
            }
            .onChange(of: isDecelerating) { decelerating in
                if !decelerating {
                    updateSelection()
                }
            }
            // Add a seperator line
            .background(alignment: .bottom) {
                Rectangle()
                    .frame(height: 1)
                    .opacity(0.25)
                    .foregroundStyle(.foreground)
            }
        }
    }

    @ViewBuilder
    private func tabItemView(_ item: TabItem) -> some View {
        let isSelected = focusedItem == item

        itemViewBuilder(item)
            .opacity(isSelected ? 1 : 0.5)
            .animation(.linear, value: isSelected)
            .overlay(alignment: .bottom) {
                GeometryReader { itemProxy in
                    Color.clear
                        .onChange(of: focusedItem) { newValue in
                            if newValue == item {
                                focusedItemWidth = itemProxy.size.width
                            }
                        }
                        .onAppear {
                            if isSelected {
                                focusedItemWidth = itemProxy.size.width
                            }
                        }
                }
            }
            .frame(width: itemWidth)
    }

    // MARK: - Scroll Indicator

    private var focusedIndex: Int {
        if let item = focusedItem { return items.firstIndex(of: item) ?? 0 } else { return 0 }
    }

    @ViewBuilder
    private func scrollIndicator(_ indicatorWidth: CGFloat, viewSize: CGSize) -> some View {
        let intrinsinctWidth = itemWidth * CGFloat(items.count) + itemSpacing * CGFloat(items.count - 1)
        let width = itemWidth
        let minWidth = min(intrinsinctWidth, viewSize.width)
        let maxWidth = max(intrinsinctWidth, viewSize.width)
        let spacingWidth = max(0, viewSize.width - intrinsinctWidth)
        let dx = width * 0.5 + spacingWidth * 0.5
        let x: CGFloat = {
            if contentSize.width > viewSize.width {
                return contentOffset.x * (viewSize.width - width) / (maxWidth - minWidth) + dx
            } else {
                switch alignment {
                case .leading:
                    return itemPosition(for: focusedIndex) + width * 0.5
                case .trailing:
                    return itemPosition(for: focusedIndex) + width * 0.5 + spacingWidth
                default: // center
                    return itemPosition(for: focusedIndex) + width * 0.5 + spacingWidth * 0.5
                }
            }
        }()

        Capsule()
            .frame(width: indicatorWidth, height: 3)
            .offset(x: x - viewSize.width * 0.5)
            .foregroundStyle(scrollIndicatorStyle)
    }

    private func scrollOffset(index: Int) -> CGFloat {
        let x = itemPosition(for: index) / (contentSize.width - itemWidth)
        return x * max(0, contentSize.width - viewSize.width)
    }

    private func indexOfItem(at position: CGPoint) -> Int {
        let x = min(1, max(0, position.x / (contentSize.width - viewSize.width)))
        return min(items.count - 1, Int(x * CGFloat(items.count)))
    }

    private func itemPosition(for index: Int) -> CGFloat {
        return CGFloat(index) * itemWidth + CGFloat(index) * itemSpacing
    }

    private func item(at position: CGPoint) -> TabItem? {
        guard items.count > 0 else { return nil }
        return items[indexOfItem(at: position)]
    }

    // MARK: - Handling Selection

    private func updateSelection() {
        if selectedItem != focusedItem {
            selectedItem = focusedItem
        }
    }

    private func didSelectTabItem(_ item: TabItem, proxy: ScrollViewProxy) {
        onSelectItem?(item)
        if let index = setFocusedItem(item, feedback: false) {
            scrollTo(item, proxy: proxy, index: index)
            feedbackGenerator.selectionChanged()
        }
    }

    @discardableResult
    private func setFocusedItem(_ item: TabItem, feedback: Bool = true) -> Int? {
        guard item != focusedItem, let index = items.firstIndex(of: item) else { return nil }
        focusedItem = item
        if isDragging || isDecelerating {
            feedbackGenerator.selectionChanged()
        }
        return index
    }

    private func scrollTo(_ item: TabItem, proxy: ScrollViewProxy, index: Int) {
        let x = itemPosition(for: index) / (contentSize.width - itemWidth)
        withAnimation(.spring()) {
            proxy.scrollTo(item.id, anchor: UnitPoint(x: x, y: 0))
        }
        updateSelection()
    }

    private func snapToSelection(proxy: ScrollViewProxy) {
        if !isDragging, let item = focusedItem, let index = items.firstIndex(of: item) {
            scrollTo(item, proxy: proxy, index: index)
        }
    }
}

extension View {
    public func scrollIndicatorStyle<S: ShapeStyle>(_ style: S) -> some View {
        self.environment(\.scrollIndicatorStyle, AnyShapeStyle(style))
    }
}


private struct ScrollIndicatorStyleEnvironmentKey: EnvironmentKey {
    static let defaultValue: AnyShapeStyle = AnyShapeStyle(.tint)
}

extension EnvironmentValues {
    var scrollIndicatorStyle: AnyShapeStyle {
        get { self[ScrollIndicatorStyleEnvironmentKey.self] }
        set { self[ScrollIndicatorStyleEnvironmentKey.self] = newValue }
    }
}

extension SwiftUI.Image {
    init?(safeSystemName: String) {
        guard nil != UIImage(systemName: safeSystemName) else { return nil }
        self.init(systemName: safeSystemName)
    }
}

public struct ScrollTabItemView<TabItem: ScrollTabItem>: View {
    public var item: TabItem

    public var body: some View {
        VStack(alignment: .center, spacing: 0) {
            (Image(safeSystemName: item.systemImage) ?? Image(systemName: "circle.fill"))
                .font(.system(size: 24, weight: .semibold))
                .frame(height: 44)
            Text(item.title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
        }
        .frame(height: 64) // default menu height
    }
}
