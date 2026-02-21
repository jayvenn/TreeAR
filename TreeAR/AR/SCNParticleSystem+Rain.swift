//
//  SCNParticleSystem+Rain.swift
//  TreeAR
//
//  Rain particle system for AR experience.
//

import SceneKit

extension SCNParticleSystem {
    static var rain: SCNParticleSystem {
        if let particleSystem = SCNParticleSystem(named: "rainParticleSystem", inDirectory: nil) {
            particleSystem.particleDiesOnCollision = true
            return particleSystem
        }
        return createFallbackRainParticleSystem()
    }
    
    private static func createFallbackRainParticleSystem() -> SCNParticleSystem {
        let system = SCNParticleSystem()
        system.particleColor = .white
        system.particleSize = 0.02
        system.particleLifeSpan = 2
        system.birthRate = 500
        system.emitterShape = SCNBox(width: 2, height: 0.1, length: 2, chamferRadius: 0)
        system.particleVelocity = -5
        system.particleVelocityVariation = 1
        system.particleDiesOnCollision = true
        system.particleColorVariation = SCNVector4(0, 0, 0, 0.5)
        return system
    }
}
