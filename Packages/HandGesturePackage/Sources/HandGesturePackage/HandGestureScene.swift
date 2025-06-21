//
//  HandGestureScene.swift
//  HandGesturePackage
//
//  Created by yugo.sugiyama on 2025/06/05.
//

import SwiftUI

/// ハンドジェスチャーアプリのメインシーン
public struct HandGestureScene: Scene {
    @State private var appModel = AppModel.shared

    public init() {}

    public var body: some Scene {
        // メインウィンドウ（初回起動時のWelcomeView）
        WindowGroup(id: "WelcomeWindow") {
            WelcomeView()
                .environment(appModel)
        }
        .windowStyle(.plain)
        .defaultSize(width: 1000, height: 600)

        // ImmersiveSpace（ハンドジェスチャー体験）
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            HandGestureImmersiveView()
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
