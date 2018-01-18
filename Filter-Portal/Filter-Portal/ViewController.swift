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
        isInFilteredSide = false
        didEnterPortal = false
        shouldDisableButtons(true)
    }
    
    
    @IBAction func changeFilter(_ sender: UIButton) {
        if filterIndex < FilterIdentification().name.count - 1 {
            filterIndex += 1
        } else {
            filterIndex = 0
        }
    }
    
    @IBAction func addPlane(_ sender: UIButton) {
        showARPlanes(true)

        tapRecognizer.isEnabled = true
        
        let alert = UIAlertController(title: "", message: "Tap on the plane to add the portal.", preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func takeAPhoto(_ sender: UIButton) {
        shouldSavePhoto = true
    }
    
    @IBOutlet weak var photoCaptureButotn: UIButton!
    private var shouldSavePhoto: Bool = false
    private var tapRecognizer = UITapGestureRecognizer()
    
    @IBOutlet weak var filterButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    
    @IBOutlet weak var sessionInfoView: UIView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
    
    private let portalSize: CGSize = CGSize(width: 0.5, height: 0.9)
    private var portal: PortalNode?

    private let filter = Filter()
    private var filterIndex: Int = 4
    
    private let spacialArrangement = SpacialArrangement()
    
    private var isPortalFrameBiggerThanCameras = false
    private var isInFilteredSide = false
    private var isPortalVisible = true
    private var didEnterPortal = false


    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        // Adds tap gesture recognizer to add portal to the scene.
        let tapHandler = #selector(handleTapGesture(recognizer:))
        tapRecognizer = UITapGestureRecognizer(target: self, action: tapHandler)
        self.view.addGestureRecognizer(tapRecognizer)
        tapRecognizer.isEnabled = false

        // Adds pinch gesture to scale the node.
        let pinchHandler = #selector(handlePinchGesture(recognizer:))
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: pinchHandler)
        self.view.addGestureRecognizer(pinchRecognizer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if sceneView.scene.rootNode.childNode(withName: "portal", recursively: true) != nil {
            shouldDisableButtons(false)
        } else {
            shouldDisableButtons(true)
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
        
        showARPlanes(nil)
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
        
        showARPlanes(nil)
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
        if let portal = portal {
            let cropShape = spacialArrangement.evaluateCropShape(for: portal, in: frame.camera, with: frameImage.extent.size, at: sceneView.scene.rootNode)
            let filteredCIImage = filter.apply(to: frameImage, withMaskOf: cropShape, using: filterIndex)
            let cgImage = convert(filteredCIImage)
            sceneView.scene.background.contents = cgImage
        } else {
            let cgImage = convert(frameImage)
            sceneView.scene.background.contents = cgImage
        }
        
        //
        // ADD ERROR MESSAGE WITH NOT BEING ABLE TO RENDER CONTENT
        //
        
        if shouldSavePhoto {
            presentPhotoVC(with: CIImage.init(cgImage: sceneView.scene.background.contents as! CGImage))
        }
    }
    
//    private let context = CIContext()

    private func convert(_ ciImage: CIImage) -> CGImage? {
        let frameCGImage = CIContext().createCGImage(ciImage, from: ciImage.extent)
        CIContext().clearCaches()
        return frameCGImage
    }
    
    /// Saves photo.
    private func presentPhotoVC(with photo: CIImage) {
        shouldSavePhoto = false
        let photoViewController: PhotoViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PhotoViewController") as! PhotoViewController
        photoViewController.capturedCIImage = photo
        self.navigationController?.present(photoViewController, animated: true, completion: nil)
    }
    
    private func showARPlanes(_ yes: Bool?){
        for child in sceneView.scene.rootNode.childNodes {
            if child.name == "plane" {
                if let yes = yes, yes == true {
                    child.isHidden = false
                } else if sceneView.scene.rootNode.childNode(withName: "portal", recursively: true) != nil {
                    child.isHidden = true
                } else {
                    child.isHidden = false
                }
            }
        }
    }
    
    /// Decides if point of view is in filtered side or non filtered side.
    private func getTheSide(of cameraPoint: SCNNode, relativeTo portal: SCNNode) -> Bool {
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
    
    private func shouldDisableButtons(_ yes: Bool) {
        if yes {
            resetButton.isEnabled = false
            resetButton.alpha = 0.7
            filterButton.isEnabled = false
            filterButton.alpha = 0.7
            photoCaptureButotn.isHidden = true
        } else {
            resetButton.isEnabled = true
            resetButton.alpha = 1
            filterButton.isEnabled = true
            filterButton.alpha = 1
            photoCaptureButotn.isHidden = false
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
    
    
//    /// Converts and then projects node points into camera captured image plane.
//    private func getProjection(of nodes: SCNNode, _ vector: SCNVector3, in imageSize: CGSize, in imageCameraFrame: ARCamera) -> CGPoint {
//        let convertedVector = sceneView.scene.rootNode.convertPosition(vector, from: nodes)
//        let convertedToFloatVector = vector_float3.init(convertedVector)
//        let projection = imageCameraFrame.projectPoint(convertedToFloatVector, orientation: .portrait, viewportSize: imageSize)
//        return projection
//    }
//
//    /// Returns portal projection `UIBezierPath` in camera captured image.
//    private func currentPositionInCameraFrame(of portal: SCNNode, in imageCameraFrame: ARCamera, with imageSize: CGSize) -> UIBezierPath {
//
//        // Composing too left and bottom right corners for the plane from given bounding box instance.
//        let minLeftPoint = SCNVector3.init(portal.boundingBox.min.x, portal.boundingBox.max.y, 0)
//        let maxRightPoint = SCNVector3.init(portal.boundingBox.max.x, portal.boundingBox.min.y, 0)
//
//        // Portal corner point projections to the camera captured image.
//        let projectionMinLeft = getProjection(of: portal, minLeftPoint, in: imageSize, in: imageCameraFrame)
//        let projectionMaxRight = getProjection(of: portal, maxRightPoint, in: imageSize, in: imageCameraFrame)
//        let projectionMin = getProjection(of: portal, portal.boundingBox.min, in: imageSize, in: imageCameraFrame)
//        let projectionMax = getProjection(of: portal, portal.boundingBox.max, in: imageSize, in: imageCameraFrame)
//
//        /// Defines cropping shape, based on portal projection to the camera captured image.
//        let croppingShape: UIBezierPath = makeCustomShapeOf(pointA: projectionMinLeft, pointB: projectionMax, pointC: projectionMaxRight, pointD: projectionMin, in: imageSize)
//
//        return croppingShape
//    }
    
    
    
    
//    /// Creates custom closed `UIBezierPath` for 4 points in selected size.
//    private func makeCustomShapeOf(pointA: CGPoint, pointB: CGPoint, pointC: CGPoint, pointD: CGPoint, in frame: CGSize) -> UIBezierPath {
//        let path = UIBezierPath()
////
////        /// Mid point of AB line.
////        let pointAB = CGPoint(x: CGFloat(simd_min(Float(pointA.x), Float(pointB.x))) + abs(pointA.x - pointB.x) / 2,
////                              y: CGFloat(simd_min(Float(pointA.y), Float(pointB.y))) + abs(pointA.y - pointB.y) / 2)
////        /// Mid point of BC line.
////        var pointBC = CGPoint(x: CGFloat(simd_min(Float(pointC.x), Float(pointB.x))) + abs(pointC.x - pointB.x) / 2,
////                              y: CGFloat(simd_min(Float(pointC.y), Float(pointB.y))) + abs(pointC.y - pointB.y) / 2)
////
////        if pointBC.y < -200 {
////            pointBC.y = -200
////        }
////
////        /// Mid point of CD line.
////        let pointCD = CGPoint(x: CGFloat(simd_min(Float(pointD.x), Float(pointC.x))) + abs(pointC.x - pointD.x) / 2,
////                              y: CGFloat(simd_min(Float(pointD.y), Float(pointC.y))) + abs(pointC.y - pointD.y) / 2)
////        /// Mid point of DA line.
////        var pointDA = CGPoint(x: CGFloat(simd_min(Float(pointD.x), Float(pointA.x))) + abs(pointD.x - pointA.x) / 2,
////                              y: CGFloat(simd_min(Float(pointD.y), Float(pointA.y))) + abs(pointD.y - pointA.y) / 2)
////
////        if pointDA.y < -200 {
////            pointDA.y = -200
////        }
////
////        path.move(to: pointAB)
////        path.addQuadCurve(to: pointBC, controlPoint: pointB)
////        path.addQuadCurve(to: pointCD, controlPoint: pointC)
////        path.addQuadCurve(to: pointDA, controlPoint: pointD)
////        path.addQuadCurve(to: pointAB, controlPoint: pointA)
//
//        
//        path.move(to: pointA)
//        path.addLine(to: pointB)
//        path.addLine(to: pointC)
//        path.addLine(to: pointD)
//        
//        
//        
//        path.close()
//        
//        return path
//    }
    
    
    
    
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
    
    @objc private func handleTapGesture(recognizer: UITapGestureRecognizer){
        let touchPoint = recognizer.location(in: self.view)
        
        guard let hitPosition = getHitPoint(at: touchPoint), let cameraOrientation = cameraOrientation else { return }
        
        spawnPortal()
        let position = SCNVector3.init(hitPosition.x, hitPosition.y + Float(portalSize.height * 1.5), hitPosition.z)
        portal?.updatePosition(to: position, with: cameraOrientation)
        
        shouldDisableButtons(false)
        showARPlanes(nil)
    }
   
    private func spawnPortal() {
        if let portal = portal {
            portal.removeFromParentNode()
        }
        portal = PortalNode.setup(with: portalSize)
        guard let portal = portal else { return }
        portal.addFrame(of: "ParticlesPink.scnp", for: portalSize)
        sceneView.scene.rootNode.addChildNode(portal)
    }

    private func getHitPoint(at point: CGPoint) -> SCNVector3? {
        let hits = sceneView.hitTest(point, types: .existingPlane)
        
        guard let firstHit = hits.first else { return nil }
        let hitPosition = SCNVector3Make(firstHit.worldTransform.columns.3.x, firstHit.worldTransform.columns.3.y, firstHit.worldTransform.columns.3.z)
        
        return hitPosition
    }
    
    private var cameraPoint: SCNVector3? {
        guard let camera = sceneView.pointOfView else { return nil }
        return camera.position
    }
    private var cameraOrientation: SCNQuaternion? {
        guard let camera = sceneView.pointOfView else { return nil }
        return camera.orientation
    }
}

