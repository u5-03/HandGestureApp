//
//  HandGestureApp.swift
//  HandGestureApp
//
//  Created by yugo.sugiyama on 2025/06/05.
//

import SwiftUI
import HandGesturePackage

@main
struct HandGestureApp: App {
        
    var body: some Scene {
        HandGestureScene()
//        WindowGroup {
//            if avPlayerViewModel.isPlaying {
//                AVPlayerView(viewModel: avPlayerViewModel)
//            } else {
//                ContentView()
//                    .environment(appModel)
//            }
//        }
//        
//        ImmersiveSpace(id: appModel.immersiveSpaceID) {
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
//        }
//        .immersionStyle(selection: .constant(.full), in: .full)
    }
}
