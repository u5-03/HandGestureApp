//
//  TopView.swift
//  HandGesturePackage
//
//  Created by yugo.sugiyama on 2025/06/05.
//

import SwiftUI

struct TopView: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        Button("Open Immersive Space") {
            Task {
                await openImmersiveSpace(id: SceneId.immersive)
            }
        }
    }
}

#Preview {
    TopView()
}
