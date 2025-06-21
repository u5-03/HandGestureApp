//
//  HandTrackingSystem.swift
//  HandGesturePackage
//
//  Created by yugo.sugiyama on 2025/06/05.
//

import RealityKit
import SwiftUI
import ARKit
import simd
import Foundation

#if os(visionOS)
import ARKit
#endif

struct HandTrackingSystem: System {
    static var arSession = ARKitSession()
    static let handTracking = HandTrackingProvider()

    static var latestLeftHand: HandAnchor?
    static var latestRightHand: HandAnchor?

    init(scene: RealityKit.Scene) {
        Task { await Self.runSession() }
    }

    @MainActor
    static func runSession() async {
        do {
            try await arSession.run([handTracking])
        } catch let error as ARKitSession.Error {
            print("Error running providers: \(error.localizedDescription)")
        } catch let error {
            print("Unexpected error: \(error.localizedDescription)")
        }

        // Listen for each hand anchor update.
        for await anchorUpdate in handTracking.anchorUpdates {
            switch anchorUpdate.anchor.chirality {
            case .left:
                Self.latestLeftHand = anchorUpdate.anchor
            case .right:
                Self.latestRightHand = anchorUpdate.anchor
            }
        }
    }

    static let query = EntityQuery(where: .has(HandTrackingComponent.self))

    func update(context: SceneUpdateContext) {
        let handEntities = Array(context.entities(matching: Self.query, updatingSystemWhen: .rendering))

        var leftHandSphere: ModelEntity?
        var rightHandSphere: ModelEntity?
        var leftHandEntity: Entity?
        var rightHandEntity: Entity?

        // 手のエンティティの基本セットアップ
        for entity in handEntities {
            guard var handComponent = entity.components[HandTrackingComponent.self] else { continue }

            // If we haven't created the finger joint spheres yet, do so once.
            if handComponent.fingers.isEmpty {
                addJoints(to: entity, handComponent: &handComponent)
            }

            // Find the relevant HandAnchor (left or right).
            guard let handAnchor: HandAnchor = {
                switch handComponent.chirality {
                case .left:  return Self.latestLeftHand
                case .right: return Self.latestRightHand
                default:     return nil
                }
            }() else {
                continue
            }

            // If the skeleton is available, update everything
            if let handSkeleton = handAnchor.handSkeleton {
                updateJointPositions(handSkeleton: handSkeleton, handComponent: &handComponent, handAnchor: handAnchor)
            }

            // Store updated component
            entity.components.set(handComponent)
        }

        // FingerRingDetectorを使用してまとめてジェスチャー検出
        let detectionResults = FingerRingDetector.detectGestures(
            handEntities: handEntities
        )

        // 検出結果を一括処理
        processDetectionResults(
            detectionResults: detectionResults,
            handEntities: handEntities,
            leftHandSphere: &leftHandSphere,
            rightHandSphere: &rightHandSphere,
            leftHandEntity: &leftHandEntity,
            rightHandEntity: &rightHandEntity
        )
    }

    // ----------------------------------------------------------------
    // Process detection results for all hands
    // ----------------------------------------------------------------

    @MainActor private func processDetectionResults(
        detectionResults: FingerRingDetector.DetectionResults,
        handEntities: [Entity],
        leftHandSphere: inout ModelEntity?,
        rightHandSphere: inout ModelEntity?,
        leftHandEntity: inout Entity?,
        rightHandEntity: inout Entity?
    ) {
        // 結果とエンティティのペアを作成
        let handResults: [(result: FingerRingDetector.HandResult, entity: Entity)] = [
            detectionResults.leftHand.flatMap { result in
                handEntities.first { $0.components[HandTrackingComponent.self]?.chirality == .left }
                    .map { (result, $0) }
            },
            detectionResults.rightHand.flatMap { result in
                handEntities.first { $0.components[HandTrackingComponent.self]?.chirality == .right }
                    .map { (result, $0) }
            }
        ].compactMap { $0 }

        // 各手の結果を処理
        for (result, entity) in handResults {
            var handComponent = entity.components[HandTrackingComponent.self]!

            // ジェスチャー検出状態を抽出
            let didGestureDetected = result.shouldShowObject

            updateHandComponentTiming(
                handComponent: &handComponent,
                result: result
            )

            updateAppModel(
                handComponent: handComponent,
                shouldShow: didGestureDetected,
                position: result.smoothedPosition
            )

            FingerRingGestureHandler.handleDisplay(
                entity: entity,
                handComponent: &handComponent,
                didGestureDetected: didGestureDetected,
                position: result.smoothedPosition
            )

            entity.components.set(handComponent)

            // sphere参照の更新
            if didGestureDetected, let circle = handComponent.pinchSphere {
                if handComponent.chirality == .left {
                    leftHandSphere = circle
                    leftHandEntity = entity
                } else if handComponent.chirality == .right {
                    rightHandSphere = circle
                    rightHandEntity = entity
                }
            }
        }
    }

    // ----------------------------------------------------------------
    // 1) Create finger joint spheres if we haven't already
    // ----------------------------------------------------------------

    func addJoints(to handEntity: Entity, handComponent: inout HandTrackingComponent) {
        let radius: Float = 0.005
        let material = UnlitMaterial(color: .yellow)

        // Name the root hand entity
        handEntity.name = handComponent.chirality == .left ? "LEFT_HAND_ROOT" : "RIGHT_HAND_ROOT"

        let sphereEntity = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [material]
        )
        sphereEntity.name = "JOINT_SPHERE_TEMPLATE"

        // Add physics and collision to the template sphere
        sphereEntity.components[CollisionComponent.self] = CollisionComponent(
            shapes: [.generateSphere(radius: radius)],
            mode: .default
        )

        var physics = PhysicsBodyComponent(
            massProperties: .init(mass: 0.01), // Light mass for joints
            material: .generate(staticFriction: 0.5, dynamicFriction: 0.4, restitution: 0.1),
            mode: .kinematic // Kinematic so they follow hand tracking
        )
        physics.isAffectedByGravity = false
        sphereEntity.components[PhysicsBodyComponent.self] = physics

        // Add a small sphere for each joint
        for joint in HandSkeleton.JointName.allCases {
            let newJoint = sphereEntity.clone(recursive: false)
            newJoint.name = "\(handComponent.chirality)_\(joint)"
            handEntity.addChild(newJoint)
            handComponent.fingers[joint] = newJoint
        }

        handEntity.components.set(handComponent)

        // Add the hand root to the scene via AppModel
        // AppModel.shared.addHandRoot(handEntity, chirality: handComponent.chirality)
    }

    // ----------------------------------------------------------------
    // 2) Update the joints & cylinders each frame
    // ----------------------------------------------------------------

    private func updateJointPositions(
        handSkeleton: HandSkeleton,
        handComponent: inout HandTrackingComponent,
        handAnchor: HandAnchor
    ) {
        // オフセット量: 手前（Vision Pro方向）に2.5cm移動
        let offsetTowardsUser: Float = 0.025 // Zの負の方向（手前）に2.5cm

        // Update each joint's transform in world space
        for (jointName, jointEntity) in handComponent.fingers {
            let anchorFromJointTransform = handSkeleton.joint(jointName).anchorFromJointTransform

            // 元の変換行列を取得
            var transformMatrix = handAnchor.originFromAnchorTransform * anchorFromJointTransform

            // Z軸方向にオフセットを適用（手前に移動）
            transformMatrix.columns.3.z += offsetTowardsUser

            jointEntity.setTransformMatrix(
                transformMatrix,
                relativeTo: nil
            )
        }

        // If we haven't created bones yet, do it once
        if handComponent.bones.isEmpty {
            createBones(handComponent: &handComponent, handSkeleton: handSkeleton)
        }

        // Update bone positions and orientations
        for (childJoint, boneModel) in handComponent.bones {
            // Find the parent joint for this bone
            guard let parentJoint = findParentJoint(for: childJoint),
                  let parentEntity = handComponent.fingers[parentJoint],
                  let childEntity = handComponent.fingers[childJoint],
                  let holder = boneModel.parent else {
                continue
            }

            // Calculate the direction and distance between joints in world space
            let parentWorldPos = parentEntity.position(relativeTo: nil)
            let childWorldPos = childEntity.position(relativeTo: nil)
            let worldDirection = childWorldPos - parentWorldPos
            let distance = simd_length(worldDirection)

            // Update the holder's position and orientation in world space
            holder.position = parentWorldPos
            holder.look(at: childWorldPos, from: parentWorldPos, relativeTo: nil)

            // Update the bone's scale and position
            boneModel.transform = Transform(
                scale: [1, distance, 1],
                rotation: simd_quatf(angle: .pi / 2, axis: [1, 0, 0]),
                translation: [0, 0, -distance * 0.5]
            )
        }
    }

    private func findParentJoint(for joint: HandSkeleton.JointName) -> HandSkeleton.JointName? {
        switch joint {
        // Thumb
        case .thumbIntermediateBase: return .thumbKnuckle
        case .thumbIntermediateTip: return .thumbIntermediateBase
        case .thumbTip: return .thumbIntermediateTip

        // Index finger
        case .indexFingerKnuckle: return .indexFingerMetacarpal
        case .indexFingerIntermediateBase: return .indexFingerKnuckle
        case .indexFingerIntermediateTip: return .indexFingerIntermediateBase
        case .indexFingerTip: return .indexFingerIntermediateTip

        // Middle finger
        case .middleFingerKnuckle: return .middleFingerMetacarpal
        case .middleFingerIntermediateBase: return .middleFingerKnuckle
        case .middleFingerIntermediateTip: return .middleFingerIntermediateBase
        case .middleFingerTip: return .middleFingerIntermediateTip

        // Ring finger
        case .ringFingerKnuckle: return .ringFingerMetacarpal
        case .ringFingerIntermediateBase: return .ringFingerKnuckle
        case .ringFingerIntermediateTip: return .ringFingerIntermediateBase
        case .ringFingerTip: return .ringFingerIntermediateTip

        // Little finger
        case .littleFingerKnuckle: return .littleFingerMetacarpal
        case .littleFingerIntermediateBase: return .littleFingerKnuckle
        case .littleFingerIntermediateTip: return .littleFingerIntermediateBase
        case .littleFingerTip: return .littleFingerIntermediateTip

        // Wrist and forearm
        case .wrist: return .forearmWrist
        case .forearmWrist: return .forearmArm

        default: return nil
        }
    }

    // ----------------------------------------------------------------
    // Create bones (cylinders) between connected joints
    // ----------------------------------------------------------------

    private func createBones(handComponent: inout HandTrackingComponent, handSkeleton: HandSkeleton) {
        // Define bone connections - each tuple represents a bone from parent to child joint
        let boneConnections: [(parent: HandSkeleton.JointName, child: HandSkeleton.JointName)] = [
            // Thumb
            (.thumbKnuckle, .thumbIntermediateBase),
            (.thumbIntermediateBase, .thumbIntermediateTip),
            (.thumbIntermediateTip, .thumbTip),

            // Index finger
            (.indexFingerMetacarpal, .indexFingerKnuckle),
            (.indexFingerKnuckle, .indexFingerIntermediateBase),
            (.indexFingerIntermediateBase, .indexFingerIntermediateTip),
            (.indexFingerIntermediateTip, .indexFingerTip),

            // Middle finger
            (.middleFingerMetacarpal, .middleFingerKnuckle),
            (.middleFingerKnuckle, .middleFingerIntermediateBase),
            (.middleFingerIntermediateBase, .middleFingerIntermediateTip),
            (.middleFingerIntermediateTip, .middleFingerTip),

            // Ring finger
            (.ringFingerMetacarpal, .ringFingerKnuckle),
            (.ringFingerKnuckle, .ringFingerIntermediateBase),
            (.ringFingerIntermediateBase, .ringFingerIntermediateTip),
            (.ringFingerIntermediateTip, .ringFingerTip),

            // Little finger
            (.littleFingerMetacarpal, .littleFingerKnuckle),
            (.littleFingerKnuckle, .littleFingerIntermediateBase),
            (.littleFingerIntermediateBase, .littleFingerIntermediateTip),
            (.littleFingerIntermediateTip, .littleFingerTip)
        ]

        for (parentJoint, childJoint) in boneConnections {
            guard let parentEntity = handComponent.fingers[parentJoint],
                  let childEntity = handComponent.fingers[childJoint],
                  let handEntity = parentEntity.parent else {
                continue
            }

            // Create a cylinder to represent the bone
            let boneMaterial = UnlitMaterial(color: .white)
            let boneModel = ModelEntity(
                mesh: .generateCylinder(height: 1.0, radius: 0.002),
                materials: [boneMaterial]
            )
            boneModel.name = "\(handComponent.chirality)_BONE_\(parentJoint)_TO_\(childJoint)"

            // Add collision to the bone
            boneModel.components[CollisionComponent.self] = CollisionComponent(
                shapes: [.generateBox(width: 0.004, height: 1.0, depth: 0.004)],
                mode: .default
            )

            // Add physics to the bone
            var physics = PhysicsBodyComponent(
                massProperties: .init(mass: 0.02), // Slightly heavier than joints
                material: .generate(staticFriction: 0.5, dynamicFriction: 0.4, restitution: 0.1),
                mode: .kinematic // Kinematic so they follow hand tracking
            )
            physics.isAffectedByGravity = false
            boneModel.components[PhysicsBodyComponent.self] = physics

            // Create a holder entity to manage the bone's transform
            let holder = Entity()
            holder.name = "\(handComponent.chirality)_BONE_HOLDER_\(parentJoint)_TO_\(childJoint)"
            handEntity.addChild(holder)

            // Calculate the direction and distance between joints in world space
            let parentWorldPos = parentEntity.position(relativeTo: nil)
            let childWorldPos = childEntity.position(relativeTo: nil)
            let worldDirection = childWorldPos - parentWorldPos
            let distance = simd_length(worldDirection)

            // Position the holder at the parent joint in world space
            holder.position = parentWorldPos

            // Orient the holder to point from parent to child joint
            holder.look(at: childWorldPos, from: parentWorldPos, relativeTo: nil)

            // Configure the bone cylinder
            boneModel.transform = Transform(
                scale: [1, distance, 1],
                rotation: simd_quatf(angle: .pi / 2, axis: [1, 0, 0]),
                translation: [0, 0, -distance * 0.5]
            )

            holder.addChild(boneModel)
            handComponent.bones[childJoint] = boneModel
        }
    }

    // ----------------------------------------------------------------
    // App Model Update & Object Display
    // ----------------------------------------------------------------

    @MainActor
    private func updateAppModel(
        handComponent: HandTrackingComponent,
        shouldShow: Bool,
        position: SIMD3<Float>
    ) {
        // Only update the app model if the pinch is valid (after 1 second)
        if handComponent.isPinchValid {
            if handComponent.chirality == .left {
                AppModel.shared.isPinchingLeftHand = shouldShow
                if shouldShow {
                    AppModel.shared.leftPinchPosition = position
                }
            } else if handComponent.chirality == .right {
                AppModel.shared.isPinchingRightHand = shouldShow
                if shouldShow {
                    AppModel.shared.rightPinchPosition = position
                }
            }
        } else {
            // Reset pinch state if not valid
            if handComponent.chirality == .left {
                AppModel.shared.isPinchingLeftHand = false
            } else if handComponent.chirality == .right {
                AppModel.shared.isPinchingRightHand = false
            }
        }
    }

    // ----------------------------------------------------------------
    // Helper method for updating hand component timing
    // ----------------------------------------------------------------

    private func updateHandComponentTiming(
        handComponent: inout HandTrackingComponent,
        result: FingerRingDetector.HandResult
    ) {
        let currentTime = Date().timeIntervalSince1970

        if result.shouldShowObject && handComponent.pinchStartTime == 0 {
            handComponent.pinchStartTime = currentTime
        } else if !result.shouldShowObject {
            handComponent.pinchStartTime = 0
        }

        // 有効性の更新
        let pinchDuration = handComponent.pinchStartTime > 0 ? currentTime - handComponent.pinchStartTime : 0
        handComponent.isPinchValid = pinchDuration >= 0.25
    }
}
