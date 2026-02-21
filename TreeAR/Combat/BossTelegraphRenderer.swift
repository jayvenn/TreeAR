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
        let node: SCNNode

        switch attack {
        case .groundSlam:
            node = makeRuneCircle(radius: attack.threatRadius, color: Self.dangerColor)
        case .sweep:
            node = makeArcTelegraph(radius: attack.threatRadius, color: Self.warnColor)
        case .stompWave:
            node = makeExpandingRings(radius: attack.threatRadius, color: Self.dangerColor)
        case .enragedCombo:
            node = makeRuneCircle(radius: attack.threatRadius, color: Self.dangerColor)
            let arc = makeArcTelegraph(radius: attack.threatRadius, color: Self.warnColor)
            node.addChildNode(arc)
        }

        node.opacity = 0
        node.position = SCNVector3(0, 0.005, 0)
        node.scale = SCNVector3(0.05, 0.05, 0.05)
        parent.addChildNode(node)
        activeTelegraphs.append(node)

        let expand = SCNAction.scale(to: 1.0, duration: duration * 0.75)
        expand.timingMode = .easeOut
        let fadeIn = SCNAction.fadeOpacity(to: 0.7, duration: duration * 0.25)

        let pulse = SCNAction.repeatForever(.sequence([
            .fadeOpacity(to: 0.9, duration: 0.2),
            .fadeOpacity(to: 0.5, duration: 0.2)
        ]))

        let spin = SCNAction.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 4.0))

        node.runAction(.group([expand, fadeIn]))
        node.runAction(pulse, forKey: "pulse")
        node.runAction(spin, forKey: "spin")
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

    private func makeRuneCircle(radius: Float, color: UIColor) -> SCNNode {
        let container = SCNNode()
        container.name = "telegraph_rune"

        let outerRing = SCNTorus(ringRadius: CGFloat(radius), pipeRadius: 0.025)
        outerRing.firstMaterial = makeGlowMaterial(color)
        container.addChildNode(SCNNode(geometry: outerRing))

        let innerRing = SCNTorus(ringRadius: CGFloat(radius) * 0.7, pipeRadius: 0.015)
        innerRing.firstMaterial = makeGlowMaterial(color.withAlphaComponent(0.6))
        container.addChildNode(SCNNode(geometry: innerRing))

        let fill = SCNCylinder(radius: CGFloat(radius), height: 0.002)
        fill.radialSegmentCount = 48
        fill.firstMaterial = makeGlowMaterial(color.withAlphaComponent(0.12))
        container.addChildNode(SCNNode(geometry: fill))

        let runeCount = 8
        for i in 0..<runeCount {
            let angle = Float(i) / Float(runeCount) * .pi * 2
            let r = radius * 0.85
            let mark = SCNNode(geometry: SCNBox(width: 0.04, height: 0.002, length: 0.12, chamferRadius: 0.005))
            mark.geometry?.firstMaterial = makeGlowMaterial(color)
            mark.position = SCNVector3(cos(angle) * r, 0, sin(angle) * r)
            mark.eulerAngles.y = -angle + .pi / 2
            container.addChildNode(mark)
        }

        for i in 0..<4 {
            let angle = Float(i) / 4.0 * .pi * 2
            let line = SCNNode(geometry: SCNBox(width: 0.015, height: 0.002, length: CGFloat(radius) * 2, chamferRadius: 0))
            line.geometry?.firstMaterial = makeGlowMaterial(color.withAlphaComponent(0.25))
            line.eulerAngles.y = angle
            container.addChildNode(line)
        }

        return container
    }

    private func makeArcTelegraph(radius: Float, color: UIColor) -> SCNNode {
        let path = UIBezierPath()
        let r = CGFloat(radius)
        path.move(to: .zero)
        path.addArc(withCenter: .zero, radius: r,
                     startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
        path.close()

        let shape = SCNShape(path: path, extrusionDepth: 0.003)
        shape.firstMaterial = makeGlowMaterial(color.withAlphaComponent(0.2))

        let node = SCNNode(geometry: shape)
        node.name = "telegraph_arc"
        node.eulerAngles.x = -.pi / 2
        return node
    }

    private func makeExpandingRings(radius: Float, color: UIColor) -> SCNNode {
        let container = SCNNode()
        container.name = "telegraph_rings"

        for i in 0..<4 {
            let r = CGFloat(radius) * CGFloat(i + 1) / 4.0
            let torus = SCNTorus(ringRadius: r, pipeRadius: 0.018)
            torus.firstMaterial = makeGlowMaterial(color.withAlphaComponent(0.5))
            container.addChildNode(SCNNode(geometry: torus))
        }
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
