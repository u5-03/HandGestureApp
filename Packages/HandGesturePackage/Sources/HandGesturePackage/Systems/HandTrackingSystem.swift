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

// MARK: - Gesture Definitions

enum HandGestureType: CaseIterable {
    case fist
    case openHand
    case pointIndex
    case custom1
    case custom2
    // Add more gesture types as needed
    
    // Tolerance values for comparing angles and distances
    static let angleTolerance: Float = 15.0 * .pi / 180.0 // 15 degrees in radians
    static let distanceTolerance: Float = 0.02 // 2 cm
    
    /// Returns true if the given joint and palm data satisfy this gesture
    func matches(handGestureData: HandGestureData) -> Bool {
        switch self {
        case .fist:
            // All fingers curled: each fingertip is near its base joint
            for finger in HandSkeleton.JointName.allFingertipJoints {
                let tipPosition = handGestureData.jointWorldPositions[finger] ?? simd_float3.zero
                let basePosition = handGestureData.jointWorldPositions[finger.baseJoint] ?? simd_float3.zero
                if simd_distance(tipPosition, basePosition) > HandGestureType.distanceTolerance {
                    return false
                }
            }
            return true
            
        case .openHand:
            // All fingers extended: each fingertip is sufficiently farther from palm center
            let palmCenter = handGestureData.palmWorldPosition
            for finger in HandSkeleton.JointName.allFingertipJoints {
                let tipPosition = handGestureData.jointWorldPositions[finger] ?? simd_float3.zero
                if simd_distance(tipPosition, palmCenter) < HandGestureType.distanceTolerance * 5 {
                    return false
                }
            }
            return true
            
        case .pointIndex:
            // Index finger extended and others curled
            guard let indexTip = handGestureData.jointWorldPositions[.indexFingerTip],
                  let indexBase = handGestureData.jointWorldPositions[.indexFingerMetacarpal],
                  let middleTip = handGestureData.jointWorldPositions[.middleFingerTip],
                  let middleBase = handGestureData.jointWorldPositions[.middleFingerMetacarpal],
                  let ringTip = handGestureData.jointWorldPositions[.ringFingerTip],
                  let ringBase = handGestureData.jointWorldPositions[.ringFingerMetacarpal] else {
                return false
            }
            // Index extended
            if simd_distance(indexTip, indexBase) < HandGestureType.distanceTolerance * 3 {
                return false
            }
            // Other fingers near base
            if simd_distance(middleTip, middleBase) > HandGestureType.distanceTolerance ||
                simd_distance(ringTip, ringBase) > HandGestureType.distanceTolerance {
                return false
            }
            return true
            
        case .custom1:
            // Example custom: thumb and pinky touching (like "call me" sign)
            guard let thumbTip = handGestureData.jointWorldPositions[.thumbTip],
                  let pinkyTip = handGestureData.jointWorldPositions[.littleFingerTip] else {
                return false
            }
            return simd_distance(thumbTip, pinkyTip) < HandGestureType.distanceTolerance * 2
            
        case .custom2:
            // Example custom: palm facing camera (palm normal within tolerance of camera forward)
            let normal = handGestureData.palmNormal
            let forward = SIMD3<Float>(0, 0, -1)
            let angle = acos(clamp(simd_dot(normal, forward) / (simd_length(normal) * simd_length(forward)), -1, 1))
            return abs(angle) < HandGestureType.angleTolerance
        }
    }
}

// MARK: - Data Holder for Two-Hand Gesture Matching

struct HandGestureData {
    // Left hand joint positions and orientations
    var leftJointWorldPositions: [HandSkeleton.JointName: SIMD3<Float>] = [:]
    var leftPalmWorldPosition: SIMD3<Float> = .zero
    var leftPalmNormal: SIMD3<Float> = .zero
    var leftWristWorldPosition: SIMD3<Float> = .zero
    var leftForearmWorldPosition: SIMD3<Float> = .zero
    
    // Right hand joint positions and orientations
    var rightJointWorldPositions: [HandSkeleton.JointName: SIMD3<Float>] = [:]
    var rightPalmWorldPosition: SIMD3<Float> = .zero
    var rightPalmNormal: SIMD3<Float> = .zero
    var rightWristWorldPosition: SIMD3<Float> = .zero
    var rightForearmWorldPosition: SIMD3<Float> = .zero
}

enum TwoHandGestureType: CaseIterable {
    case palmsTogetherRightAngleArmsHorizontal
    case rightFistAboveLeftOpenHand
    case fingersBent90Degrees
    case rightArmVerticalLeftArmHorizontalFingertipsTouch
    // Add any additional two-hand gestures as needed
    
    func matches(handData: HandGestureData) -> Bool {
        switch self {
        case .palmsTogetherRightAngleArmsHorizontal:
            // 1. Both palms touching, wrists at right angle, forearms horizontal (y-coordinates approximately equal)
            let leftPalm = handData.leftPalmWorldPosition
            let rightPalm = handData.rightPalmWorldPosition
            // Distance between palms nearly zero
            guard simd_distance(leftPalm, rightPalm) < HandGestureType.distanceTolerance else {
                return false
            }
            // Check left wrist to forearm vector is horizontal (y difference small, z difference indicates right angle)
            let leftWristToForearm = handData.leftWristWorldPosition - handData.leftForearmWorldPosition
            // Horizontal means y component ≈ 0
            guard abs(leftWristToForearm.y) < HandGestureType.distanceTolerance else {
                return false
            }
            // Check right wrist is bent at right angle (use joint orientation: wrist normal approximately horizontal)
            let rightPalmNormal = handData.rightPalmNormal
            // A right angle means palm normal is vertical
            let vertical = SIMD3<Float>(0, 1, 0)
            let angleRightWrist = acos(clamp(simd_dot(rightPalmNormal, vertical) / (simd_length(rightPalmNormal) * simd_length(vertical)), -1, 1))
            return abs(angleRightWrist - (.pi / 2)) < HandGestureType.angleTolerance
            
        case .rightFistAboveLeftOpenHand:
            // 2. Right hand formed into fist, left hand fully open, arms horizontal, right fist held above left open hand
            // Check right fist
            if !HandGestureType.fist.matches(handGestureData: .init(
                leftJointWorldPositions: [:],
                leftPalmWorldPosition: .zero,
                leftPalmNormal: .zero,
                leftWristWorldPosition: .zero,
                leftForearmWorldPosition: .zero,
                rightJointWorldPositions: handData.rightJointWorldPositions,
                rightPalmWorldPosition: handData.rightPalmWorldPosition,
                rightPalmNormal: handData.rightPalmNormal,
                rightWristWorldPosition: handData.rightWristWorldPosition,
                rightForearmWorldPosition: handData.rightForearmWorldPosition
            )) {
                return false
            }
            // Check left open hand
            if !HandGestureType.openHand.matches(handGestureData: .init(
                leftJointWorldPositions: handData.leftJointWorldPositions,
                leftPalmWorldPosition: handData.leftPalmWorldPosition,
                leftPalmNormal: handData.leftPalmNormal,
                leftWristWorldPosition: handData.leftWristWorldPosition,
                leftForearmWorldPosition: handData.leftForearmWorldPosition,
                rightJointWorldPositions: [:],
                rightPalmWorldPosition: .zero,
                rightPalmNormal: .zero,
                rightWristWorldPosition: .zero,
                rightForearmWorldPosition: .zero
            )) {
                return false
            }
            // Both forearms horizontal: y positions of wrists ≈ y positions of corresponding forearms
            guard abs(handData.rightWristWorldPosition.y - handData.rightForearmWorldPosition.y) < HandGestureType.distanceTolerance,
                  abs(handData.leftWristWorldPosition.y - handData.leftForearmWorldPosition.y) < HandGestureType.distanceTolerance else {
                return false
            }
            // Check right palm is above left palm (y coordinate higher)
            return handData.rightPalmWorldPosition.y > handData.leftPalmWorldPosition.y
            
        case .fingersBent90Degrees:
            // 3. All finger joints at approximately 90-degree angle relative to palm (check each finger intermediate angle)
            for (jointName, jointPos) in handData.rightJointWorldPositions {
                // Only check intermediate finger joints (e.g., knuckles, intermediate bases)
                if jointName.isIntermediateJoint {
                    let parentJoint = jointName.parentJoint
                    let childJoint = jointName.childJoint
                    guard let parentPos = handData.rightJointWorldPositions[parentJoint],
                          let childPos = handData.rightJointWorldPositions[childJoint] else {
                        continue
                    }
                    let v1 = parentPos - jointPos
                    let v2 = childPos - jointPos
                    let angle = acos(clamp(simd_dot(v1, v2) / (simd_length(v1) * simd_length(v2)), -1, 1))
                    if abs(angle - (.pi / 2)) > HandGestureType.angleTolerance {
                        return false
                    }
                }
            }
            return true
            
        case .rightArmVerticalLeftArmHorizontalFingertipsTouch:
            // 4. Right arm vertical with straight fingers, left arm horizontal with straight fingers, fingertips of both hands touching
            // Check right arm vertical: forearm and wrist vector predominantly vertical
            let rightWristToForearm = handData.rightWristWorldPosition - handData.rightForearmWorldPosition
            guard abs(rightWristToForearm.x) < HandGestureType.distanceTolerance,
                  rightWristToForearm.y > 0,
                  abs(rightWristToForearm.z) < HandGestureType.distanceTolerance else {
                return false
            }
            // Check right open hand (straight fingers)
            if !HandGestureType.openHand.matches(handGestureData: .init(
                leftJointWorldPositions: [:],
                leftPalmWorldPosition: .zero,
                leftPalmNormal: .zero,
                leftWristWorldPosition: .zero,
                leftForearmWorldPosition: .zero,
                rightJointWorldPositions: handData.rightJointWorldPositions,
                rightPalmWorldPosition: handData.rightPalmWorldPosition,
                rightPalmNormal: handData.rightPalmNormal,
                rightWristWorldPosition: handData.rightWristWorldPosition,
                rightForearmWorldPosition: handData.rightForearmWorldPosition
            )) {
                return false
            }
            // Check left arm horizontal: forearm and wrist vector predominantly horizontal
            let leftWristToForearm = handData.leftWristWorldPosition - handData.leftForearmWorldPosition
            guard abs(leftWristToForearm.y) < HandGestureType.distanceTolerance else {
                return false
            }
            // Check left open hand
            if !HandGestureType.openHand.matches(handGestureData: .init(
                leftJointWorldPositions: handData.leftJointWorldPositions,
                leftPalmWorldPosition: handData.leftPalmWorldPosition,
                leftPalmNormal: handData.leftPalmNormal,
                leftWristWorldPosition: handData.leftWristWorldPosition,
                leftForearmWorldPosition: handData.leftForearmWorldPosition,
                rightJointWorldPositions: [:],
                rightPalmWorldPosition: .zero,
                rightPalmNormal: .zero,
                rightWristWorldPosition: .zero,
                rightForearmWorldPosition: .zero
            )) {
                return false
            }
            // Fingertips touching: distance between corresponding fingertips near zero
            for fingertip in HandSkeleton.JointName.allFingertipJoints {
                guard let leftTip = handData.leftJointWorldPositions[fingertip],
                      let rightTip = handData.rightJointWorldPositions[fingertip] else {
                    return false
                }
                if simd_distance(leftTip, rightTip) > HandGestureType.distanceTolerance {
                    return false
                }
            }
            return true
        }
    }
}

// Helper extensions for JointName (for intermediate joints, parent/child)
extension HandSkeleton.JointName {
    static var allIntermediateJoints: [HandSkeleton.JointName] {
        return [
            // Thumb intermediate joints
            .thumbIntermediateBase, .thumbIntermediateTip,
            // Index intermediate joints
            .indexFingerKnuckle, .indexFingerIntermediateBase, .indexFingerIntermediateTip,
            // Middle intermediate joints
            .middleFingerKnuckle, .middleFingerIntermediateBase, .middleFingerIntermediateTip,
            // Ring intermediate joints
            .ringFingerKnuckle, .ringFingerIntermediateBase, .ringFingerIntermediateTip,
            // Little intermediate joints
            .littleFingerKnuckle, .littleFingerIntermediateBase, .littleFingerIntermediateTip
        ]
    }
    
    var isIntermediateJoint: Bool {
        return HandSkeleton.JointName.allIntermediateJoints.contains(self)
    }
    
    var parentJoint: HandSkeleton.JointName {
        switch self {
            // Thumb
        case .thumbIntermediateTip: return .thumbIntermediateBase
        case .thumbIntermediateBase: return .thumbKnuckle
            // Index
        case .indexFingerIntermediateTip: return .indexFingerIntermediateBase
        case .indexFingerIntermediateBase: return .indexFingerKnuckle
        case .indexFingerKnuckle: return .indexFingerMetacarpal
            // Middle
        case .middleFingerIntermediateTip: return .middleFingerIntermediateBase
        case .middleFingerIntermediateBase: return .middleFingerKnuckle
        case .middleFingerKnuckle: return .middleFingerMetacarpal
            // Ring
        case .ringFingerIntermediateTip: return .ringFingerIntermediateBase
        case .ringFingerIntermediateBase: return .ringFingerKnuckle
        case .ringFingerKnuckle: return .ringFingerMetacarpal
            // Little
        case .littleFingerIntermediateTip: return .littleFingerIntermediateBase
        case .littleFingerIntermediateBase: return .littleFingerKnuckle
        case .littleFingerKnuckle: return .littleFingerMetacarpal
        default: return self
        }
    }
    
    var childJoint: HandSkeleton.JointName {
        switch self {
            // Thumb
        case .thumbKnuckle: return .thumbIntermediateBase
        case .thumbIntermediateBase: return .thumbIntermediateTip
        case .thumbIntermediateTip: return .thumbTip
            // Index
        case .indexFingerKnuckle: return .indexFingerIntermediateBase
        case .indexFingerIntermediateBase: return .indexFingerIntermediateTip
        case .indexFingerIntermediateTip: return .indexFingerTip
            // Middle
        case .middleFingerKnuckle: return .middleFingerIntermediateBase
        case .middleFingerIntermediateBase: return .middleFingerIntermediateTip
        case .middleFingerIntermediateTip: return .middleFingerTip
            // Ring
        case .ringFingerKnuckle: return .ringFingerIntermediateBase
        case .ringFingerIntermediateBase: return .ringFingerIntermediateTip
        case .ringFingerIntermediateTip: return .ringFingerTip
            // Little
        case .littleFingerKnuckle: return .littleFingerIntermediateBase
        case .littleFingerIntermediateBase: return .littleFingerIntermediateTip
        case .littleFingerIntermediateTip: return .littleFingerTip
        default: return self
        }
    }
}

/*
 Abstract:
 A system that updates entities that have hand-tracking components.
 */

struct HandTrackingSystem: System {
    static var arSession = ARKitSession()
    static let handTracking = HandTrackingProvider()
    
    static var latestLeftHand: HandAnchor?
    static var latestRightHand: HandAnchor?
    
    init(scene: RealityKit.Scene) {
        Task { await Self.runSession() }
    }
    
    @MainActor
    private static func runSession() async {
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
        let handEntities = context.entities(matching: Self.query, updatingSystemWhen: .rendering)
        
        var leftHandSphere: ModelEntity?
        var rightHandSphere: ModelEntity?
        var leftHandEntity: Entity?
        var rightHandEntity: Entity?
        
        // --- Gather left and right hand data for two-hand gesture analysis ---
        var leftHandGestureJoints: [HandSkeleton.JointName: SIMD3<Float>] = [:]
        var rightHandGestureJoints: [HandSkeleton.JointName: SIMD3<Float>] = [:]
        var leftPalmWorldPosition: SIMD3<Float> = .zero
        var rightPalmWorldPosition: SIMD3<Float> = .zero
        var leftPalmNormal: SIMD3<Float> = .zero
        var rightPalmNormal: SIMD3<Float> = .zero
        var leftWristWorldPosition: SIMD3<Float> = .zero
        var rightWristWorldPosition: SIMD3<Float> = .zero
        var leftForearmWorldPosition: SIMD3<Float> = .zero
        var rightForearmWorldPosition: SIMD3<Float> = .zero
        
        // Used to store matched two-hand gestures
        var matchedTwoHandGestures: [TwoHandGestureType] = []
        
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
                
                // Build gesture data for this hand
                var jointWorldPositions: [HandSkeleton.JointName: SIMD3<Float>] = [:]
                for (jointName, jointEntity) in handComponent.fingers {
                    jointWorldPositions[jointName] = jointEntity.position(relativeTo: nil)
                }
                // Compute palm center as average of base-of-fingers joints
                let palmJoints: [HandSkeleton.JointName] = [.wrist, .indexFingerMetacarpal, .middleFingerMetacarpal, .ringFingerMetacarpal, .littleFingerMetacarpal]
                var palmCenterSum = SIMD3<Float>(repeating: 0)
                for palmJoint in palmJoints {
                    if let pos = jointWorldPositions[palmJoint] {
                        palmCenterSum += pos
                    }
                }
                let palmWorldPosition = palmCenterSum / Float(palmJoints.count)
                // Palm normal: compute using wrist, index base, and middle base
                var palmNormal: SIMD3<Float> = .zero
                var wristWorldPosition: SIMD3<Float> = .zero
                if let wristPos = jointWorldPositions[.wrist],
                   let indexBasePos = jointWorldPositions[.indexFingerMetacarpal],
                   let middleBasePos = jointWorldPositions[.middleFingerMetacarpal] {
                    let v1 = indexBasePos - wristPos
                    let v2 = middleBasePos - wristPos
                    palmNormal = simd_normalize(simd_cross(v1, v2))
                    wristWorldPosition = wristPos
                }
                // Forearm position: use forearmArm joint
                var forearmWorldPosition: SIMD3<Float> = .zero
                if let forearmPos = jointWorldPositions[.forearmArm] {
                    forearmWorldPosition = forearmPos
                }
                
                // Store for two-hand gesture matching
                if handComponent.chirality == .left {
                    leftHandGestureJoints = jointWorldPositions
                    leftPalmWorldPosition = palmWorldPosition
                    leftPalmNormal = palmNormal
                    leftWristWorldPosition = wristWorldPosition
                    leftForearmWorldPosition = forearmWorldPosition
                } else if handComponent.chirality == .right {
                    rightHandGestureJoints = jointWorldPositions
                    rightPalmWorldPosition = palmWorldPosition
                    rightPalmNormal = palmNormal
                    rightWristWorldPosition = wristWorldPosition
                    rightForearmWorldPosition = forearmWorldPosition
                }
                
                // --- Single hand gesture evaluation remains unchanged ---
                var handGestureData: HandGestureData
                if handComponent.chirality == .left {
                    handGestureData = HandGestureData(
                        leftJointWorldPositions: jointWorldPositions,
                        leftPalmWorldPosition: palmWorldPosition,
                        leftPalmNormal: palmNormal,
                        leftWristWorldPosition: wristWorldPosition,
                        leftForearmWorldPosition: forearmWorldPosition,
                        rightJointWorldPositions: [:],
                        rightPalmWorldPosition: .zero,
                        rightPalmNormal: .zero,
                        rightWristWorldPosition: .zero,
                        rightForearmWorldPosition: .zero
                    )
                } else {
                    handGestureData = HandGestureData(
                        leftJointWorldPositions: [:],
                        leftPalmWorldPosition: .zero,
                        leftPalmNormal: .zero,
                        leftWristWorldPosition: .zero,
                        leftForearmWorldPosition: .zero,
                        rightJointWorldPositions: jointWorldPositions,
                        rightPalmWorldPosition: palmWorldPosition,
                        rightPalmNormal: palmNormal,
                        rightWristWorldPosition: wristWorldPosition,
                        rightForearmWorldPosition: forearmWorldPosition
                    )
                }
                // Evaluate gestures for this hand
                var matchedGestures: [HandGestureType] = []
                for gesture in HandGestureType.allCases {
                    if gesture.matches(handGestureData: handGestureData) {
                        matchedGestures.append(gesture)
                    }
                }
                handComponent.currentGestures = matchedGestures
                
                // Thumb & Index pinch logic (separate from gesture detection)
                // Identify pinch location between thumb and index
                let (thumbPos, indexPos) = getThumbAndIndexPositions(handSkeleton: handSkeleton)
                let (thumbWorldPos, indexWorldPos) = getWorldPositions(thumbPos: thumbPos, indexPos: indexPos, handAnchor: handAnchor)
                
                let distance = simd_distance(thumbPos, indexPos)
                let isPinching = distance < 0.03
                
                updateAppModel(handComponent: handComponent, isPinching: isPinching, thumbWorldPos: thumbWorldPos, indexWorldPos: indexWorldPos)
                
                let midpoint = (thumbWorldPos + indexWorldPos) * 0.5
                handlePinchSphere(
                    entity: entity,
                    handComponent: &handComponent,
                    isPinching: isPinching,
                    midpoint: midpoint,
                    leftHandSphere: &leftHandSphere,
                    rightHandSphere: &rightHandSphere,
                    leftHandEntity: &leftHandEntity,
                    rightHandEntity: &rightHandEntity
                )
                
                // Example: print matched gestures
                if !handComponent.currentGestures.isEmpty {
                    print("\(handComponent.chirality) hand matched gestures: \(handComponent.currentGestures)")
                }
            }
            
            // Store updated component
            entity.components.set(handComponent)
        }
        
        // --- Two-hand gesture detection ---
        // Only attempt if both hands are present
        if !leftHandGestureJoints.isEmpty && !rightHandGestureJoints.isEmpty {
            let handData = HandGestureData(
                leftJointWorldPositions: leftHandGestureJoints,
                leftPalmWorldPosition: leftPalmWorldPosition,
                leftPalmNormal: leftPalmNormal,
                leftWristWorldPosition: leftWristWorldPosition,
                leftForearmWorldPosition: leftForearmWorldPosition,
                rightJointWorldPositions: rightHandGestureJoints,
                rightPalmWorldPosition: rightPalmWorldPosition,
                rightPalmNormal: rightPalmNormal,
                rightWristWorldPosition: rightWristWorldPosition,
                rightForearmWorldPosition: rightForearmWorldPosition
            )
            matchedTwoHandGestures = []
            for gesture in TwoHandGestureType.allCases {
                if gesture.matches(handData: handData) {
                    matchedTwoHandGestures.append(gesture)
                }
            }
            if !matchedTwoHandGestures.isEmpty {
                print("Matched two-hand gestures: \(matchedTwoHandGestures)")
            }
            // Optionally, store matchedTwoHandGestures in AppModel or elsewhere if needed
        }
    }
    
    // ----------------------------------------------------------------
    // 1) Create finger joint spheres if we haven't already
    // ----------------------------------------------------------------
    
    private func addJoints(to handEntity: Entity, handComponent: inout HandTrackingComponent) {
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
        // Update each joint's transform in world space
        for (jointName, jointEntity) in handComponent.fingers {
            let anchorFromJointTransform = handSkeleton.joint(jointName).anchorFromJointTransform
            jointEntity.setTransformMatrix(
                handAnchor.originFromAnchorTransform * anchorFromJointTransform,
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
    // Thumb & Index pinch logic
    // ----------------------------------------------------------------
    
    private func getThumbAndIndexPositions(
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
    
    private func getWorldPositions(
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
    
    @MainActor
    private func updateAppModel(
        handComponent: HandTrackingComponent,
        isPinching: Bool,
        thumbWorldPos: SIMD3<Float>,
        indexWorldPos: SIMD3<Float>
    ) {
        // Only update the app model if the pinch is valid (after 1 second)
        if handComponent.isPinchValid {
            if handComponent.chirality == .left {
                AppModel.shared.isPinchingLeftHand = isPinching
                if isPinching {
                    AppModel.shared.leftPinchPosition = (thumbWorldPos + indexWorldPos) * 0.5
                }
            } else if handComponent.chirality == .right {
                AppModel.shared.isPinchingRightHand = isPinching
                if isPinching {
                    AppModel.shared.rightPinchPosition = (thumbWorldPos + indexWorldPos) * 0.5
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
    
    private func handlePinchSphere(
        entity: Entity,
        handComponent: inout HandTrackingComponent,
        isPinching: Bool,
        midpoint: SIMD3<Float>,
        leftHandSphere: inout ModelEntity?,
        rightHandSphere: inout ModelEntity?,
        leftHandEntity: inout Entity?,
        rightHandEntity: inout Entity?
    ) {
        let currentTime = Date().timeIntervalSince1970
        
        if isPinching {
            // If this is the start of a pinch, record the time
            if handComponent.pinchStartTime == 0 {
                handComponent.pinchStartTime = currentTime
            }
            
            // Check if we've been pinching for at least 1 second
            let pinchDuration = currentTime - handComponent.pinchStartTime
            handComponent.isPinchValid = pinchDuration >= 0.25
            
            if handComponent.isPinchValid {
                if handComponent.pinchSphere == nil {
                    // Create a ring (circle with a hole)
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
                    
                    let circle = ModelEntity(
                        mesh: try! MeshResource(extruding: circlePath, extrusionOptions: extrusionOptions),
                        materials: [material]
                    )
                    circle.name = "\(handComponent.chirality)_PINCH_RING"
                    
                    // Add audio component to the circle
                    do {
                        let audioResource = try AudioFileResource.load(
                            named: "SFX_RingLoop",
                            configuration: .init(shouldLoop: true)
                        )
                        
                        var spatialAudio = SpatialAudioComponent()
                        spatialAudio.gain = -10.0 // Lower volume for SFX
                        circle.spatialAudio = spatialAudio
                        circle.playAudio(audioResource)
                    } catch {
                        print("Error loading ring loop audio: \(error.localizedDescription)")
                    }
                    
                    entity.addChild(circle)
                    handComponent.pinchSphere = circle
                }
                
                if let circle = handComponent.pinchSphere {
                    circle.position = midpoint
                    if handComponent.chirality == .left {
                        leftHandSphere = circle
                        leftHandEntity = entity
                    } else {
                        rightHandSphere = circle
                        rightHandEntity = entity
                    }
                }
            }
        } else {
            // Reset pinch timing when not pinching
            handComponent.pinchStartTime = 0
            handComponent.isPinchValid = false
            
            // Remove the ring when not pinching
            if let circle = handComponent.pinchSphere {
                circle.removeFromParent()
                handComponent.pinchSphere = nil
            }
        }
    }
}
