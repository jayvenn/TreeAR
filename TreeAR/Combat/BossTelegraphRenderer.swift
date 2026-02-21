//
//  BossTelegraphRenderer.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SceneKit

/// Creates and animates floor-level telegraph indicators for boss attacks.
///
/// All nodes are added as children of a provided parent node (the boss root)
/// so they inherit the boss's world transform. Telegraphs are placed at Y=0.01
/// (just above the detected plane) regardless of boss model height.
final class BossTelegraphRenderer {

    private weak var parentNode: SCNNode?
    private var activeTelegraphs: [SCNNode] = []

    func configure(parentNode: SCNNode) {
        self.parentNode = parentNode
    }

    // MARK: - Show Telegraph

    func showTelegraph(for attack: BossAttack, duration: TimeInterval) {
        guard let parent = parentNode else { return }
        let node: SCNNode

        switch attack {
        case .groundSlam:
            node = makeCircleTelegraph(radius: attack.threatRadius, color: .systemRed)
        case .sweep:
            node = makeArcTelegraph(radius: attack.threatRadius, color: .systemOrange)
        case .stompWave:
            node = makeRingTelegraph(radius: attack.threatRadius, color: .systemRed)
        case .enragedCombo:
            node = makeCircleTelegraph(radius: attack.threatRadius, color: .systemRed)
            let arc = makeArcTelegraph(radius: attack.threatRadius, color: .systemOrange)
            node.addChildNode(arc)
        }

        node.opacity = 0
        node.position = SCNVector3(0, 0.01, 0)
        parent.addChildNode(node)
        activeTelegraphs.append(node)

        node.scale = SCNVector3(0.1, 0.1, 0.1)
        let scaleUp = SCNAction.scale(to: 1.0, duration: duration * 0.8)
        scaleUp.timingMode = .easeOut
        let fadeIn = SCNAction.fadeOpacity(to: 0.6, duration: duration * 0.3)

        let pulse = SCNAction.sequence([
            .fadeOpacity(to: 0.8, duration: 0.15),
            .fadeOpacity(to: 0.4, duration: 0.15)
        ])
        let pulsing = SCNAction.repeatForever(pulse)

        node.runAction(.group([scaleUp, fadeIn]))
        node.runAction(pulsing, forKey: "pulse")
    }

    /// Flash the telegraph bright then remove it — call at attack execute time.
    func flashAndRemoveTelegraphs() {
        for node in activeTelegraphs {
            node.removeAction(forKey: "pulse")
            let flash = SCNAction.sequence([
                .fadeOpacity(to: 1.0, duration: 0.08),
                .fadeOpacity(to: 0.0, duration: 0.25),
                .removeFromParentNode()
            ])
            node.runAction(flash)
        }
        activeTelegraphs.removeAll()
    }

    func removeAllTelegraphs() {
        for node in activeTelegraphs {
            node.removeFromParentNode()
        }
        activeTelegraphs.removeAll()
    }

    // MARK: - Factory Methods

    private func makeCircleTelegraph(radius: Float, color: UIColor) -> SCNNode {
        let circle = SCNCylinder(radius: CGFloat(radius), height: 0.005)
        circle.radialSegmentCount = 48
        circle.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.3)
        circle.firstMaterial?.isDoubleSided = true
        circle.firstMaterial?.lightingModel = .constant
        circle.firstMaterial?.writesToDepthBuffer = false
        let node = SCNNode(geometry: circle)
        node.name = "telegraph_circle"

        let ring = SCNTorus(ringRadius: CGFloat(radius), pipeRadius: 0.02)
        ring.firstMaterial?.diffuse.contents = color
        ring.firstMaterial?.lightingModel = .constant
        ring.firstMaterial?.writesToDepthBuffer = false
        let ringNode = SCNNode(geometry: ring)
        node.addChildNode(ringNode)

        return node
    }

    private func makeArcTelegraph(radius: Float, color: UIColor) -> SCNNode {
        let path = UIBezierPath()
        let r = CGFloat(radius)
        path.move(to: .zero)
        path.addArc(withCenter: .zero, radius: r,
                     startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
        path.close()

        let shape = SCNShape(path: path, extrusionDepth: 0.005)
        shape.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.25)
        shape.firstMaterial?.isDoubleSided = true
        shape.firstMaterial?.lightingModel = .constant
        shape.firstMaterial?.writesToDepthBuffer = false

        let node = SCNNode(geometry: shape)
        node.name = "telegraph_arc"
        node.eulerAngles.x = -.pi / 2
        return node
    }

    private func makeRingTelegraph(radius: Float, color: UIColor) -> SCNNode {
        let container = SCNNode()
        container.name = "telegraph_ring"

        for i in 0..<3 {
            let ringRadius = CGFloat(radius) * CGFloat(i + 1) / 3.0
            let torus = SCNTorus(ringRadius: ringRadius, pipeRadius: 0.015)
            torus.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.4)
            torus.firstMaterial?.lightingModel = .constant
            torus.firstMaterial?.writesToDepthBuffer = false
            let ringNode = SCNNode(geometry: torus)
            container.addChildNode(ringNode)
        }

        return container
    }
}
