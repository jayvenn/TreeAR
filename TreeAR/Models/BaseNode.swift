//
//  BaseNode.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import ARKit

class BaseNode: SCNNode {

    let lesson: Lesson
    let cubeLength: CGFloat
    let cubeSpacing: CGFloat
    let trackerNodeLength: CGFloat

    init(cubeLength: CGFloat, cubeSpacing: CGFloat, trackerNodeLength: CGFloat, lesson: Lesson) {
        self.cubeLength = cubeLength
        self.cubeSpacing = cubeSpacing
        self.trackerNodeLength = trackerNodeLength
        self.lesson = lesson
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
