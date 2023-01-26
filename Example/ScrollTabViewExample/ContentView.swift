//
//  ContentView.swift
//  ScrollTabViewExample
//
//  Created by Quentin Fasquel on 26/01/2023.
//

import SwiftUI
import ScrollTabView

struct CustomTabItem: ScrollTabItem {
    let id = UUID()
    var title: String
    var systemImage: String
}

struct ContentView: View {
    let tabItems: [CustomTabItem] = [
        CustomTabItem(title: "Monday", systemImage: "star.bubble"),
        CustomTabItem(title: "Every silly day", systemImage: "mouth"),
        CustomTabItem(title: "Tuesday", systemImage: "flame"),
        CustomTabItem(title: "Wednesday", systemImage: "sun.dust"),
        CustomTabItem(title: "Thursday", systemImage: "star.bubble"),
        CustomTabItem(title: "Friday", systemImage: "mouth"),
        CustomTabItem(title: "Saturday", systemImage: "flame"),
        CustomTabItem(title: "Sunday", systemImage: "sun.dust")
    ]

    @State private var selectedItem: CustomTabItem?

    var body: some View {
        VStack {
            ScrollTabView(items: tabItems, selectedItem: $selectedItem)
                .scrollIndicatorStyle(.black)
            Spacer()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
