//
//  SpacialArrangement.swift
//  Filter-Portal
//
//  Created by Kristina Gelzinyte on 1/18/18.
//  Copyright © 2018 Kristina Gelzinyte. All rights reserved.
//

import ARKit

struct SpacialArrangement {
    
    

    /// Returns portal projection `UIBezierPath` in camera captured image - crop shape. 
    func evaluateCropShape(for portal: SCNNode, in cameraFrame: ARCamera, with imageSize: CGSize, at rootNode: SCNNode) -> UIBezierPath {
        
        // Composing too left and bottom right corners for the plane from given bounding box instance.
        let minLeftPoint = SCNVector3.init(portal.boundingBox.min.x, portal.boundingBox.max.y, 0)
        let maxRightPoint = SCNVector3.init(portal.boundingBox.max.x, portal.boundingBox.min.y, 0)
        
        // Portal corner point projections to the camera captured image.
        let projectionMinLeft = getProjection(of: portal, for: minLeftPoint, in: cameraFrame, with: imageSize, using: rootNode)
        let projectionMaxRight = getProjection(of: portal, for: maxRightPoint, in: cameraFrame, with: imageSize, using: rootNode)
        let projectionMin = getProjection(of: portal, for: portal.boundingBox.min, in: cameraFrame, with: imageSize, using: rootNode)
        let projectionMax = getProjection(of: portal, for: portal.boundingBox.max, in: cameraFrame, with: imageSize, using: rootNode)
        
        /// Defines cropping shape, based on portal projection to the camera captured image.
        let cropShape: UIBezierPath = makeCustomShapeOf(pointA: projectionMinLeft, pointB: projectionMax, pointC: projectionMaxRight, pointD: projectionMin, in: imageSize)
                
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
    private func makeCustomShapeOf(pointA: CGPoint, pointB: CGPoint, pointC: CGPoint, pointD: CGPoint, in frame: CGSize) -> UIBezierPath {
        let path = UIBezierPath()
        //
        //        /// Mid point of AB line.
        //        let pointAB = CGPoint(x: CGFloat(simd_min(Float(pointA.x), Float(pointB.x))) + abs(pointA.x - pointB.x) / 2,
        //                              y: CGFloat(simd_min(Float(pointA.y), Float(pointB.y))) + abs(pointA.y - pointB.y) / 2)
        //        /// Mid point of BC line.
        //        var pointBC = CGPoint(x: CGFloat(simd_min(Float(pointC.x), Float(pointB.x))) + abs(pointC.x - pointB.x) / 2,
        //                              y: CGFloat(simd_min(Float(pointC.y), Float(pointB.y))) + abs(pointC.y - pointB.y) / 2)
        //
        //        if pointBC.y < -200 {
        //            pointBC.y = -200
        //        }
        //
        //        /// Mid point of CD line.
        //        let pointCD = CGPoint(x: CGFloat(simd_min(Float(pointD.x), Float(pointC.x))) + abs(pointC.x - pointD.x) / 2,
        //                              y: CGFloat(simd_min(Float(pointD.y), Float(pointC.y))) + abs(pointC.y - pointD.y) / 2)
        //        /// Mid point of DA line.
        //        var pointDA = CGPoint(x: CGFloat(simd_min(Float(pointD.x), Float(pointA.x))) + abs(pointD.x - pointA.x) / 2,
        //                              y: CGFloat(simd_min(Float(pointD.y), Float(pointA.y))) + abs(pointD.y - pointA.y) / 2)
        //
        //        if pointDA.y < -200 {
        //            pointDA.y = -200
        //        }
        //
        //        path.move(to: pointAB)
        //        path.addQuadCurve(to: pointBC, controlPoint: pointB)
        //        path.addQuadCurve(to: pointCD, controlPoint: pointC)
        //        path.addQuadCurve(to: pointDA, controlPoint: pointD)
        //        path.addQuadCurve(to: pointAB, controlPoint: pointA)
        
        path.move(to: pointA)
        path.addLine(to: pointB)
        path.addLine(to: pointC)
        path.addLine(to: pointD)
        
        path.close()
        return path
    }
}
