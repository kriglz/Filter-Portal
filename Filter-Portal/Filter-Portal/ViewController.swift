//
//  ViewController.swift
//  Filter-Portal
//
//  Created by Kristina Gelzinyte on 1/4/18.
//  Copyright © 2018 Kristina Gelzinyte. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import SpriteKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    @IBOutlet weak var sessionInfoView: UIView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
//    private let portalNode = SCNNode(geometry: SCNBox(width: 0.1, height: 0.1, length: 0.1, chamferRadius: 0))
    private let portalSize: CGSize = CGSize(width: 0.5, height: 1.5)
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """) // For details, see https://developer.apple.com/documentation/arkit
        }
        
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        // Enable plane detection
        configuration.planeDetection = .horizontal
        configuration.isLightEstimationEnabled = true
        // Run the view's session
        sceneView.session.run(configuration)
        
        // Set a delegate to track the number of plane anchors for providing UI feedback.
        sceneView.session.delegate = self
        
        UIApplication.shared.isIdleTimerDisabled = true
        
        // Show debug UI to view performance metrics (e.g. frames per second).
        sceneView.showsStatistics = true
        sceneView.debugOptions = ARSCNDebugOptions.showFeaturePoints
        
        
        let tapHandler = #selector(handleTapGesture(byReactingTo:))
        let tapRecognizer = UITapGestureRecognizer(target: self, action: tapHandler)
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
    
    
    /// - Tag: UpdateARContent
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Place content only for anchors found by plane detection.
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Create a SceneKit plane to visualize the plane anchor using its position and extent.
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red
        plane.materials = [material]
        let planeNode = SCNNode(geometry: plane)
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        /*
         `SCNPlane` is vertically oriented in its local coordinate space, so
         rotate the plane to match the horizontal orientation of `ARPlaneAnchor`.
         */
        planeNode.eulerAngles.x = -.pi / 2
        
        // Make the plane visualization semitransparent to clearly show real-world placement.
        planeNode.opacity = 0.25
        
        /*
         Add the plane visualization to the ARKit-managed node so that it tracks
         changes in the plane anchor as plane estimation continues.
         */
        node.name = "plane"
        node.addChildNode(planeNode)
        
        // Removes debugging feature points.
        sceneView.debugOptions.remove(ARSCNDebugOptions.showFeaturePoints)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Update content only for plane anchors and nodes matching the setup created in `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as?  ARPlaneAnchor,
            let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else { return }
        
        
        // Plane estimation may shift the center of a plane relative to its anchor's transform.
        planeNode.simdPosition = float3(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        /*
         Plane estimation may extend the size of the plane, or combine previously detected
         planes into a larger one. In the latter case, `ARSCNView` automatically deletes the
         corresponding node for one plane, then calls this method to update the size of
         the remaining plane.
         */
        plane.width = CGFloat(planeAnchor.extent.x)
        plane.height = CGFloat(planeAnchor.extent.z)
    }
    
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    let context = CIContext()
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
//        if let filter = CIFilter(name: "CIPhotoEffectTonal") {
//            let image = CIImage(cvPixelBuffer: frame.capturedImage)//.oriented(.right)
//            filter.setValue(image, forKey: kCIInputImageKey)
//            if let result = filter.outputImage {
//                let cgImage = context.createCGImage(result, from: result.extent)
//                sceneView.scene.background.contents = cgImage
//
//                if let transform = currentScreenTransform() {
//                    sceneView.scene.background.contentsTransform = transform
//                }
//                context.clearCaches()
//            }
//        }
        
        
        let frameImage = CIImage(cvPixelBuffer: frame.capturedImage).oriented(.right)

        if let portal = sceneView.scene.rootNode.childNode(withName: "portal", recursively: true) {
            let cropRect = currentPositionInCameraFrame(of: portal, in: frame.camera, with: frameImage.extent.size)
            let croppedImage = frameImage.cropped(to: cropRect)
            
            if !isInFilteredSide {
                if let ciFilter = CIFilter(name: portalCIFilter) {
                    ciFilter.setValue(croppedImage, forKey: kCIInputImageKey)
                    
                    if let result = ciFilter.outputImage {
                        let newImage = result.composited(over: frameImage)
                        let frameCGImage = context.createCGImage(newImage, from: newImage.extent)
                        sceneView.scene.background.contents = frameCGImage
                        context.clearCaches()
                    }
                }
            } else {
                if let ciFilter = CIFilter(name: portalCIFilter) {
                    ciFilter.setValue(frameImage, forKey: kCIInputImageKey)
                    
                    if let result = ciFilter.outputImage {
                        let newImage = result//croppedImage.composited(over: result)
                        let frameCGImage = context.createCGImage(newImage, from: newImage.extent)
                        sceneView.scene.background.contents = frameCGImage
                        context.clearCaches()
                    }
                }
            }
        }
    }

    private let portalCIFilter: String = "CIPhotoEffectTonal"
    private var isInFilteredSide = false
    
    
    private func currentPositionInCameraFrame(of portal: SCNNode, in imageFrame: ARCamera, with imageSize: CGSize) -> CGRect {

//        let portalCenter = vector_float3.init(portal.position)
//        let projectionCenter = imageFrame.projectPoint(portalCenter, orientation: .portrait, viewportSize: imageSize)
        
        let convertMinPoint = sceneView.scene.rootNode.convertPosition(portal.boundingBox.min, from: portal)
        let boundingBoxMin = vector_float3.init(convertMinPoint)
        var projectionMin = imageFrame.projectPoint(boundingBoxMin, orientation: .portrait, viewportSize: imageSize)

        let convertMaxPoint = sceneView.scene.rootNode.convertPosition(portal.boundingBox.max, from: portal)
        let boundingBoxMax = vector_float3.init(convertMaxPoint)
        var projectionMax = imageFrame.projectPoint(boundingBoxMax, orientation: .portrait, viewportSize: imageSize)
        
        if projectionMin.x < 0 {
            projectionMin.x = 0
        }
        if projectionMax.y < 0 {
            projectionMax.y = 0
        }
        
        let portalRect = CGRect(x: projectionMin.x,
                                y: imageSize.height - (projectionMin.y - projectionMax.y) - projectionMax.y,
                                width: projectionMax.x - projectionMin.x,
                                height: projectionMin.y - projectionMax.y)
        
//        print(projectionMin, projectionMax)
//        print(imageSize)
        
        print((sceneView.pointOfView?.position.z)! - portal.position.z)
        
        if let camera = sceneView.pointOfView {
            if !isInFilteredSide {
                if projectionMin.x <= 0 && projectionMax.y <= 0 && projectionMax.x > imageSize.width && projectionMin.y > imageSize.height && camera.position.z - portal.position.z < 0.2 {
                    print("isInFilteredSide")
                    isInFilteredSide = true
                } else {
                    print("no")
                    isInFilteredSide = false
                }
            }
        }
        return portalRect
    }
    
    // MARK: - ARSessionObserver
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        sessionInfoLabel.text = "Session failed: \(error.localizedDescription)"
        resetTracking()
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        sessionInfoLabel.text = "Session was interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        sessionInfoLabel.text = "Session interruption ended"
        resetTracking()
    }
    
    // MARK: - Private methods
    
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move the device around to detect horizontal surfaces."
            
        case .normal:
            // No feedback needed when tracking is normal and planes are visible.
            message = ""
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing):
            message = "Initializing AR session."
        }
        
        sessionInfoLabel.text = message
        sessionInfoView.isHidden = message.isEmpty
    }
    
    private func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        removePlaneNodes()
        removePortalNode()
    }
    
    private func removePlaneNodes(){
        // Removes plane child nodes when portal is added.
        for child in sceneView.scene.rootNode.childNodes {
            if child.name == "plane" {
                child.removeFromParentNode()
            }
        }
    }
    
    private func removePortalNode(){
        // Removes plane child nodes when portal is added.
        for child in sceneView.scene.rootNode.childNodes {
            if child.name == "portal" {
                child.removeFromParentNode()
            }
        }
    }
    
    @objc private func handleTapGesture(byReactingTo: UITapGestureRecognizer){
        let touchPoint = byReactingTo.location(in: self.view)
        let portal = spawnPortal()
        addToPlane(item: portal, atPoint: touchPoint)
        removePlaneNodes()
    }
    
    private func spawnPortal() -> SCNNode{
        let portalPlane = SCNPlane(width: portalSize.width, height: portalSize.height)
        let material = SCNMaterial()
        material.transparency = 0.0
        material.isDoubleSided = true
        portalPlane.materials = [material]
        let portal = SCNNode(geometry: portalPlane)
        portal.name = "portal"
        return portal
    }
    
    func addToPlane(item: SCNNode, atPoint point: CGPoint) {
        let hits = sceneView.hitTest(point, types: .existingPlaneUsingExtent)
        if hits.count > 0, let firstHit = hits.first {
            let hitPosition = SCNVector3Make(firstHit.worldTransform.columns.3.x, firstHit.worldTransform.columns.3.y, firstHit.worldTransform.columns.3.z)
            
            item.position = hitPosition
            item.position.y += Float(portalSize.height/2)
            if let camera = sceneView.pointOfView {
                // Set plane position to face the camera.
                item.orientation = SCNVector4.init(0.0, camera.orientation.y, 0.0, camera.orientation.w)
            }
            
            for child in sceneView.scene.rootNode.childNodes {
                if child.name == "portal" {
                    child.removeFromParentNode()
                }
            }
            sceneView.scene.rootNode.addChildNode(item)
        }
    }
    
    private func currentScreenTransform() -> SCNMatrix4? {
        switch UIDevice.current.orientation {
        case .landscapeLeft:
            return SCNMatrix4Identity
        case .landscapeRight:
            return SCNMatrix4MakeRotation(.pi, 0, 0, 1)
        case .portrait:
            return SCNMatrix4MakeRotation(.pi / 2, 0, 0, 1)
        case .portraitUpsideDown:
            return SCNMatrix4MakeRotation(-.pi / 2, 0, 0, 1)
        default:
            return nil
        }
    }
}

