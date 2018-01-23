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
import ReplayKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, RPPreviewViewControllerDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!
    
    @IBOutlet weak var sessionInfoView: UIView!
    
    @IBOutlet weak var sessionInfoLabel: UILabel!
    
    @IBOutlet weak var photoCaptureButotn: UIButton!
    
    @IBOutlet weak var filterButton: UIButton!
    
    @IBOutlet weak var resetButton: UIButton!
    
    @IBOutlet weak var planeButton: UIButton!
    
    private var shouldSavePhoto: Bool = false
    
    private var tapRecognizer = UITapGestureRecognizer()
 
    private let portalSize: CGSize = CGSize(width: 0.5, height: 0.9)
    
    private var portal: PortalNode?
    
    private let filter = Filter()
    
    private var filterIndex: Int = 4
    
    private let spacialArrangement = SpacialArrangement()
    
    private let context = CIContext()
    
    private var isPortalFrameBiggerThanCameras = false
    private var isInFilteredSide = false
    private var isPortalVisible = true
    private var didEnterPortal = false
    
    let recorder = RPScreenRecorder.shared()
    private var isRecording = false
    
    // - Actions
    
    @IBAction func resetScene(_ sender: UIButton) {
        if let portalNode = portal {
            portalNode.removeFromParentNode()
            portal = nil
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
        
        portal?.addFrame(of: filterIndex, for: portalSize)
    }
    
    @IBAction func addPlane(_ sender: UIButton) {
        let midPoint = CGPoint(x: self.view.frame.size.width / 2, y: self.view.frame.size.height * 3 / 4)
        guard let hitPoint = getHitPoint(at: midPoint) else { return }
        spawnPortal(at: hitPoint)
        shouldDisableButtons(false)
        showARPlanes(nil)
    }
    
    @IBAction func takeAPhoto(_ sender: UIButton) {
//        shouldSavePhoto = true
        
        if !isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    private func startRecording() {
        guard recorder.isAvailable else {
            print("Recording is not available at this time.")
            return
        }
        
        recorder.startRecording{ [weak self] (error) in
            guard error == nil else {
                print("There was an error starting the recording.")
                return
            }
            
            print("Started Recording Successfully")
            self?.isRecording = true
        }
        
        photoCaptureButotn.setImage(UIImage.init(named: "takephotoRecording"), for: .normal)   
    }
  
    private func stopRecording() {
        recorder.stopRecording { [weak self] (preview, error) in
            print("Stopped recording")
            
            guard preview != nil else {
                print("Preview controller is not available.")
                return
            }
            
            let alert = UIAlertController(title: "Recording Finished", message: "Would you like to edit or delete your recording?", preferredStyle: .alert)
            
            let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: { (action: UIAlertAction) in
                self?.recorder.discardRecording(handler: { () -> Void in
                    print("Recording suffessfully deleted.")
                })
            })
            
            let editAction = UIAlertAction(title: "Edit", style: .default, handler: { (action: UIAlertAction) -> Void in
                preview?.previewControllerDelegate = self
                self?.present(preview!, animated: true, completion: nil)
            })
            
            alert.addAction(editAction)
            alert.addAction(deleteAction)
            self?.present(alert, animated: true, completion: nil)
            
            self?.isRecording = false
//            self?.viewReset()
        }
        photoCaptureButotn.setImage(UIImage.init(named: "takephoto"), for: .normal)

    }

    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        dismiss(animated: true)
    }
    
    // - View setup.

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
//        sceneView.showsStatistics = true
        sceneView.debugOptions = ARSCNDebugOptions.showFeaturePoints
        
        // Adds tap gesture recognizer to add portal to the scene.
        let tapHandler = #selector(handleTapGesture(recognizer:))
        tapRecognizer = UITapGestureRecognizer(target: self, action: tapHandler)
        self.view.addGestureRecognizer(tapRecognizer)
        
        planeButton.isHidden = true
//        planeButton.alpha = 0.7
        tapRecognizer.isEnabled = false

        // Adds pinch gesture to scale the node.
        let pinchHandler = #selector(handlePinchGesture(recognizer:))
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: pinchHandler)
        self.view.addGestureRecognizer(pinchRecognizer)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
   
        if portal != nil {
            shouldDisableButtons(false)
        } else {
            shouldDisableButtons(true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if isRecording {
            stopRecording()
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

    private func showIntroductionAlert() {
        wasIntroduced = true
        let alert = UIAlertController(title: "Good job!", message: "Now tap the screen or the PLUS button to place the portal and have fun!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))

        self.present(alert, animated: true, completion: nil)
    }
    
    private var wasIntroduced = false
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
        
        if !wasIntroduced {
            showIntroductionAlert()
        }
    
        planeButton.isHidden = false
//        planeButton.alpha = 0.7
        tapRecognizer.isEnabled = true
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
            
            // Calculates if portal node is in camera's frustum.
            guard let camera = sceneView.pointOfView else { return }
            
            isPortalVisible = sceneView.isNode(portal, insideFrustumOf: camera)

            var cropShape: UIBezierPath?
            
            if isPortalVisible {
                cropShape = spacialArrangement.evaluateCropShape(for: portal, in: frame.camera, with: frameImage.extent.size, at: sceneView.scene.rootNode)
                guard let cropShape = cropShape else { return }
                isPortalFrameBiggerThanCameras = spacialArrangement.compare(cropShape, with: frameImage.extent)
                
            }
//            else {
//                isPortalFrameBiggerThanCameras = false
//            }
            
            (isInFilteredSide, didEnterPortal) = spacialArrangement.inFilteredSide(portal, relativeTo: camera, didEnterPortal, isPortalVisible, isInFilteredSide, isPortalFrameBiggerThanCameras)
            
            
            let filteredCIImage = filter.apply(to: frameImage, withMaskOf: cropShape, using: filterIndex, didEnterPortal, isPortalVisible, isInFilteredSide, isPortalFrameBiggerThanCameras)
            
            let cgImage = convert(filteredCIImage)
            sceneView.scene.background.contents = cgImage
            
        } else {
            let cgImage = convert(frameImage)
            sceneView.scene.background.contents = cgImage
        }
    
        
        //
        // ADD ERROR MESSAGE WITH NOT BEING ABLE TO RENDER CONTENT
        //
        
        guard sceneView.scene.background.contents != nil else {
            print("\n ERROR - background is nil \n")
            return
        }
//        
//        if isRecording && !recorder.isRecording {
//            shouldSavePhoto = true
//            isRecording = false
//        }
        
        if shouldSavePhoto {
            let image = sceneView.snapshot()
            presentPhotoVC(with: CIImage.init(image: image)!)

//            presentPhotoVC(with: CIImage.init(cgImage: sceneView.scene.background.contents as! CGImage))
        }

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
    

    private func convert(_ ciImage: CIImage) -> CGImage? {
        let frameCGImage = context.createCGImage(ciImage, from: ciImage.extent)
        context.clearCaches()
        return frameCGImage
    }
    

    
    // MARK: - Private methods
    
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move the device around to detect horizontal surfaces 🤓"
            
        case .normal:
            // No feedback needed when tracking is normal and planes are visible.
            message = ""
            
        case .notAvailable:
            message = "Sorry, tracking unavailable ☹️"
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing):
            message = "Initializing... 🙄"
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
        guard let hitPosition = getHitPoint(at: touchPoint) else { return }
        spawnPortal(at: hitPosition)
        shouldDisableButtons(false)
        showARPlanes(nil)
    }
   
    private func spawnPortal(at position: SCNVector3) {
        if let portalNode = portal {
            portalNode.removeFromParentNode()
            portal = nil
        }
        
        guard let cameraOrientation = cameraOrientation else { return }
        portal = PortalNode.setup(with: portalSize)
        
        guard let portal = portal else { return }
        portal.addFrame(of: filterIndex, for: portalSize)
        portal.updatePosition(to: position, with: cameraOrientation)
        sceneView.scene.rootNode.addChildNode(portal)
    }

    private func getHitPoint(at point: CGPoint) -> SCNVector3? {
        let hits = sceneView.hitTest(point, types: .existingPlane)
        
        guard let firstHit = hits.first else { return nil }
        let hitPosition = SCNVector3Make(firstHit.worldTransform.columns.3.x, firstHit.worldTransform.columns.3.y + Float(portalSize.height * 1.5), firstHit.worldTransform.columns.3.z)
        
        return hitPosition
    }
    
    private func presentPhotoVC(with photo: CIImage) {
        shouldSavePhoto = false
        let photoViewController: PhotoViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PhotoViewController") as! PhotoViewController
        photoViewController.capturedCIImage = photo
        self.navigationController?.present(photoViewController, animated: true, completion: nil)
    }
    
    private func showARPlanes(_ yes: Bool?) {
        for child in sceneView.scene.rootNode.childNodes {
            if child.name == "plane" {
                if let yes = yes, yes == true {
                    child.isHidden = false
                } else if portal != nil {
                    child.isHidden = true
                } else {
                    child.isHidden = false
                }
            }
        }
    }
    
    private func shouldDisableButtons(_ yes: Bool) {
        if yes {
            resetButton.isHidden = true
//            resetButton.alpha = 0.7
            filterButton.isHidden = true
//            filterButton.alpha = 0.7
            photoCaptureButotn.isHidden = true
        } else {
            resetButton.isHidden = false
//            resetButton.alpha = 1
            filterButton.isHidden = false
//            filterButton.alpha = 1
            photoCaptureButotn.isHidden = false
        }
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

