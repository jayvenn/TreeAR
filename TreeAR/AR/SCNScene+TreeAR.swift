//
//  SCNScene+TreeAR.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
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

