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
}
