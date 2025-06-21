//
//  HandGestureImmersiveView.swift
//  HandGesturePackage
//
//  Created by yugo.sugiyama on 2025/06/05.
//

import SwiftUI
import RealityKit

/// ハンドジェスチャー体験用のImmersiveView
public struct HandGestureImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    
    public init() {}
    
    public var body: some View {
        // メインのハンドジェスチャー検出用RealityView
        HandGestureRealityView()
            .ignoresSafeArea()
        .onAppear {
            appModel.updateImmersiveSpaceState(.open)
            print("ImmersiveView appeared - Hand tracking started")
        }
        .onDisappear {
            appModel.updateImmersiveSpaceState(.closed)
            appModel.resetPinchStates()
            print("ImmersiveView disappeared - Hand tracking stopped")
        }
    }
}

#Preview(immersionStyle: .mixed) {
    HandGestureImmersiveView()
        .environment(AppModel.shared)
} 
