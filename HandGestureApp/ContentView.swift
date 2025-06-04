//
//  ContentView.swift
//  HandGestureApp
//
//  Created by yugo.sugiyama on 2025/06/05.
//

import SwiftUI
import RealityKit

struct ContentView: View {

    var body: some View {
        VStack {
            ToggleImmersiveSpaceButton()
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
