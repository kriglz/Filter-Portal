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

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, RPPreviewViewControllerDelegate, RPScreenRecorderDelegate {
    
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
    
    private var isRecording = false
    
    // - Actions
    
    @IBAction func resetScene(_ sender: UIButton) {
        resetScene()
    }
    
    private func resetScene() {
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
        let recorder = RPScreenRecorder.shared()
        recorder.delegate = self
        
        if recorder.isRecording {
            stopRecording()
        }
        
        guard recorder.isAvailable else {
            let alert = UIAlertController(title: "Oh noes!", message: "Screen recording is unavailable. Possible reasons: your device does not support it; you are displaying information over Airplay or through a TVOut session; another app is using the recorder right now. Please update your settings.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)

            return
        }
        
        recorder.startRecording { [weak self] error in
            if let error = error as NSError? {
                switch error.code {
                case RPRecordingErrorCode.userDeclined.rawValue:
                    self?.showAlert(with: "Video recording is impossible without screen recording.")
                default:
                    self?.showAlert(with: error.localizedDescription)
                }
            } else {
                DispatchQueue.main.async {
                    if recorder.isRecording {
                        self?.isRecording = true
                        self?.photoCaptureButotn.setImage(UIImage.init(named: "takephotoRecording"), for: .normal)
                    }
                }
            }
        }
    }
    
    private func showAlert(with message: String) {
        let alert = UIAlertController(title: "Oh noes!", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith previewViewController: RPPreviewViewController?, error: Error?) {
        
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.photoCaptureButotn.setImage(UIImage.init(named: "takephoto"), for: .normal)
        }
        
        // Display the error the user to alert them that the recording failed.
        if let error = error as NSError? {
            switch error.code {
            case RPRecordingErrorCode.userDeclined.rawValue:
                let message = "Video recording is impossible without screen recording."
                showAlert(with: message)
            case RPRecordingErrorCode.failedMediaServicesFailure.rawValue:
                let message = "Highly recommend to restart your phone to be able to record the screen. Error: \(error.localizedDescription)"
                showAlert(with: message)
            default:
                let message = "Highly recommend to restart your app to be able to record the screen. Error: \(error.localizedDescription)"
                showAlert(with: message)
            }
        }
    }
    
    private func stopRecording() {
        let recorder = RPScreenRecorder.shared()
        
        // Do nothing if screen recording is not available
        guard recorder.isAvailable else {
            return
        }
        
        photoCaptureButotn.setImage(UIImage.init(named: "takephoto"), for: .normal)
        isRecording = false

        recorder.stopRecording { [weak self] (preview, error) in
            
            if let error = error as NSError? {
                self?.showAlert(with: error.localizedDescription)
                return
            }
            
            guard preview != nil else {
                self?.showAlert(with: "Recorded video is not available.")
                return
            }
            
            let alert = UIAlertController(title: "Recording Finished", message: "Would you like to edit or delete your recording?", preferredStyle: .alert)
            
            let deleteAction = UIAlertAction(title: "Delete", style: .destructive, handler: { (action: UIAlertAction) in
                recorder.discardRecording(handler: { () -> Void in
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
        }
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
        photoCaptureButotn.isHidden = true
        tapRecognizer.isEnabled = false

        // Adds pinch gesture to scale the node.
        let pinchHandler = #selector(handlePinchGesture(recognizer:))
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: pinchHandler)
        self.view.addGestureRecognizer(pinchRecognizer)
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: Notification.Name.UIApplicationDidEnterBackground, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appResignsActive), name: Notification.Name.UIApplicationWillResignActive, object: nil)
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
    
    @objc func appResignsActive() {
        if isRecording {
            stopRecording()
        }
    }
    
    @objc func appMovedToBackground() {
        if isRecording {
            stopRecording()
        }
        resetScene()
        
        planeButton.isHidden = true
        photoCaptureButotn.isHidden = true
        tapRecognizer.isEnabled = false
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
        photoCaptureButotn.isHidden = false
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
        
//        if RPScreenRecorder.shared().isRecording {
//            print(RPScreenRecorder.shared().isAvailable)
//            print(RPScreenRecorder.shared().isRecording, "\n")
//
//        } else {
//            stopRecording()
//        }
       
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
            resetScene()
            
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
            resetScene()
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
            filterButton.isHidden = true
//            photoCaptureButotn.isHidden = true
        } else {
            resetButton.isHidden = false
            filterButton.isHidden = false
//            photoCaptureButotn.isHidden = false
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

