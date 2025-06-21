//
//  FingerRingDetector.swift
//  HandGesturePackage
//
//  Created by yugo.sugiyama on 2025/06/05.
//

import RealityKit
import ARKit
import simd
import Foundation

/// 指の接触や近接を検出してリング表示を制御するクラス
@MainActor
enum FingerRingDetector {

    /// 手の情報
    struct HandInfo {
        let entity: Entity
        let handComponent: HandTrackingComponent
        let handSkeleton: HandSkeleton
        let handAnchor: HandAnchor
    }

    /// 検出結果（左右両手分）
    struct DetectionResults {
        let leftHand: HandResult?
        let rightHand: HandResult?
    }

    /// 単一の手の検出結果
    struct HandResult {
        let shouldShowObject: Bool
        let position: SIMD3<Float>
        let isValid: Bool
        let smoothedPosition: SIMD3<Float> // スムージング後の位置
    }

    /// 前回の位置を保存するための静的変数（スムージング用）
    private static var previousLeftPosition: SIMD3<Float>?
    private static var previousRightPosition: SIMD3<Float>?

    /// スムージング係数（0.0-1.0、値が小さいほどスムーズ）
    private static let smoothingFactor: Float = 0.3

    /// 両手の情報を元にジェスチャー検出を実行
    static func detectGestures(handEntities: [Entity]) -> DetectionResults {
        var leftHandInfo: HandInfo?
        var rightHandInfo: HandInfo?

        // 左右の手の情報を収集
        for entity in handEntities {
            guard let handComponent = entity.components[HandTrackingComponent.self] else { continue }

            let handAnchor: HandAnchor?
            switch handComponent.chirality {
            case .left:
                handAnchor = HandTrackingSystem.latestLeftHand
            case .right:
                handAnchor = HandTrackingSystem.latestRightHand
            default:
                handAnchor = nil
            }

            guard let anchor = handAnchor,
                  let skeleton = anchor.handSkeleton else { continue }

            let handInfo = HandInfo(
                entity: entity,
                handComponent: handComponent,
                handSkeleton: skeleton,
                handAnchor: anchor
            )

            if handComponent.chirality == .left {
                leftHandInfo = handInfo
            } else if handComponent.chirality == .right {
                rightHandInfo = handInfo
            }
        }

        // 左手の検出
        let leftResult = leftHandInfo.map { info in
            detectThumbIndexPinch(handInfo: info, isLeft: true)
        }

        // 右手の検出
        let rightResult = rightHandInfo.map { info in
            detectThumbIndexPinch(handInfo: info, isLeft: false)
        }

        return DetectionResults(
            leftHand: leftResult,
            rightHand: rightResult
        )
    }

    /// 親指と人差し指のピンチ検出（スムージング付き）
    private static func detectThumbIndexPinch(handInfo: HandInfo, isLeft: Bool) -> HandResult {
        // 親指と人差し指の位置を取得
        let (thumbPos, indexPos) = getThumbAndIndexPositions(handSkeleton: handInfo.handSkeleton)
        let (thumbWorldPos, indexWorldPos) = getWorldPositions(
            thumbPos: thumbPos,
            indexPos: indexPos,
            handAnchor: handInfo.handAnchor
        )

        // 距離計算
        let distance = simd_distance(thumbPos, indexPos)
        let isPinching = distance < 0.03

        // 中点計算
        let rawPosition = (thumbWorldPos + indexWorldPos) * 0.5

        // スムージング適用
        let smoothedPosition: SIMD3<Float>
        if isLeft {
            if let prev = previousLeftPosition {
                smoothedPosition = prev * (1.0 - smoothingFactor) + rawPosition * smoothingFactor
            } else {
                smoothedPosition = rawPosition
            }
            previousLeftPosition = smoothedPosition
        } else {
            if let prev = previousRightPosition {
                smoothedPosition = prev * (1.0 - smoothingFactor) + rawPosition * smoothingFactor
            } else {
                smoothedPosition = rawPosition
            }
            previousRightPosition = smoothedPosition
        }

        // タイミング検証
        let currentTime = Date().timeIntervalSince1970
        var isValid = false

        if isPinching {
            let pinchDuration = handInfo.handComponent.pinchStartTime > 0 ? currentTime - handInfo.handComponent.pinchStartTime : 0
            isValid = pinchDuration >= 0.25
        }

        return HandResult(
            shouldShowObject: isPinching && isValid,
            position: rawPosition,
            isValid: isValid,
            smoothedPosition: smoothedPosition
        )
    }

    // MARK: - Private Helper Methods

    /// 親指と人差し指の位置を取得
    private static func getThumbAndIndexPositions(
        handSkeleton: HandSkeleton
    ) -> (thumbPos: SIMD3<Float>, indexPos: SIMD3<Float>) {
        let thumbTip = handSkeleton.joint(.thumbTip)
        let indexTip = handSkeleton.joint(.indexFingerTip)

        let thumbPosition = thumbTip.anchorFromJointTransform.columns.3
        let indexPosition = indexTip.anchorFromJointTransform.columns.3

        return (
            SIMD3<Float>(thumbPosition.x, thumbPosition.y, thumbPosition.z),
            SIMD3<Float>(indexPosition.x, indexPosition.y, indexPosition.z)
        )
    }

    /// ローカル座標をワールド座標に変換
    private static func getWorldPositions(
        thumbPos: SIMD3<Float>,
        indexPos: SIMD3<Float>,
        handAnchor: HandAnchor
    ) -> (SIMD3<Float>, SIMD3<Float>) {
        let thumb4 = SIMD4<Float>(thumbPos.x, thumbPos.y, thumbPos.z, 1)
        let index4 = SIMD4<Float>(indexPos.x, indexPos.y, indexPos.z, 1)

        let thumbWorld = handAnchor.originFromAnchorTransform * thumb4
        let indexWorld = handAnchor.originFromAnchorTransform * index4

        return (
            SIMD3<Float>(thumbWorld.x, thumbWorld.y, thumbWorld.z),
            SIMD3<Float>(indexWorld.x, indexWorld.y, indexWorld.z)
        )
    }
}
