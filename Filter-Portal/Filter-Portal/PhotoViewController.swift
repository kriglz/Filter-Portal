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
    
    @IBOutlet weak var imageView: UIImageView!
    
    private var imageJPEGData: Data?
    
    public var capturedCIImage: CIImage?

    
    
    // - Actions.

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
    
    
    
    // - View setup.
    
    override func viewWillAppear(_ animated: Bool) {
        guard let capturedCIImage = capturedCIImage, let jpegData = jpegData(for: capturedCIImage, attachments: nil) else {
            print("Unable to create JPEG photo")
            self.dismiss(animated: false, completion: nil)
            return
        }
        imageJPEGData = jpegData
        imageView?.image = UIImage(data: jpegData)
    }

    
    
    // - Private functions.
    
    private func jpegData(for ciImage: CIImage, attachments: CFDictionary?) -> Data? {
        let ciContext = CIContext()
        guard let renderedCGImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
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
