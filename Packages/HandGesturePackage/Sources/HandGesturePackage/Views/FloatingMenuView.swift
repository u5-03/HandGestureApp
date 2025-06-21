//
//  FloatingMenuView.swift
//  HandGesturePackage
//
//  Created by yugo.sugiyama on 2025/06/05.
//

import SwiftUI

/// ImmersiveView内で表示されるフローティングメニュー
public struct FloatingMenuView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            // ジェスチャー情報表示
            gestureInfoPanel
            
            // 終了ボタン
            Button(action: {
                Task {
                    await exitImmersiveExperience()
                }
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("体験を終了")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.red, in: RoundedRectangle(cornerRadius: 10))
            }
            .disabled(appModel.immersiveSpaceState == .inTransition)
        }
        .padding()
        .frame(maxWidth: 350)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }
    
    @ViewBuilder
    private var gestureInfoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hand Gesture Status")
                .font(.headline)
                .fontWeight(.bold)

            // ピンチ状態表示
            HStack {
                Circle()
                    .fill(appModel.isPinchingLeftHand ? .green : .gray)
                    .frame(width: 12, height: 12)
                Text("Left Hand Pinch")
                    .font(.caption)

                Spacer()

                Circle()
                    .fill(appModel.isPinchingRightHand ? .green : .gray)
                    .frame(width: 12, height: 12)
                Text("Right Hand Pinch")
                    .font(.caption)
            }

            // 両手ジェスチャー表示
            if !appModel.currentTwoHandGestures.isEmpty {
                Text("Two-Hand Gestures:")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(appModel.currentTwoHandGestures, id: \.self) { gesture in
                    Text("• \(gestureDisplayName(for: gesture))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                Text("No gestures detected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    @MainActor
    private func exitImmersiveExperience() async {
        appModel.updateImmersiveSpaceState(.inTransition)
        await dismissImmersiveSpace()
        // ImmersiveViewのonDisappearで.closedに設定される
    }
    
    private func gestureDisplayName(for gesture: TwoHandGestureType) -> String {
        switch gesture {
        case .palmsTogetherRightAngleArmsHorizontal:
            return "Palms Together (Prayer)"
        case .rightFistAboveLeftOpenHand:
            return "Right Fist Above Left Open Hand"
        case .fingersBent90Degrees:
            return "Fingers Bent 90 Degrees"
        case .rightArmVerticalLeftArmHorizontalFingertipsTouch:
            return "T-Shape with Fingertips Touch"
        }
    }
}

#Preview {
    FloatingMenuView()
        .environment(AppModel.shared)
} 
