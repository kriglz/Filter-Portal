//
//  PhotoViewController.swift
//  Filter-Portal
//
//  Created by Kristina Gelzinyte on 1/16/18.
//  Copyright © 2018 Kristina Gelzinyte. All rights reserved.
//

import UIKit
import Photos
import MobileCoreServices

class PhotoViewController: UIViewController {

    private var imageJPEGData: Data?
    public var capturedImagePxB: CVPixelBuffer?
    @IBOutlet weak var imageView: UIImageView!

    @IBAction func discard(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func savePhoto(_ sender: Any) {
        // Save JPEG to photo library
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({ [weak self] in
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: (self?.imageJPEGData!)!, options: nil)
                    
                }, completionHandler: { success, error in
                    if let error = error {
                        print("Error occurred while saving photo to photo library: \(error)")
                    } else {
                        self.dismiss(animated: true, completion: nil)
                    }
                })
            }
        }
    }
    

    override func viewWillAppear(_ animated: Bool) {
        guard let capturedImagePxB = capturedImagePxB, let jpegData = jpegData(withPixelBuffer: capturedImagePxB, attachments: nil) else {
            print("Unable to create JPEG photo")
            self.dismiss(animated: false, completion: nil)
            return
        }
    
        imageJPEGData = jpegData
        imageView?.image = UIImage(data: jpegData)
    }

    private func jpegData(withPixelBuffer pixelBuffer: CVPixelBuffer, attachments: CFDictionary?) -> Data? {
        let ciContext = CIContext()
        let renderedCIImage = CIImage(cvImageBuffer: pixelBuffer).oriented(.right)
        guard let renderedCGImage = ciContext.createCGImage(renderedCIImage, from: renderedCIImage.extent) else {
            print("Failed to create CGImage")
            return nil
        }
        
        guard let data = CFDataCreateMutable(kCFAllocatorDefault, 0) else {
            print("Create CFData error!")
            return nil
        }
        
        guard let cgImageDestination = CGImageDestinationCreateWithData(data, kUTTypeJPEG, 1, nil) else {
            print("Create CGImageDestination error!")
            return nil
        }
        
        CGImageDestinationAddImage(cgImageDestination, renderedCGImage, attachments)
        if CGImageDestinationFinalize(cgImageDestination) {
            return data as Data
        }
        print("Finalizing CGImageDestination error!")
        return nil
    }
}
