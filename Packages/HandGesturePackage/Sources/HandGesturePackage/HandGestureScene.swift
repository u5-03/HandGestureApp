//
//  HandGestureScene.swift
//  HandGesturePackage
//
//  Created by yugo.sugiyama on 2025/06/05.
//

import SwiftUI

public struct HandGestureScene: Scene {
    public init() {}

    public var body: some Scene {
        WindowGroup(id: SceneId.top) {
            TopView()
        }

        ImmersiveSpace(id: SceneId.immersive) {
//            ImmersiveView()
//                .environment(appModel)
//                .onAppear {
//                    appModel.immersiveSpaceState = .open
//                    avPlayerViewModel.play()
//                }
//                .onDisappear {
//                    appModel.immersiveSpaceState = .closed
//                    avPlayerViewModel.reset()
//                }
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
