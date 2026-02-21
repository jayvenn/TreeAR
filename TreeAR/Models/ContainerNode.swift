//
//  ContainerNode.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import ARKit

enum stackContainerBoxNodeName: String {
    case leftSquare = "leftSquare"
    case rightSquare = "rightSquare"
    case topRectangle = "topRectangle"
    case bottomRectangle = "bottomRectangle"
    case leftRectangle = "leftRectangle"
    case rightRectangle = "rightRectangle"
}

final class ContainerBoxNode: BaseNode {

    private let fadeInAction: SCNAction = {
        SCNAction.sequence([SCNAction.fadeIn(duration: fadeInAnimationDuration)])
    }()

    // Square
    private lazy var squareLength: CGFloat = cubeLength + 0.05
    private lazy var squarePlane: SCNPlane = {
        let plane = SCNPlane(width: squareLength, height: squareLength)
        plane.firstMaterial?.isDoubleSided = true
        return plane
    }()

    private var halfTrackerNodeLength: Float {
        Float(trackerNodeLength / 2)
    }

    private lazy var rightSquareNode = SCNNode(geometry: squarePlane)
    private lazy var leftSquareNode  = SCNNode(geometry: squarePlane)

    private lazy var openLeftDoorAction: SCNAction = {
        let horizontalDistance: CGFloat = 0.05
        let action = SCNAction.sequence([
            SCNAction.moveBy(x: -horizontalDistance, y: 0, z: 0, duration: animationDuration),
            SCNAction.moveBy(x: 0, y: squareLength,  z: 0, duration: animationDuration),
            SCNAction.moveBy(x:  horizontalDistance, y: 0, z: 0, duration: animationDuration)
        ])
        action.timingMode = .easeInEaseOut
        return action
    }()

    private lazy var openRightDoorAction: SCNAction = {
        let horizontalDistance: CGFloat = 0.05
        let action = SCNAction.sequence([
            SCNAction.moveBy(x:  horizontalDistance, y: 0, z: 0, duration: animationDuration),
            SCNAction.moveBy(x: 0, y: squareLength,  z: 0, duration: animationDuration),
            SCNAction.moveBy(x: -horizontalDistance, y: 0, z: 0, duration: animationDuration)
        ])
        action.timingMode = .easeInEaseOut
        return action
    }()

    private var leftDoorOpen  = false
    private var rightDoorOpen = false

    var cubeNodes = [CubeNode]() {
        didSet {
            for (index, node) in cubeNodes.enumerated() {
                setActionFor(node: node, index: index)
            }
        }
    }

    private var index: Int = 0

    lazy var rectanglePlane: SCNPlane = {
        let plane = SCNPlane(width: squareLength, height: trackerNodeLength)
        plane.firstMaterial?.isDoubleSided = true
        return plane
    }()

    override init(cubeLength: CGFloat, cubeSpacing: CGFloat, trackerNodeLength: CGFloat, lesson: Lesson) {
        super.init(cubeLength: cubeLength, cubeSpacing: cubeSpacing,
                   trackerNodeLength: trackerNodeLength, lesson: lesson)
        opacity = 0
        position = SCNVector3(0, 3.6, 0)
        generateNode()
        name = "containerNode"
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func generateNode() {
        generateLeftSquareNode()
        generateRightSquareNode()
        generateRectangleNodes()
    }

    private func setIndex(increment: Bool, completion: @escaping () -> Void) {
        switch increment {
        case true:
            guard index < cubeNodes.count else { return }
            let cubeNode = cubeNodes[index]
            openSideDoors {
                cubeNode.runAction(cubeNode.action) { completion() }
            }
            index += 1
        case false:
            guard index > 0 else { return }
            index -= 1
            let theIndex: Int
            let action: SCNAction
            switch lesson.name {
            case .stack:
                theIndex = index
            case .queue:
                theIndex = cubeNodes.count - 1 - index
            default:
                return
            }
            let cubeNode = cubeNodes[theIndex]
            action = lesson.name == .stack ? cubeNode.reversedAction : cubeNode.getPopQueueAction()
            cubeNode.runAction(action) {
                if self.lesson.name == .stack {
                    guard theIndex == 0 else { return completion() }
                    self.closeSideDoors(index: theIndex) { completion() }
                } else {
                    guard theIndex == self.cubeNodes.count - 1 else { return completion() }
                    self.closeSideDoors(index: theIndex) { completion() }
                }
            }
        }
    }
}

// MARK: - Action
extension ContainerBoxNode {
    func runFadeInAction(completion: @escaping () -> Void) {
        runAction(fadeInAction) { completion() }
    }

    func runAssembleSquareAction(completion: @escaping () -> Void) {
        let duration = TimeInterval(1)
        let leftAction  = SCNAction.moveBy(x:  CGFloat(cubeLength), y: 0, z: 0, duration: duration)
        let rightAction = SCNAction.moveBy(x: -CGFloat(cubeLength), y: 0, z: 0, duration: duration)
        leftSquareNode.runAction(leftAction)
        rightSquareNode.runAction(rightAction) { completion() }
    }
}

// MARK: - Generate node
extension ContainerBoxNode {
    func generateRightSquareNode() {
        rightSquareNode.eulerAngles = SCNVector3(0, 90 * degreesToRadians, 0)
        rightSquareNode.position.x = halfTrackerNodeLength + Float(cubeLength)
        rightSquareNode.name = stackContainerBoxNodeName.rightSquare.rawValue
        addChildNode(rightSquareNode)
    }

    func generateLeftSquareNode() {
        leftSquareNode.eulerAngles = SCNVector3(0, 90 * degreesToRadians, 0)
        leftSquareNode.position.x = -halfTrackerNodeLength - Float(cubeLength)
        leftSquareNode.name = stackContainerBoxNodeName.leftSquare.rawValue
        addChildNode(leftSquareNode)
    }

    func generateRectangleNodes() {
        let degrees = Float(90 * degreesToRadians)
        var nodes = [SCNNode]()

        let top = SCNNode(geometry: rectanglePlane)
        top.position.y     = Float(squarePlane.height / 2)
        top.eulerAngles.x  = degrees
        top.eulerAngles.y  = degrees
        top.opacity        = 0.2
        top.name           = stackContainerBoxNodeName.topRectangle.rawValue
        nodes.append(top)

        let bottom = SCNNode(geometry: rectanglePlane)
        bottom.position.y    = -Float(squarePlane.height / 2)
        bottom.eulerAngles.x = degrees
        bottom.eulerAngles.y = degrees
        bottom.opacity       = 0.2
        bottom.name          = stackContainerBoxNodeName.bottomRectangle.rawValue
        nodes.append(bottom)

        let left = SCNNode(geometry: rectanglePlane)
        left.position.z    = Float(squarePlane.height / 2)
        left.eulerAngles.z = degrees
        left.opacity       = 0.2
        left.name          = stackContainerBoxNodeName.leftRectangle.rawValue
        nodes.append(left)

        let right = SCNNode(geometry: rectanglePlane)
        right.position.z    = -Float(squarePlane.height / 2)
        right.eulerAngles.z = degrees
        right.opacity       = 0.2
        right.name          = stackContainerBoxNodeName.rightRectangle.rawValue
        nodes.append(right)

        nodes.forEach { addChildNode($0) }
    }

    func pushCubeNode(completion: @escaping () -> Void) {
        setIndex(increment: true) { completion() }
    }

    func pushCubeNodes() {
        guard index != cubeNodes.count else { return popCubeNodes() }
        pushCubeNode { self.pushCubeNodes() }
    }

    func popCubeNode(completion: @escaping () -> Void) {
        setIndex(increment: false) { completion() }
    }

    func popCubeNodes() {
        guard index >= 0 else { return }
        popCubeNode { self.popCubeNodes() }
    }

    func openSideDoors(completion: @escaping () -> Void) {
        guard index == 0 else { return completion() }
        switch lesson.name {
        case .stack:
            openLeftDoor { completion() }
        case .queue:
            openLeftDoor { completion() }
            openRightDoor { }
        default:
            break
        }
    }

    func closeSideDoors(index: Int, completion: @escaping () -> Void) {
        switch lesson.name {
        case .stack:
            closeLeftDoor { completion() }
        case .queue:
            closeLeftDoor { completion() }
            closeRightDoor { }
        default:
            break
        }
    }

    func openLeftDoor(completion: @escaping () -> Void) {
        leftSquareNode.runAction(openLeftDoorAction) {
            self.leftDoorOpen = true
            completion()
        }
    }

    func openRightDoor(completion: @escaping () -> Void) {
        rightSquareNode.runAction(openRightDoorAction) {
            self.rightDoorOpen = true
            completion()
        }
    }

    func closeLeftDoor(completion: @escaping () -> Void) {
        leftSquareNode.runAction(openLeftDoorAction.reversed()) {
            self.leftDoorOpen = false
            completion()
        }
    }

    func closeRightDoor(completion: @escaping () -> Void) {
        rightSquareNode.runAction(openRightDoorAction.reversed()) {
            self.rightDoorOpen = false
            completion()
        }
    }

    private func setActionFor(node: CubeNode, index: Int) {
        let originalPosition = node.position
        var position = node.position
        position.x -= (Float(cubeSpacing + cubeLength) * Float(index + 1))
        var secondPosition = position
        secondPosition.y = self.position.y
        var finalPosition = secondPosition
        finalPosition.x += (Float(self.cubeSpacing + self.cubeLength) * Float(cubeNodes.count - index))

        let action = SCNAction.sequence([
            SCNAction.move(to: position,       duration: animationDuration),
            SCNAction.wait(duration: animationDuration),
            SCNAction.move(to: secondPosition, duration: animationDuration),
            SCNAction.move(to: finalPosition,  duration: animationDuration)
        ])
        action.timingMode = .easeInEaseOut

        let reversedAction: SCNAction
        switch lesson.name {
        case .stack:
            reversedAction = SCNAction.sequence([
                SCNAction.move(to: finalPosition,    duration: animationDuration),
                SCNAction.move(to: secondPosition,   duration: animationDuration),
                SCNAction.wait(duration: animationDuration),
                SCNAction.move(to: position,         duration: animationDuration),
                SCNAction.move(to: originalPosition, duration: animationDuration)
            ])
        case .queue:
            reversedAction = node.getPopQueueAction()
        default:
            reversedAction = SCNAction()
        }
        reversedAction.timingMode = .easeInEaseOut

        node.action = action
        node.reversedAction = reversedAction
    }
}
