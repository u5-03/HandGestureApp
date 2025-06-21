//
//  HandTrackingComponent.swift
//  HandGesturePackage
//
//  Created by yugo.sugiyama on 2025/06/05.
//

import RealityKit
import ARKit
import Foundation

/// 手のトラッキング情報を保持するコンポーネント
public struct HandTrackingComponent: Component {
    /// 左手か右手かを示す
    public var chirality: HandAnchor.Chirality

    /// 各関節のエンティティを保持する辞書
    public var fingers: [HandSkeleton.JointName: Entity] = [:]

    /// 骨（関節間の接続）のエンティティを保持する辞書
    public var bones: [HandSkeleton.JointName: ModelEntity] = [:]

    /// 現在検出されている片手ジェスチャーのリスト
    public var currentGestures: [HandGestureType] = []

    /// ピンチ開始時刻（秒）
    public var pinchStartTime: TimeInterval = 0

    /// ピンチが有効かどうか（一定時間継続している）
    public var isPinchValid: Bool = false

    /// ピンチ時に表示される球体エンティティ
    public var pinchSphere: ModelEntity?

    public init(chirality: HandAnchor.Chirality) {
        self.chirality = chirality

        HandTrackingSystem.registerSystem()
    }
}