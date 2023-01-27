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

public struct ScrollTabView<TabItem: ScrollTabItem>: View {

    // MARK: Public Properties

    public var items: [TabItem]
    @Binding public var selectedItem: TabItem?

    public init(items: [TabItem], selectedItem: Binding<TabItem?>) {
        self.items = items
        self._selectedItem = selectedItem
    }

    // MARK: Private Properties

    @State private var contentOffset: CGPoint = .zero
    @State private var contentSize: CGSize = .zero
    @State private var selectedItemWidth: CGFloat = 0
    @State private var viewSize: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var isDecelerating: Bool = false

    @Environment(\.scrollIndicatorStyle) private var scrollIndicatorStyle

    // MARK: Private Constants

    private let feedbackGenerator = UISelectionFeedbackGenerator()
    private let itemSpacing: CGFloat = 0
    private let itemWidth: CGFloat = 90
    private let tabHeight: CGFloat = 64
    private let scrollSpaceName = "_ScrollTabView_"

    // MARK: -

    public var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .center, spacing: itemSpacing) {
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
                    scrollIndicator(selectedItemWidth, viewSize: geometry.size)
                        .animation(.spring(), value: selectedItemWidth)
                }
            }
            .onAppear {
                if selectedItem == nil {
                    // Autoselect first item
                    selectedItem = items.first
                }
                viewSize = geometry.size
            }
            .onChange(of: contentOffset) { contentOffset in
                setSelectedItem(item(at: contentOffset))
            }
        }
        .frame(height: tabHeight)
        // Add a seperator line
        .background(alignment: .bottom) {
            Rectangle()
                .frame(height: 1)
                .opacity(0.25)
                .foregroundStyle(.foreground)
        }
    }

    @ViewBuilder
    private func tabItemView(_ item: TabItem) -> some View {
        let isSelected = selectedItem == item

        VStack(alignment: .center, spacing: 0) {
            Image(systemName: item.systemImage)
                .font(.system(size: 24, weight: .semibold))
                .frame(height: 44)
            Text(item.title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
        .opacity(isSelected ? 1 : 0.5)
        .animation(.linear, value: isSelected)
        .overlay(alignment: .bottom) {
            GeometryReader { itemProxy in
                Color.clear
                    .onChange(of: selectedItem) { newValue in
                        if newValue == item {
                            selectedItemWidth = itemProxy.size.width
                        }
                    }
                    .onAppear {
                        if isSelected {
                            selectedItemWidth = itemProxy.size.width
                        }
                    }
            }
        }
        .frame(width: itemWidth)
    }

    // MARK: - Scroll Indicator

    @ViewBuilder
    private func scrollIndicator(_ indicatorWidth: CGFloat, viewSize: CGSize) -> some View {
        let width = itemWidth
        let minX: CGFloat = (width - indicatorWidth)
        let maxX: CGFloat = (contentSize.width - viewSize.width)
        let x = contentOffset.x * (viewSize.width - width) / (contentSize.width - viewSize.width)

        Capsule()
            .frame(width: indicatorWidth, height: 3)
            .position(x: min(maxX, max(minX, x + width * 0.5)), y: viewSize.height - 1)
            .foregroundStyle(scrollIndicatorStyle)
    }

    private func itemPosition(index: Int) -> CGFloat {
        return CGFloat(index) * itemWidth + CGFloat(index - 1) * itemSpacing
    }

    private func scrollOffset(index: Int) -> CGFloat {
        let x = itemPosition(index: index) / (contentSize.width - itemWidth)
        return x * (contentSize.width - viewSize.width)
    }

    private func indexOfItem(at position: CGPoint) -> Int {
        let x = min(1, max(0, position.x / (contentSize.width - viewSize.width)))
        return min(items.count - 1, Int(x * CGFloat(items.count)))
    }

    private func item(at position: CGPoint) -> TabItem {
        return items[indexOfItem(at: position)]
    }

    // MARK: - Handling Selection

    private func didSelectTabItem(_ item: TabItem, proxy: ScrollViewProxy) {
        if let index = setSelectedItem(item, feedback: false) {
            scrollTo(item, proxy: proxy, index: index)
            feedbackGenerator.selectionChanged()
        }
    }

    @discardableResult
    private func setSelectedItem(_ item: TabItem, feedback: Bool = true) -> Int? {
        guard item != selectedItem, let index = items.firstIndex(of: item) else { return nil }
        selectedItem = item
        if isDragging || isDecelerating {
            feedbackGenerator.selectionChanged()
        }
        return index
    }

    private func scrollTo(_ item: TabItem, proxy: ScrollViewProxy, index: Int) {
        let x = itemPosition(index: index) / (contentSize.width - itemWidth)
        withAnimation(.spring()) {
            proxy.scrollTo(item.id, anchor: UnitPoint(x: x, y: 0))
        }
    }

    private func snapToSelection(proxy: ScrollViewProxy) {
        if !isDragging, let item = selectedItem, let index = items.firstIndex(of: item) {
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
