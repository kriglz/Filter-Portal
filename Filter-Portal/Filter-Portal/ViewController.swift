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

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    @IBAction func resetScene(_ sender: UIButton) {
        for child in sceneView.scene.rootNode.childNodes {
            if child.name == "portal" {
                child.removeFromParentNode()
            }
        }
        shoulfDisableButtons(true)
    }
    
    @IBAction func changeFilter(_ sender: UIButton) {
        if filterIndex < portalCIFilter.count - 1 {
            filterIndex += 1
        } else {
            filterIndex = 0
        }
    }
    
    @IBAction func addPlane(_ sender: UIButton) {
        
        UIView.animate(withDuration: 5.0, animations: { [weak self] in
            self?.sessionInfoView.isHidden = false
            self?.sessionInfoLabel.text = "Tap on the plane to add the portal."
        }, completion: { _ in
            self.sessionInfoLabel.text = ""
            self.sessionInfoView.isHidden = true
        })
        
        
    }
    
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var sessionInfoView: UIView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
    private let portalSize: CGSize = CGSize(width: 0.5, height: 0.9)
    private let context = CIContext()
    private let portalCIFilter: [String] = ["CIPhotoEffectNoir", "CILineOverlay", "CIEdges", "CIColorPosterize", "CIColorInvert"]
    private var filterIndex: Int = 4 {
        didSet {
            switch filterIndex {
            case 1:
                shouldBeScaled = true
                scaleFactor = 4
            default:
                shouldBeScaled = false
                scaleFactor = 0
            }
        }
    }
    private var isPortalFrameBiggerThanCameras = false
    private var isInFilteredSide = false
    private var isPortalVisible = true
    private var shouldBeScaled: Bool = false
    private var scaleFactor: CGFloat = 0.0

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
        
        shoulfDisableButtons(true)
        
        // Adds tap gesture recognizer to add portal to the scene.
        let tapHandler = #selector(handleTapGesture(recognizer:))
        let tapRecognizer = UITapGestureRecognizer(target: self, action: tapHandler)
        self.view.addGestureRecognizer(tapRecognizer)
        
        // Adds pinch gesture to scale the node.
        let pinchHandler = #selector(handlePinchGesture(recognizer:))
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: pinchHandler)
        self.view.addGestureRecognizer(pinchRecognizer)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
    
    
    private func shoulfDisableButtons(_ yes: Bool) {
        if yes {
            resetButton.isEnabled = false
            resetButton.alpha = 0.7
            filterButton.isEnabled = false
            filterButton.alpha = 0.7
        } else {
            resetButton.isEnabled = true
            resetButton.alpha = 1
            filterButton.isEnabled = true
            filterButton.alpha = 1
        }
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
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let frameImage = CIImage(cvPixelBuffer: frame.capturedImage).oriented(.right)

        // Adds filters to the image only if portal has been created.
        if let portal = sceneView.scene.rootNode.childNode(withName: "portal", recursively: true) {
            applyFilter(to: portal, for: frameImage, ofCamera: frame)
        } else {
            let frameCGImage = context.createCGImage(frameImage, from: frameImage.extent)
            sceneView.scene.background.contents = frameCGImage
            context.clearCaches()
        }
    }
    
    private var didEnterPortal = false
    
    /// Decides if point of view is in filtered side or non filtered side.
    private func getTheSide(of cameraPoint: SCNNode, relativeTo portal: SCNNode) -> Bool {
        
//        print(isPortalVisible, "isPortalVisible")
//        print(cameraPoint.position.z - portal.position.z)
//        print(didEnterPortal, "didEnterPortal")
//        print(isInFilteredSide, "isInFilteredSide\n")

        guard !didEnterPortal else {
            if isPortalVisible && abs(cameraPoint.position.z - portal.position.z) > 0.2 {
                didEnterPortal = false
            }
            return isInFilteredSide
        }
        
        if !isInFilteredSide {
            if isPortalVisible && isPortalFrameBiggerThanCameras && abs(cameraPoint.position.z - portal.position.z) < 0.1 {
                didEnterPortal = true
                return true
            } else {
                return false
            }
            
        } else {
            if isPortalVisible && isPortalFrameBiggerThanCameras && abs(cameraPoint.position.z - portal.position.z) < 0.1 {
                didEnterPortal = true
                return false
            } else {
                return true
            }
        }
    }
    
    /// Applies selected filters to the portal / scene.
    private func applyFilter(to portal: SCNNode, for frameImage: CIImage, ofCamera frame: ARFrame) {
        if let ciFilter = CIFilter(name: portalCIFilter[filterIndex]){
            
            // Adds additional conditions for some filters.
            switch portalCIFilter[filterIndex] {
            case "CILineOverlay":
                ciFilter.setValue(1.0, forKey: kCIInputContrastKey)
                ciFilter.setValue(0.2, forKey: "inputThreshold")
                ciFilter.setValue(1, forKey: "inputEdgeIntensity")
                ciFilter.setValue(0.6, forKey: "inputNRSharpness")
                ciFilter.setValue(0.02, forKey: "inputNRNoiseLevel")
            case "CIGaussianBlur":
                ciFilter.setValue(5.0, forKey: kCIInputRadiusKey)
            case "CICrystallize":
                ciFilter.setValue(5.0, forKey: kCIInputRadiusKey)
            default:
                break
            }
            
            // Calculates if portal node is in camera's frustum.
            guard let cameraView = sceneView.pointOfView else { return }
            isPortalVisible = sceneView.isNode(portal, insideFrustumOf: cameraView)
            
            // Defines shape of cropping image.
            let cropShape = currentPositionInCameraFrame(of: portal, in: frame.camera, with: frameImage.extent.size)
            // Defines relative size of portal to visible scene.
            isPortalFrameBiggerThanCameras = compare(cropShape, with: frameImage.extent)
            // Defines point of view standing position.
            isInFilteredSide = getTheSide(of: cameraView, relativeTo: portal)
            
            
            // Portal frame is not bigger than camera's frame - portal edges are visible.
            if isPortalVisible && !isPortalFrameBiggerThanCameras {
                
                // Gets cropped image.
                let croppedImage = applyMask(of: cropShape, for: frameImage, in: frameImage.extent.size)
                
                // If camera is in non filtered side - looking to portal from outside.
                if !isInFilteredSide {
                    var tempImage = CIImage()
                    
                    if shouldBeScaled {
                        tempImage = scale(image: croppedImage, by: 1/scaleFactor)
                        ciFilter.setValue(tempImage, forKey: kCIInputImageKey)
                    } else {
                        ciFilter.setValue(croppedImage, forKey: kCIInputImageKey)
                    }
                    
                    if let result = ciFilter.outputImage {
                        if let background = backgroundImage(for: tempImage) {
                            var croppedWithBackgroundImage = result.composited(over: background)
                            // This filter image needs to be scaled down always.
                            croppedWithBackgroundImage = scale(image: croppedWithBackgroundImage, by: scaleFactor)
                            tempImage = croppedWithBackgroundImage.composited(over: frameImage)
                            let frameCGImage = context.createCGImage(tempImage, from: frameImage.extent)
                            sceneView.scene.background.contents = frameCGImage
                            context.clearCaches()
                        } else {
                            if shouldBeScaled {
                                tempImage = scale(image: result, by: scaleFactor)
                                tempImage = tempImage.composited(over: frameImage)
                            } else {
                                tempImage = result.composited(over: frameImage)
                            }
                            
                            let frameCGImage = context.createCGImage(tempImage, from: frameImage.extent)
                            sceneView.scene.background.contents = frameCGImage
                            context.clearCaches()
                        }
                    }
                    
                // If camera is in filtered side, inside portal.
                } else {
                    if shouldBeScaled {
                        let tempImage = scale(image: frameImage, by: 1/scaleFactor)
                        ciFilter.setValue(tempImage, forKey: kCIInputImageKey)
                    } else {
                        ciFilter.setValue(frameImage, forKey: kCIInputImageKey)
                    }
                    
                    if let result = ciFilter.outputImage {
                        if let background = backgroundImage(for: frameImage) {
                            var croppedWithBackgroundImage = result.composited(over: background)
                            croppedWithBackgroundImage = scale(image: croppedWithBackgroundImage, by: scaleFactor)
                            let newImage = croppedImage.composited(over: croppedWithBackgroundImage)
                            let frameCGImage = context.createCGImage(newImage, from: frameImage.extent)
                            sceneView.scene.background.contents = frameCGImage
                            context.clearCaches()
                        } else {
                            var tempImage = CIImage()
                            
                            if shouldBeScaled {
                                tempImage = scale(image: result, by: scaleFactor)
                                tempImage = croppedImage.composited(over: tempImage)
                            } else {
                                tempImage = croppedImage.composited(over: result)
                            }
                            
                            let frameCGImage = context.createCGImage(tempImage, from: frameImage.extent)
                            sceneView.scene.background.contents = frameCGImage
                            context.clearCaches()
                        }
                    }
                }
                
            // Portal frame is bigger than camera's frame - portal edges are not visible or portal is not in frame at all.
            } else if isPortalVisible && isPortalFrameBiggerThanCameras && !didEnterPortal {
                
                if isInFilteredSide {
                    let frameCGImage = context.createCGImage(frameImage, from: frameImage.extent)
                    sceneView.scene.background.contents = frameCGImage
                    context.clearCaches()
                } else {
                    if shouldBeScaled {
                        var tempImage = scale(image: frameImage, by: 1/scaleFactor)
                        ciFilter.setValue(tempImage, forKey: kCIInputImageKey)
                        if let result = ciFilter.outputImage {
                            
                            if let background = backgroundImage(for: tempImage) {
                                tempImage = result.composited(over: background)
                            } else {
                                tempImage = result
                            }
                            
                            tempImage = scale(image: tempImage, by: scaleFactor)
                            let frameCGImage = context.createCGImage(tempImage, from: frameImage.extent)
                            sceneView.scene.background.contents = frameCGImage
                            context.clearCaches()
                        }
                    } else {
                        ciFilter.setValue(frameImage, forKey: kCIInputImageKey)
                        
                        if let result = ciFilter.outputImage {
                            let frameCGImage = context.createCGImage(result, from: frameImage.extent)
                            sceneView.scene.background.contents = frameCGImage
                            context.clearCaches()
                        }
                    }
                }
            } else {//if !isPortalVisible {
                
                if !isInFilteredSide {
                    let frameCGImage = context.createCGImage(frameImage, from: frameImage.extent)
                    sceneView.scene.background.contents = frameCGImage
                    context.clearCaches()
                } else {
                    if shouldBeScaled {
                        var tempImage = scale(image: frameImage, by: 1/scaleFactor)
                        ciFilter.setValue(tempImage, forKey: kCIInputImageKey)
                        if let result = ciFilter.outputImage {
                            
                            if let background = backgroundImage(for: tempImage) {
                                tempImage = result.composited(over: background)
                            } else {
                                tempImage = result
                            }
                            
                            tempImage = scale(image: tempImage, by: scaleFactor)
                            let frameCGImage = context.createCGImage(tempImage, from: frameImage.extent)
                            sceneView.scene.background.contents = frameCGImage
                            context.clearCaches()
                        }
                    } else {
                        ciFilter.setValue(frameImage, forKey: kCIInputImageKey)
                        
                        if let result = ciFilter.outputImage {
                            let frameCGImage = context.createCGImage(result, from: frameImage.extent)
                            sceneView.scene.background.contents = frameCGImage
                            context.clearCaches()
                        }
                    }
                }
            }
        }
    }
    
    private func compare(_ mask: UIBezierPath, with sceneFrame: CGRect) -> Bool {
        let sceneFrameRightTopPoint = CGPoint(x: sceneFrame.size.width, y: sceneFrame.origin.y)
        let sceneFrameRightBottomPoint = CGPoint(x: sceneFrame.size.width, y: sceneFrame.size.height)
        let sceneFrameLeftBottompPoint = CGPoint(x: sceneFrame.origin.x, y: sceneFrame.size.height)
        
        if mask.contains(sceneFrame.origin) && mask.contains(sceneFrameRightTopPoint)
            && mask.contains(sceneFrameRightBottomPoint) && mask.contains(sceneFrameLeftBottompPoint){
            return true
        }
        return false
    }
    
    private func scale(image: CIImage, by factor: CGFloat) -> CIImage {
        let scaleFilter = CIFilter(name: "CIAffineTransform")!
        scaleFilter.setValue(image, forKey: kCIInputImageKey)
        scaleFilter.setValue(CGAffineTransform.init(scaleX: factor, y: factor), forKey: "inputTransform")
        let scaledImage = scaleFilter.outputImage!
        return scaledImage
    }
    
    private func backgroundImage(for croppedImage: CIImage) -> CIImage? {
        guard filterIndex == 1 else { return nil }
        
        // Adding color background for filters which make cropped image transparent.
        if let ciColorFilter = CIFilter(name: "CIColorClamp"){
            ciColorFilter.setValue(croppedImage, forKeyPath: kCIInputImageKey)
            ciColorFilter.setValue(CIVector.init(x: 1, y: 0, z: 1, w: 0), forKeyPath: "inputMinComponents")
            ciColorFilter.setValue(CIVector.init(x: 1, y: 0, z: 1, w: 1), forKeyPath: "inputMaxComponents")
            
            if let backgroundImageResult = ciColorFilter.outputImage {
                return backgroundImageResult
            }
        }
        return nil
    }
    
    /// Converts and then projects node points into camera captured image plane.
    private func getProjection(of nodes: SCNNode, _ vector: SCNVector3, in imageSize: CGSize, in imageCameraFrame: ARCamera) -> CGPoint {
        let convertedVector = sceneView.scene.rootNode.convertPosition(vector, from: nodes)
        let convertedToFloatVector = vector_float3.init(convertedVector)
        let projection = imageCameraFrame.projectPoint(convertedToFloatVector, orientation: .portrait, viewportSize: imageSize)
        return projection
    }
    
    /// Returns portal projection `UIBezierPath` in camera captured image.
    private func currentPositionInCameraFrame(of portal: SCNNode, in imageCameraFrame: ARCamera, with imageSize: CGSize) -> UIBezierPath {
        
        // Composing too left and bottom right corners for the plane from given bounding box instance.
        let minLeftPoint = SCNVector3.init(portal.boundingBox.min.x, portal.boundingBox.max.y, 0)
        let maxRightPoint = SCNVector3.init(portal.boundingBox.max.x, portal.boundingBox.min.y, 0)

        // Portal corner point projections to the camera captured image.
        let projectionMinLeft = getProjection(of: portal, minLeftPoint, in: imageSize, in: imageCameraFrame)
        let projectionMaxRight = getProjection(of: portal, maxRightPoint, in: imageSize, in: imageCameraFrame)
        let projectionMin = getProjection(of: portal, portal.boundingBox.min, in: imageSize, in: imageCameraFrame)
        let projectionMax = getProjection(of: portal, portal.boundingBox.max, in: imageSize, in: imageCameraFrame)
        
        /// Defines cropping shape, based on portal projection to the camera captured image.
        let croppingShape: UIBezierPath = makeCustomShapeOf(pointA: projectionMinLeft, pointB: projectionMax, pointC: projectionMaxRight, pointD: projectionMin, in: imageSize)
        
        return croppingShape
    }
    
    /// Creates custom closed `UIBezierPath` for 4 points in selected size.
    private func makeCustomShapeOf(pointA: CGPoint, pointB: CGPoint, pointC: CGPoint, pointD: CGPoint, in frame: CGSize) -> UIBezierPath {
        let path = UIBezierPath()
        
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
    
    /// Cropps image using custom shape.
    private func applyMask(of BezierPath: UIBezierPath, for image: CIImage, in imageSize: CGSize) -> CIImage {
        // Define graphic context (canvas) to paint on
        UIGraphicsBeginImageContext(imageSize)
        let currentGraphicsContext = UIGraphicsGetCurrentContext()!
        currentGraphicsContext.saveGState()
        
        // Flips image upside down to match `UIGraphicsGetCurrentContext`.
        let transformedImage = image.transformed(by: CGAffineTransform.init(scaleX: 1, y: -1)).transformed(by: CGAffineTransform.init(translationX: 0, y: image.extent.size.height))
        
        // Set the clipping mask
        BezierPath.addClip()
        let cgImage = context.createCGImage(transformedImage, from: image.extent)!
        currentGraphicsContext.draw(cgImage, in: image.extent)
        let maskedImage = UIGraphicsGetImageFromCurrentImageContext()!
        
        // Restore previous drawing context
        currentGraphicsContext.restoreGState()
        UIGraphicsEndImageContext()
        
        return CIImage.init(image: maskedImage)!
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
    }
    
    @objc private func handleTapGesture(recognizer: UITapGestureRecognizer){
        let touchPoint = recognizer.location(in: self.view)
        let portal = spawnPortal()
        addToPlane(item: portal, atPoint: touchPoint)
//        hidePlaneNodes()
        shoulfDisableButtons(false)
    }
    
    @objc func handlePinchGesture(recognizer: UIPinchGestureRecognizer){
        switch recognizer.state {
        case .changed, .ended:
            
            if isPortalVisible {
                for child in sceneView.scene.rootNode.childNodes {
                    if child.name == "portal" {
                        child.scale.x *= Float(recognizer.scale)
                        child.scale.y *= Float(recognizer.scale)
                        recognizer.scale = 1
                    }
                }
            }
        default:
            break
        }
    }
    
    private func hidePlaneNodes(){
        // Removes plane child nodes when portal is added.
        for child in sceneView.scene.rootNode.childNodes {
            if child.name == "plane" {
                child.isHidden = true
            }
        }
    }
    
    private func spawnPortal() -> SCNNode {
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
            item.position.y += Float(portalSize.height * 1.5)
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
}

