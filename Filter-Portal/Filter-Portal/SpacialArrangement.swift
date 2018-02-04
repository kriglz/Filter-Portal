//
//  SpacialArrangement.swift
//  Filter-Portal
//
//  Created by Kristina Gelzinyte on 1/18/18.
//  Copyright © 2018 Kristina Gelzinyte. All rights reserved.
//

import ARKit

class Conditions {
    var didEnterPortal: Bool = false
    var isPortalVisible : Bool = false
    var isInFilteredSide: Bool = false
    var isPortalFrameBiggerThanCameras: Bool = false
}

struct SpacialArrangement {
    
    /// Evaluates relative size of portal to visible scene.
    func compare(_ cropShape: UIBezierPath, with sceneFrame: CGRect) -> Bool {
        let sceneFrameRightTopPoint = CGPoint(x: sceneFrame.size.width, y: sceneFrame.origin.y)
        let sceneFrameRightBottomPoint = CGPoint(x: sceneFrame.size.width, y: sceneFrame.size.height)
        let sceneFrameLeftBottompPoint = CGPoint(x: sceneFrame.origin.x, y: sceneFrame.size.height)
        
        if cropShape.contains(sceneFrame.origin) && cropShape.contains(sceneFrameRightTopPoint)
            && cropShape.contains(sceneFrameRightBottomPoint) && cropShape.contains(sceneFrameLeftBottompPoint){
            return true
        }
        return false
    }

    /// Decides if point of view is in filtered side or non filtered side.
    func inFilteredSide(_ portal: SCNNode, relativeTo cameraPoint: SCNNode, with conditions: Conditions) -> (isInFilteredSide: Bool, didEnterPortal: Bool) {
        
        guard !conditions.didEnterPortal else {
            if abs(cameraPoint.position.z - portal.position.z) > 0.2 {
                return (conditions.isInFilteredSide, false)
            }
            return (conditions.isInFilteredSide, true)
        }
        
        if !conditions.isInFilteredSide {
            if conditions.isPortalVisible && conditions.isPortalFrameBiggerThanCameras && abs(cameraPoint.position.z - portal.position.z) < 0.1 {
                return (!conditions.isInFilteredSide, true)
            } else {
                return (conditions.isInFilteredSide, false)
            }
            
        } else {
            if conditions.isPortalVisible && conditions.isPortalFrameBiggerThanCameras && abs(cameraPoint.position.z - portal.position.z) < 0.1 {
                return (!conditions.isInFilteredSide, true)
            } else {
                return (conditions.isInFilteredSide, false)
            }
        }
    }
    
    /// Returns portal projection `UIBezierPath` in camera captured image - crop shape. 
    func cropShape(for portal: SCNNode, in cameraFrame: ARCamera, with imageSize: CGSize, at rootNode: SCNNode) -> UIBezierPath {
        
        // Composing too left and bottom right corners for the plane from given bounding box instance.
        let minLeftPoint = SCNVector3.init(portal.boundingBox.min.x, portal.boundingBox.max.y, 0)
        let maxRightPoint = SCNVector3.init(portal.boundingBox.max.x, portal.boundingBox.min.y, 0)
        
        // Portal corner point projections to the camera captured image.
        let projectionMinLeft = getProjection(of: portal, for: minLeftPoint, in: cameraFrame, with: imageSize, using: rootNode)
        let projectionMaxRight = getProjection(of: portal, for: maxRightPoint, in: cameraFrame, with: imageSize, using: rootNode)
        let projectionMin = getProjection(of: portal, for: portal.boundingBox.min, in: cameraFrame, with: imageSize, using: rootNode)
        let projectionMax = getProjection(of: portal, for: portal.boundingBox.max, in: cameraFrame, with: imageSize, using: rootNode)
        
        /// Defines cropping shape, based on portal projection to the camera captured image.
        let cropShape: UIBezierPath = customShapeOf(pointA: projectionMinLeft, pointB: projectionMax, pointC: projectionMaxRight, pointD: projectionMin, in: imageSize)
                
        return cropShape
    }
    
    /// Converts and then projects node points into camera captured image plane.
    private func getProjection(of node: SCNNode, for vector: SCNVector3, in cameraFrame: ARCamera, with imageSize: CGSize, using rootNode: SCNNode) -> CGPoint {
        let convertedVector = rootNode.convertPosition(vector, from: node)
        let convertedToFloatVector = vector_float3.init(convertedVector)
        let projection = cameraFrame.projectPoint(convertedToFloatVector, orientation: .portrait, viewportSize: imageSize)
        return projection
    }
    
    /// Creates custom closed `UIBezierPath` for 4 points in selected size.
    private func customShapeOf(pointA: CGPoint,
                               pointB: CGPoint,
                               pointC: CGPoint,
                               pointD: CGPoint,
                               in frame: CGSize) -> UIBezierPath
    {
        let path = UIBezierPath()
        
        let controlRect = CGRect(origin: CGPoint.zero, size: frame)
        
        if pointC.y < frame.height, pointD.y < frame.height, !controlRect.contains(pointA), !controlRect.contains(pointB), !controlRect.contains(pointC), !controlRect.contains(pointD) {
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: frame.width, y: 0))
                path.addLine(to: CGPoint(x: pointC.x, y: pointC.y))
                path.addLine(to: CGPoint(x: pointD.x, y: pointD.y))
            
        } else {
            path.move(to: pointA)
            path.addLine(to: pointB)
            path.addLine(to: pointC)
            path.addLine(to: pointD)
        }
        
        path.close()
        return path
    }
}
