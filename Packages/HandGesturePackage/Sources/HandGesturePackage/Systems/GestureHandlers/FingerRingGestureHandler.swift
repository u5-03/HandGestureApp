//
//  FingerRingGestureHandler.swift
//  HandGesturePackage
//
//  Created by yugo.sugiyama on 2025/06/05.
//

import RealityKit
import SwiftUI
import Foundation

/// リング表示のジェスチャーハンドラー
@MainActor
enum FingerRingGestureHandler {

    /// リングオブジェクトの表示・非表示を処理
    static func handleDisplay(
        entity: Entity,
        handComponent: inout HandTrackingComponent,
        didGestureDetected: Bool,
        position: SIMD3<Float>
    ) {
        if didGestureDetected {
            // リングが存在しない場合は作成
            if handComponent.pinchSphere == nil {
                createRing(entity: entity, handComponent: &handComponent)
            }

            // リングの位置を更新
            if let ring = handComponent.pinchSphere {
                ring.position = position
            }
        } else {
            // ジェスチャーが検出されていない時はリングを削除
            removeRing(handComponent: &handComponent)
        }
    }

    // MARK: - Private Helper Methods

    /// リング（穴のある円）を作成
    private static func createRing(
        entity: Entity,
        handComponent: inout HandTrackingComponent
    ) {
        let circlePath = Path { path in
            path.addArc(center: .zero, radius: 0.04,
                        startAngle: .degrees(0), endAngle: .degrees(360), clockwise: true)
            path.addArc(center: .zero, radius: 0.03,
                        startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
        }

        var extrusionOptions = MeshResource.ShapeExtrusionOptions()
        extrusionOptions.extrusionMethod = .linear(depth: 0.005)
        extrusionOptions.boundaryResolution = .uniformSegmentsPerSpan(segmentCount: 32)

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .blue)
        material.emissiveColor = .init(color: .blue)
        material.emissiveIntensity = 1.0

        let ring = ModelEntity(
            mesh: try! MeshResource(extruding: circlePath, extrusionOptions: extrusionOptions),
            materials: [material]
        )
        ring.name = "\(handComponent.chirality)_PINCH_RING"

        entity.addChild(ring)
        handComponent.pinchSphere = ring
    }

    /// リングを削除
    private static func removeRing(handComponent: inout HandTrackingComponent) {
        // ピンチしていない時はタイミングをリセット
        handComponent.pinchStartTime = 0
        handComponent.isPinchValid = false

        // リングを削除
        if let ring = handComponent.pinchSphere {
            ring.removeFromParent()
            handComponent.pinchSphere = nil
        }
    }
}
