//
//  PortalNode.swift
//  Filter-Portal
//
//  Created by Kristina Gelzinyte on 1/18/18.
//  Copyright © 2018 Kristina Gelzinyte. All rights reserved.
//

import UIKit
import SceneKit

class PortalNode: SCNNode {
    
    public static func setup(with size: CGSize) -> PortalNode {
        
        let portalPlane = SCNPlane(width: size.width, height: size.height)
        let material = SCNMaterial()
        material.transparency = 0.0
        material.isDoubleSided = true
        portalPlane.materials = [material]
        
        let portal = PortalNode()
        portal.geometry = portalPlane
        portal.name = "portal"
        
        return portal
    }
    
    public func updatePosition(to position: SCNVector3, with orientation: SCNQuaternion) {
        self.position = position
        
        // Set plane position to face the camera.
        self.orientation = SCNVector4.init(0.0, orientation.y, 0.0, orientation.w)
    }
    
    public func addFrame(of particles: String, for portalSize: CGSize) {
        let emitter =  SCNParticleSystem.init(named: particles, inDirectory: nil)
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0-portalSize.width/2, y: 0-portalSize.height/2))
        path.addLine(to: CGPoint(x: 0-portalSize.width/2, y: portalSize.height-portalSize.height/2))
        path.addLine(to: CGPoint(x: portalSize.width-portalSize.width/2, y: portalSize.height-portalSize.height/2))
        path.addLine(to: CGPoint(x: portalSize.width-portalSize.width/2, y: 0-portalSize.height/2))
        path.addLine(to: CGPoint(x: 0.01-portalSize.width/2, y: 0-portalSize.height/2))
        path.addLine(to: CGPoint(x: 0.01-portalSize.width/2, y: -0.01-portalSize.height/2))
        path.addLine(to: CGPoint(x: portalSize.width+0.01-portalSize.width/2, y: -0.01-portalSize.height/2))
        path.addLine(to: CGPoint(x: portalSize.width+0.01-portalSize.width/2, y: portalSize.height+0.01-portalSize.height/2))
        path.addLine(to: CGPoint(x: -0.001-portalSize.width/2, y: portalSize.height+0.01-portalSize.height/2))
        path.addLine(to: CGPoint(x: -0.001-portalSize.width/2, y: -0.01-portalSize.height/2))
        path.addLine(to: CGPoint(x: 0-portalSize.width/2, y: -0.01-portalSize.height/2))
        path.close()

        let shape = SCNShape(path: path, extrusionDepth: 0)
        
        guard let particleEmitter = emitter else { return }
        
        particleEmitter.emitterShape = shape
        addParticleSystem(particleEmitter)
    }
}
