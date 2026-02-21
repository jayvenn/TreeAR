//
//  SCNAction+MagicalBox.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SceneKit

extension SCNAction {

    static let fadeInSequenceAction: SCNAction = .sequence([
        .fadeOpacity(to: 1, duration: 2),
        .wait(duration: 2)
    ])

    static let fadeOutSequenceAction: SCNAction = .sequence([
        .fadeOpacity(to: 0, duration: 1)
    ])

    static let fadeOutRemoveAction: SCNAction = .sequence([
        .fadeOpacity(to: 0, duration: 1),
        .removeFromParentNode()
    ])

    // MARK: - Grass growing
    static func grassGrowSequenceAction(_ node: SCNNode) -> SCNAction {
        let yScale = CGFloat(node.scale.y)
        return .sequence([
            .scale(to: 0,          duration: 0),
            .fadeIn(duration: 0),
            .scale(to: yScale * 1.25, duration: 2),
            .scale(to: yScale * 1.0,  duration: 1)
        ])
    }

    static let grassesRotation: SCNAction =
        .rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 2.5)

    // MARK: - Grass shrinking
    static func grassShrinkSequenceAction(_ node: SCNNode) -> SCNAction {
        let yScale = CGFloat(node.scale.y)
        return .sequence([
            .scale(to: yScale * 1.2, duration: 0.8),
            .scale(to: yScale * 0.8, duration: 0.5),
            .removeFromParentNode()
        ])
    }

    static func grassShrinkFadeOutSequenceAction() -> SCNAction {
        .fadeOut(duration: 1)
    }

    static let grassReversedRotation: SCNAction =
        .rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 1)
}
