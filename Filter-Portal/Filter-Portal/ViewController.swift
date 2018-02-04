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

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    @IBOutlet weak var sceneView: ARSCNView!
    
    @IBOutlet weak var sessionInfoView: UIView!
    
    @IBOutlet weak var sessionInfoLabel: UILabel!
    
    @IBOutlet weak var photoCaptureButotn: UIButton!
    
    @IBOutlet weak var filterButton: UIButton!
    
    @IBOutlet weak var resetButton: UIButton!
    
    @IBOutlet weak var planeButton: UIButton!
    
    private var tapRecognizer = UITapGestureRecognizer()
    
    private var portal: PortalNode?
    
    private var filterIndex: Int = 1
    
    private let filter = Filter()
    
    private let spacialArrangement = SpacialArrangement()
    
    private let context = CIContext()
    
    private var isPortalFrameBiggerThanCameras = false
    private var isInFilteredSide = false
    private var isPortalVisible = true
    private var didEnterPortal = false
    
    private var isRecording = false
    
    private var wasIntroduced = false

    var shouldUpdateBackgroundPicture = false

    
    
    // - Actions
    
    @IBAction func resetScene(_ sender: UIButton) {
        resetScene()
    }
    
    @IBAction func changeFilter(_ sender: UIButton) {
        if let portal = portal {
            if filterIndex < FilterIdentification().name.count - 1 {
                filterIndex += 1
            } else {
                filterIndex = 0
            }
            portal.addFrame(of: filterIndex)
        }
    }
    
    @IBAction func addPlane(_ sender: UIButton) {
        let midPoint = CGPoint(x: self.view.frame.size.width / 2, y: self.view.frame.size.height * 3 / 4)
        guard let position = hitPosition(at: midPoint) else { return }
        spawnPortal(at: position)
        shouldDisableButtons(false)
        showARPlanes()
    }
    
    @IBAction func takeAPhoto(_ sender: UIButton) {
        if !isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    
    
    // - View setup.

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        // Enable plane detection
        configuration.planeDetection = .horizontal
        configuration.isLightEstimationEnabled = true
        // Run the view's session
//        sceneView.session.run(configuration)
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

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
        
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: Notification.Name.UIApplicationDidEnterBackground, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appResignsActive), name: Notification.Name.UIApplicationWillResignActive, object: nil)
        
        planeButton.isHidden = true
        photoCaptureButotn.isHidden = true
        tapRecognizer.isEnabled = false
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
        
        showARPlanes()
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
        
        showARPlanes()
    }
    
    
    
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
        guard let frame = session.currentFrame else { return }
        updateSessionInfoLabel(for: frame, trackingState: camera.trackingState)
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let frameImage = CIImage(cvPixelBuffer: frame.capturedImage).oriented(.right)
        
        // Adds filters to the image only if portal has been created.
        if let portal = portal {
            if shouldUpdateBackgroundPicture {

            guard let camera = sceneView.pointOfView else { return }
            // Calculates if portal node is in camera's frustum.
            isPortalVisible = sceneView.isNode(portal, insideFrustumOf: camera)

            var cropShape: UIBezierPath?

            if isPortalVisible {
                cropShape = spacialArrangement.cropShape(for: portal, in: frame.camera, with: frameImage.extent.size, at: sceneView.scene.rootNode)
                guard let cropShape = cropShape else { return }
                isPortalFrameBiggerThanCameras = spacialArrangement.compare(cropShape, with: frameImage.extent)
            }

            (isInFilteredSide, didEnterPortal) = spacialArrangement.inFilteredSide(portal, relativeTo: camera, didEnterPortal, isPortalVisible, isInFilteredSide, isPortalFrameBiggerThanCameras)


            let filteredCIImage = filter.apply(to: frameImage, withMaskOf: cropShape, using: filterIndex, didEnterPortal, isPortalVisible, isInFilteredSide, isPortalFrameBiggerThanCameras)

            let cgImage = convert(filteredCIImage)
            sceneView.scene.background.contents = cgImage
            

//            if shouldUpdateBackgroundPicture {
//                let colorFilter = CIFilter(name: "CIColorClamp")
//                colorFilter?.setValue(CIVector.init(x: 0.4, y: 0.2, z: 0.4, w: 0), forKeyPath: "inputMinComponents")
//                colorFilter?.setValue(CIVector.init(x: 1, y: 0.4, z: 1, w: 1), forKeyPath: "inputMaxComponents")
//                colorFilter?.setValue(frameImage, forKey: kCIInputImageKey)
//                guard let resultColored = colorFilter?.outputImage else { return }
//
//                sceneView.scene.background.contents = UIColor.black
//
//                let maskImage = CIImage(image: sceneView.snapshot())!//?.cropped(to: frameImage.extent)
//                let ciFilter = CIFilter(name: "CIMaskToAlpha")
//                ciFilter?.setValue(maskImage, forKey: kCIInputImageKey)
//                guard let resultMask = ciFilter?.outputImage else { return }
//
//                let maskFilter = CIFilter(name: "CIBlendWithAlphaMask")
//                maskFilter?.setValue(resultColored, forKey: kCIInputImageKey)
//                maskFilter?.setValue(resultMask, forKey: kCIInputMaskImageKey)
//                maskFilter?.setValue(frameImage, forKey: kCIInputBackgroundImageKey)
//                guard let finalResult = maskFilter?.outputImage else { return }
//
//                imageVIew.isHidden = false
//                imageVIew.image = UIImage(ciImage: finalResult)

                shouldUpdateBackgroundPicture = false

            } else {
                shouldUpdateBackgroundPicture = true
            }
        } else {
            let cgImage = convert(frameImage)
            sceneView.scene.background.contents = cgImage
        }
    }
    
    @IBOutlet weak var imageVIew: UIImageView!
    
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
    
    
    // MARK: - Private methods
    
    private func convert(_ ciImage: CIImage) -> CGImage? {
        let frameCGImage = context.createCGImage(ciImage, from: ciImage.extent)
        context.clearCaches()
        return frameCGImage
    }
    
    private func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
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
    
    private func showAlert(with message: String) {
        let alert = UIAlertController(title: "Oh noes!", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func showIntroductionAlert() {
        wasIntroduced = true
        let alert = UIAlertController(title: "Good job!", message: "Now tap the screen or the PLUS button to place the portal and have fun!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
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
    
    @objc private func handleTapGesture(recognizer: UITapGestureRecognizer){
        let touchPoint = recognizer.location(in: self.view)
        guard let hitPosition = hitPosition(at: touchPoint) else { return }
        spawnPortal(at: hitPosition)
        shouldDisableButtons(false)
        showARPlanes()
    }
   
    private func spawnPortal(at position: SCNVector3) {
        if let portalNode = portal {
            portalNode.removeFromParentNode()
            portal = nil
        }
        portal = PortalNode.setup()
        guard let cameraOrientation = cameraOrientation, let portal = portal else {
            return
        }
        portal.addFrame(of: filterIndex)
        portal.updatePosition(to: position, with: cameraOrientation)
        sceneView.scene.rootNode.addChildNode(portal)
    }

    private func hitPosition(at point: CGPoint) -> SCNVector3? {
        let hits = sceneView.hitTest(point, types: .existingPlane)
        guard let firstHit = hits.first else {
            return nil
        }
        let hitPosition = SCNVector3Make(firstHit.worldTransform.columns.3.x,
                                         firstHit.worldTransform.columns.3.y + Float(portalSize.height * 1.5),
                                         firstHit.worldTransform.columns.3.z)
        return hitPosition
    }
    
    private func showARPlanes() {
        for child in sceneView.scene.rootNode.childNodes {
            if child.name == "plane" {
                if portal != nil {
                    child.isHidden = true
                } else {
                    child.isHidden = false
                }
            }
        }
    }
    
    private func shouldDisableButtons(_ bool: Bool) {
        if bool {
            resetButton.isHidden = true
            filterButton.isHidden = true
        } else {
            resetButton.isHidden = false
            filterButton.isHidden = false
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



extension ViewController: RPPreviewViewControllerDelegate, RPScreenRecorderDelegate {
    func startRecording() {
        let recorder = RPScreenRecorder.shared()
        recorder.delegate = self
        
        if recorder.isRecording {
            stopRecording()
        }
        
        guard recorder.isAvailable else {
            showAlert(with: "Screen recording is unavailable. Possible reasons: your device does not support it; you are displaying information over Airplay or through a TVOut session; another app is using the recorder right now. Please update your settings.")
            return
        }
        
        recorder.startRecording { [weak self] error in
            if let error = error as NSError? {
                switch error.code {
                case RPRecordingErrorCode.userDeclined.rawValue:
                    return
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
    
    func screenRecorder(_ screenRecorder: RPScreenRecorder, didStopRecordingWith previewViewController: RPPreviewViewController?, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.photoCaptureButotn.setImage(UIImage.init(named: "takephoto"), for: .normal)
        }
        
        // Display the error the user to alert them that the recording failed.
        if let error = error as NSError? {
            switch error.code {
            case RPRecordingErrorCode.userDeclined.rawValue:
                return
            case RPRecordingErrorCode.failedMediaServicesFailure.rawValue:
                let message = "Highly recommend to restart your phone to be able to record the screen. Error: \(error.localizedDescription)"
                showAlert(with: message)
            default:
                let message = "Highly recommend to restart your app to be able to record the screen. Error: \(error.localizedDescription)"
                showAlert(with: message)
            }
        }
    }
    
    func stopRecording() {
        let recorder = RPScreenRecorder.shared()
        guard recorder.isAvailable else { return }
        
        photoCaptureButotn.setImage(UIImage.init(named: "takephoto"), for: .normal)
        isRecording = false
        
        recorder.stopRecording { [weak self] (preview, error) in
            if let error = error as NSError? {
                self?.showAlert(with: error.localizedDescription)
                return
            }
            
            guard let preview = preview else {
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
                preview.previewControllerDelegate = self
                self?.present(preview, animated: true, completion: nil)
            })
            
            alert.addAction(editAction)
            alert.addAction(deleteAction)
            self?.present(alert, animated: true, completion: nil)
        }
    }
    
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        dismiss(animated: true)
    }
}

