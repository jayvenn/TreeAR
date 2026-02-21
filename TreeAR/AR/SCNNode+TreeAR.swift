//
//  SCNNode+TreeAR.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SceneKit

extension SCNNode {
    
    static var hole1: SCNNode {
        loadNode(from: "hole1.scn", nodeName: "hole1")
    }
    
    static var hole2: SCNNode {
        loadNode(from: "hole2.scn", nodeName: "hole2")
    }
    
    static var hole3: SCNNode {
        loadNode(from: "hole3.scn", nodeName: "hole3")
    }
    
    static var flatHole: SCNNode {
        loadNode(from: "flatHole.scn", nodeName: "flatHole")
    }
    
    static var seed: SCNNode {
        loadNode(from: "seed.scn", nodeName: "seed")
    }
    
    static var holeAndLeaf1: SCNNode {
        loadNode(from: "holeAndLeaf1.scn", nodeName: "holeAndLeaf1")
    }
    
    static var holeAndLeaf2: SCNNode {
        loadNode(from: "holeAndLeaf2.scn", nodeName: "holeAndLeaf2")
    }
    
    static var holeAndLeaf3: SCNNode {
        loadNode(from: "holeAndLeaf3.scn", nodeName: "holeAndLeaf3")
    }
    
    static var cloud: SCNNode {
        loadNode(from: "cloud.scn", nodeName: "cloud")
    }
    
    static var tree: SCNNode {
        guard let scene = SCNScene(named: "simpleTree.scn"),
              let node = scene.rootNode.childNode(withName: "simpleTree", recursively: true)
        else {
            let sphere = SCNSphere(radius: 0.2)
            sphere.firstMaterial?.diffuse.contents = UIColor.green
            let fallback = SCNNode(geometry: sphere)
            fallback.name = "simpleTree"
            fallback.scale = SCNVector3(scaleFactorAlternative, scaleFactorAlternative, scaleFactorAlternative)
            fallback.eulerAngles = SCNVector3().defaultEulerAngles
            return fallback
        }
        node.scale = SCNVector3(scaleFactorAlternative, scaleFactorAlternative, scaleFactorAlternative)
        node.eulerAngles = SCNVector3().defaultEulerAngles
        return node
    }
    
    static var apples: SCNNode {
        guard let scene = SCNScene(named: "applesSizeVariation.scn") else {
            return fallbackApplesNode()
        }
        let node = scene.childNodesNode()
        node.scale = SCNVector3(scaleFactorAlternative, scaleFactorAlternative, scaleFactorAlternative)
        node.eulerAngles = SCNVector3().defaultEulerAngles
        return node
    }
    
    static var floorPlane: SCNNode {
        let length: CGFloat = 3
        let plane = SCNPlane(width: length, height: length)
        plane.materials.first?.diffuse.contents = UIColor.clear
        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -.pi / 2
        return node
    }
    
    private static func loadNode(from sceneName: String, nodeName: String) -> SCNNode {
        guard let scene = SCNScene(named: sceneName),
              let node = scene.rootNode.childNode(withName: nodeName, recursively: true)
        else {
            return fallbackPlaceholderNode(name: nodeName)
        }
        node.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
        node.position.y = Float(-2 * scaleFactor)
        node.eulerAngles = SCNVector3().defaultEulerAngles
        return node
    }
    
    private static func fallbackPlaceholderNode(name: String) -> SCNNode {
        let sphere = SCNSphere(radius: 0.05)
        sphere.firstMaterial?.diffuse.contents = UIColor.brown
        let node = SCNNode(geometry: sphere)
        node.name = name
        node.scale = SCNVector3(scaleFactor, scaleFactor, scaleFactor)
        node.position.y = Float(-2 * scaleFactor)
        node.eulerAngles = SCNVector3().defaultEulerAngles
        return node
    }
    
    private static func fallbackApplesNode() -> SCNNode {
        let node = SCNNode()
        let sphere = SCNSphere(radius: 0.1)
        sphere.firstMaterial?.diffuse.contents = UIColor.red
        let appleNode = SCNNode(geometry: sphere)
        appleNode.name = "apple1"
        node.addChildNode(appleNode)
        node.scale = SCNVector3(scaleFactorAlternative, scaleFactorAlternative, scaleFactorAlternative)
        node.eulerAngles = SCNVector3().defaultEulerAngles
        return node
    }
}

extension SCNVector3 {
    var defaultEulerAngles: SCNVector3 {
        SCNVector3(eulerXAngle, eulerYAngle, eulerZAngle)
    }
}
