//
//  BossTelegraphRenderer.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SceneKit

/// Floor-level telegraph indicators with glowing rune aesthetics.
///
/// All nodes are added as children of the boss root so they inherit its world
/// transform. Telegraphs sit at Y ≈ 0 relative to the ground plane.
final class BossTelegraphRenderer {

    private weak var parentNode: SCNNode?
    private var activeTelegraphs: [SCNNode] = []

    private static let dangerColor = UIColor(red: 1.0, green: 0.2, blue: 0.05, alpha: 1)
    private static let warnColor   = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1)

    func configure(parentNode: SCNNode) {
        self.parentNode = parentNode
    }

    // MARK: - Show

    func showTelegraph(for attack: BossAttack, duration: TimeInterval) {
        guard let parent = parentNode else { return }
        let color = attack == .sweep ? Self.warnColor : Self.dangerColor
        let node = makeDangerZone(radius: attack.threatRadius, color: color)

        node.opacity = 0
        node.position = SCNVector3(0, 0.005, 0)
        node.scale = SCNVector3(0.1, 0.1, 0.1)
        parent.addChildNode(node)
        activeTelegraphs.append(node)

        let expand = SCNAction.scale(to: 1.0, duration: duration * 0.8)
        expand.timingMode = .easeOut
        let fadeIn = SCNAction.fadeOpacity(to: 0.6, duration: duration * 0.3)

        let pulse = SCNAction.repeatForever(.sequence([
            .fadeOpacity(to: 0.7, duration: 0.25),
            .fadeOpacity(to: 0.4, duration: 0.25)
        ]))

        node.runAction(.group([expand, fadeIn]))
        node.runAction(pulse, forKey: "pulse")
    }

    func flashAndRemoveTelegraphs() {
        for node in activeTelegraphs {
            node.removeAction(forKey: "pulse")
            node.removeAction(forKey: "spin")
            let flash = SCNAction.sequence([
                .fadeOpacity(to: 1.0, duration: 0.06),
                .group([
                    .fadeOpacity(to: 0.0, duration: 0.2),
                    .scale(to: 1.15, duration: 0.2)
                ]),
                .removeFromParentNode()
            ])
            node.runAction(flash)
        }
        activeTelegraphs.removeAll()
    }

    func removeAllTelegraphs() {
        activeTelegraphs.forEach { $0.removeFromParentNode() }
        activeTelegraphs.removeAll()
    }

    // MARK: - Factory

    private func makeDangerZone(radius: Float, color: UIColor) -> SCNNode {
        let container = SCNNode()
        container.name = "telegraph"

        let ring = SCNTorus(ringRadius: CGFloat(radius), pipeRadius: 0.02)
        ring.firstMaterial = makeGlowMaterial(color)
        container.addChildNode(SCNNode(geometry: ring))

        let fill = SCNCylinder(radius: CGFloat(radius), height: 0.002)
        fill.radialSegmentCount = 36
        fill.firstMaterial = makeGlowMaterial(color.withAlphaComponent(0.08))
        container.addChildNode(SCNNode(geometry: fill))

        return container
    }

    private func makeGlowMaterial(_ color: UIColor) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.emission.intensity = 1.5
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        mat.writesToDepthBuffer = false
        mat.readsFromDepthBuffer = true
        return mat
    }
}
