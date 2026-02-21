//
//  float4x4+Extensions.swift
//  TreeAR
//
//  Created by Jayven on Feb 21, 2026.
//

import SceneKit

public extension float4x4 {
    var translation: float3 {
        let t = columns.3
        return float3(t.x, t.y, t.z)
    }
}
