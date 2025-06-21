//
//  WelcomeView.swift
//  HandGesturePackage
//
//  Created by yugo.sugiyama on 2025/06/05.
//

import SwiftUI

/// 初回起動時に表示されるウェルカムビュー
public struct WelcomeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    public init() {}

    public var body: some View {
        VStack(spacing: 30) {
            // アプリタイトル
            VStack(spacing: 16) {
                Image(systemName: "hand.wave.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Hand Gesture Detection")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("visionOS Hand Tracking Experience")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // 説明文
            VStack(alignment: .leading, spacing: 12) {
                Text("このアプリでは以下の機能を体験できます：")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "hand.point.up.left.fill", text: "リアルタイム手のトラッキング")
                    FeatureRow(icon: "hand.thumbsup.fill", text: "片手ジェスチャー認識")
                    FeatureRow(icon: "hands.clap.fill", text: "両手ジェスチャー認識")
                    FeatureRow(icon: "hand.pinch.fill", text: "ピンチ操作検出")
                }
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            
            // 開始ボタン
            Button(action: {
                Task {
                    await startImmersiveExperience()
                }
            }) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("体験を開始")
                }
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(.blue, in: RoundedRectangle(cornerRadius: 12))
            }
            .disabled(appModel.immersiveSpaceState == .inTransition)
            .opacity(appModel.immersiveSpaceState == .inTransition ? 0.6 : 1.0)
            
            if appModel.immersiveSpaceState == .inTransition {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("準備中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(40)
        .preferredColorScheme(.dark)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @MainActor
    private func startImmersiveExperience() async {
        appModel.updateImmersiveSpaceState(.inTransition)
        
        switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
        case .opened:
            // ImmersiveViewのonAppearで.openに設定される
            break
        case .userCancelled, .error:
            appModel.updateImmersiveSpaceState(.closed)
        @unknown default:
            appModel.updateImmersiveSpaceState(.closed)
        }
    }
}

/// 機能説明行
private struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    WelcomeView()
        .environment(AppModel.shared)
} 
