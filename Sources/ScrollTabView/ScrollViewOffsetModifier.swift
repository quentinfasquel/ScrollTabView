//
//  ScrollViewOffsetModifier.swift
//  ScrollTabView
//
//  Created by Quentin Fasquel on 25/01/2023.
//

import Combine
import SwiftUI

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

struct ScrollViewOffsetModifier: ViewModifier {
    let coordinateSpace: String

    @Binding public var contentOffset: CGPoint
    @Binding public var contentSize: CGSize

    public func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometryProxy in
                    let frame = geometryProxy.frame(in: .named(coordinateSpace))
                    let contentOffset = CGPoint(x: -frame.minX, y: frame.minY)
                    Color.clear
                        .preference(key: ScrollViewOffsetPreferenceKey.self, value: contentOffset)
                        .onChange(of: geometryProxy.frame(in: .local).size, perform: { newValue in
                            self.contentSize = newValue
                        })
                }
            }
            .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { contentOffset in
                self.contentOffset = contentOffset
            }
    }
}

extension View {
    func readingScrollView(
        coordinateSpace: String,
        contentOffset: Binding<CGPoint>,
        contentSize: Binding<CGSize>
    ) -> some View {
        modifier(ScrollViewOffsetModifier(
            coordinateSpace: coordinateSpace,
            contentOffset: contentOffset,
            contentSize: contentSize))
    }
}
