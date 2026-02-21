//
//  SCNNode+MagicalBox.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SceneKit

extension SCNNode {

    static var grass: SCNNode {
        guard let scene = SCNScene(named: "grass.scn"),
              let node = scene.rootNode.childNode(withName: "main", recursively: true)
        else { return SCNNode() }
        node.opacity = 0
        let s: Float = 3.5
        node.scale = SCNVector3(node.scale.x * s, node.scale.y * s, node.scale.z * s)
        return node
    }

    static var lights: SCNNode {
        guard let scene = SCNScene(named: "lights.scn"),
              let node = scene.rootNode.childNode(withName: "main", recursively: true)
        else { return SCNNode() }
        return node
    }
}
