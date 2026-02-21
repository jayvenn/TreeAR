//
//  SCNScene+TreeAR.swift
//  TreeAR
//
//  SceneKit scene extensions.
//

import SceneKit

extension SCNScene {
    func childNodesNode() -> SCNNode {
        let node = SCNNode()
        for childNode in rootNode.childNodes {
            node.addChildNode(childNode.clone())
        }
        return node
    }
}

