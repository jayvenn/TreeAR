//
//  Lesson.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import Foundation

enum LessonName: String {
    case stack = "Stack"
    case queue = "Queue"
    case singlyLinkedList = "Singly-Linked List"
    case doublyLinkedList = "Doubly-Linked List"
    case binaryTree = "Binary Tree"
}

enum Operation: String {
    case push = "push(cube)"
    case pop = "pop()"
    case peek = "peek()"
    case isEmpty = "isEmpty()"

    case enqueue = "enqueue(cube)"
    case dequeue = "dequeue()"

    case append = "append(cube)"
    case remove = "remove(cube)"
    case nodeAtIndex = "elementAt(index: Int)"
    case removeAll = "removeAll()"

    case insertAfter = "insert(after: cube)"
    case removeLast = "removeLast()"
    case removeAfter = "remove(after: cube)"

    case find = "find(cube)"
    case addChild = "add(child: cube)"
    case removeChild = "remove(child: cube)"

    case comingSoon = "Coming Soon\nTap to Contribute"
}

struct Lesson {
    let name: LessonName

    lazy var operations: [Operation] = {
        switch name {
        case .stack:
            return [.push, .pop]
        case .queue:
            return [.enqueue, .dequeue]
        case .singlyLinkedList, .doublyLinkedList:
            return [.comingSoon, .comingSoon]
        case .binaryTree:
            return [.comingSoon, .comingSoon]
        }
    }()

    init(lessonName: LessonName) {
        self.name = lessonName
    }
}
