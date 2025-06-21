//
//  HandGestureRealityView.swift
//  HandGesturePackage
//
//  Created by yugo.sugiyama on 2025/06/05.
//

import SwiftUI
import RealityKit
import ARKit

/// ハンドジェスチャー検出用のRealityView
public struct HandGestureRealityView: View {
    @State private var rootEntity = Entity()

    public init() {}

    public var body: some View {
        RealityView { content, attachments in
            // ルートエンティティをシーンに追加
            content.add(rootEntity)

            // 左手と右手のエンティティを作成
            createHandEntities()

            // HandTrackingSystemを登録
            registerHandTrackingSystem(content: content)

            // フローティングメニューのattachmentを配置
            if let floatingMenuAttachment = attachments.entity(for: "FloatingMenu") {
                // ユーザーの視点から下に50cm、奥に50cmの位置に配置
                floatingMenuAttachment.position = SIMD3<Float>(0.0, -0.5, 0.5) // x: 中央, y: 下に50cm, z: 奥に50cm

                // 45度上向きに傾けて、ユーザーから見て正面に見えるようにする
                let rotationAngle: Float = -45.0 * .pi / 180.0 // -45度をラジアンに変換（上向きに傾ける）
                floatingMenuAttachment.transform.rotation = simd_quatf(angle: rotationAngle, axis: [1, 0, 0]) // X軸周りに回転

                content.add(floatingMenuAttachment)
            }
        } update: { content, attachments in
            // 必要に応じてattachmentの位置を更新
            if let floatingMenuAttachment = attachments.entity(for: "FloatingMenu") {
                // 動的な位置更新が必要な場合はここで行う
            }
        } attachments: {
            Attachment(id: "FloatingMenu") {
                FloatingMenuView()
                    .frame(width: 350, height: 400)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 10)
            }
        }
        .task {
            // ARKitセッションの権限をリクエスト
            await requestHandTrackingAuthorization()
        }
    }
}

private extension HandGestureRealityView {

    @MainActor
    func createHandEntities() {
        // 左手エンティティの作成
        let leftHandEntity = Entity()
        leftHandEntity.name = "LeftHand"
        leftHandEntity.components.set(HandTrackingComponent(chirality: .left))
        rootEntity.addChild(leftHandEntity)

        // 右手エンティティの作成
        let rightHandEntity = Entity()
        rightHandEntity.name = "RightHand"
        rightHandEntity.components.set(HandTrackingComponent(chirality: .right))
        rootEntity.addChild(rightHandEntity)
    }

    @MainActor
    func registerHandTrackingSystem(content: RealityViewContent) {
        // RealityViewではScene.systemメソッドが使用できないため、
        // HandTrackingSystemを直接初期化してARKitセッションを開始

        // 注意: この実装は簡易的なものです
        // 実際のプロダクションでは、より適切なシステム管理が必要になる場合があります

        // HandTrackingSystemを初期化（ARKitセッションの開始のみ）
        Task {
            await HandTrackingSystem.runSession()
        }

        print("Hand entities created and ready for tracking")
    }

    func requestHandTrackingAuthorization() async {
        // ARKitSessionのインスタンスを作成してから権限をリクエスト
        let session = ARKitSession()

        let authorizationResult = await session.requestAuthorization(for: [ARKitSession.AuthorizationType.handTracking])

        switch authorizationResult[ARKitSession.AuthorizationType.handTracking] {
        case .allowed:
            print("Hand tracking authorization granted")
        case .denied:
            print("Hand tracking authorization denied")
        case .notDetermined:
            print("Hand tracking authorization not determined")
        case .none:
            print("Hand tracking authorization unknown")
        @unknown default:
            print("Unknown hand tracking authorization status")
        }
    }
}

#Preview {
    HandGestureRealityView()
}
