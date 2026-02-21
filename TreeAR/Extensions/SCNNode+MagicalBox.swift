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
        return node
    }

    static var magicBox: SCNNode {
        guard let scene = SCNScene(named: "magical_box.scn"),
              let node = scene.rootNode.childNode(withName: "magical_box", recursively: true)
        else { return SCNNode() }
        node.opacity = 0
        return node
    }

    static var lights: SCNNode {
        guard let scene = SCNScene(named: "lights.scn"),
              let node = scene.rootNode.childNode(withName: "main", recursively: true)
        else { return SCNNode() }
        return node
    }

    func runFadeInAction(completion: @escaping () -> Void) {
        runAction(SCNAction.sequence([SCNAction.fadeIn(duration: animationDuration)])) {
            completion()
        }
    }
}

extension SCNVector3 {
    var defaultEulerAngles: SCNVector3 {
        SCNVector3(0, eulerYAngle, 0)
    }
}
