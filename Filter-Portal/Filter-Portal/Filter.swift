//
//  Filter.swift
//  Filter-Portal
//
//  Created by Kristina Gelzinyte on 1/18/18.
//  Copyright © 2018 Kristina Gelzinyte. All rights reserved.
//

import UIKit
import ARKit

struct FilterIdentification {
    
    let name: Dictionary<Int, String> = [
        0: "CIPhotoEffectNoir",
        1: "CIColorClamp",
        2: "CIEdges",
        3: "CIColorPosterize",
        4: "CIColorInvert"
    ]
    
    let frameName: Dictionary<Int, String> = [
        0: "ParticlesBlack.scnp",
        1: "ParticlesPink.scnp",
        2: "ParticlesGold.scnp",
        3: "ParticlesBlackRed.scnp",
        4: "ParticlesWhite.scnp"
    ]
}

struct Filter {
    
    /// Applies selected filters to the portal / scene.
    func apply(to frameImage: CIImage, withMaskOf cropShape: UIBezierPath?, using filterIndex: Int, _ didEnterPortal: Bool, _ isPortalVisible: Bool, _ isInFilteredSide: Bool, _ isPortalFrameBiggerThanCameras: Bool) -> CIImage {
        
        let filterName = FilterIdentification().name[filterIndex]
        
        
        
        if let filterName = filterName, let ciFilter = CIFilter(name: filterName){

            // Adds additional conditions for some filters.
            if filterName == "CIColorClamp" {
                ciFilter.setValue(CIVector.init(x: 0.4, y: 0.2, z: 0.4, w: 0), forKeyPath: "inputMinComponents")
                ciFilter.setValue(CIVector.init(x: 1, y: 0.4, z: 1, w: 1), forKeyPath: "inputMaxComponents")
            }
            
            //                CILineOverlay filter properties:
            //                ciFilter.setValue(1.0, forKey: kCIInputContrastKey)
            //                ciFilter.setValue(0.2, forKey: "inputThreshold")
            //                ciFilter.setValue(1, forKey: "inputEdgeIntensity")
            //                ciFilter.setValue(0.6, forKey: "inputNRSharpness")
            //                ciFilter.setValue(0.02, forKey: "inputNRNoiseLevel")
          
            
            // Portal frame is not bigger than camera's frame - portal edges are visible.
            if isPortalVisible && !isPortalFrameBiggerThanCameras, let cropShape = cropShape {
                
                // Gets cropped image.
                let croppedImage = applyMask(of: cropShape, for: frameImage)

                // If camera is in non filtered side - looking to portal from outside.
                if !isInFilteredSide {
                    
                    ciFilter.setValue(croppedImage, forKey: kCIInputImageKey)
                    if let result = ciFilter.outputImage {
                        return result.composited(over: frameImage)
                    }
                    
                // If camera is in filtered side, inside portal.
                } else {
                    ciFilter.setValue(frameImage, forKey: kCIInputImageKey)
                    if let result = ciFilter.outputImage {
                        return croppedImage.composited(over: result)
                    }
                }
                
            // Portal frame is bigger than camera's frame - portal edges are not visible or portal is not in frame at all.
            } else if isPortalVisible && isPortalFrameBiggerThanCameras && !didEnterPortal {
                
                if !isInFilteredSide {
                    ciFilter.setValue(frameImage, forKey: kCIInputImageKey)
                    if let result = ciFilter.outputImage {
                        return result
                    }
                } else {
                    return frameImage
                }
                
            } else {
                
                if !isInFilteredSide {
                   return frameImage
                } else {
                    ciFilter.setValue(frameImage, forKey: kCIInputImageKey)
                    if let result = ciFilter.outputImage {
                        return result
                    }
                }
            }
        }
        
        return frameImage
    }
    
    let context = CIContext()

    
    /// Cropps image using custom shape.
    private func applyMask(of BezierPath: UIBezierPath, for image: CIImage) -> CIImage {
        // Define graphic context (canvas) to paint on
        UIGraphicsBeginImageContext(image.extent.size)
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
        
        context.clearCaches()
        
        return CIImage.init(image: maskedImage)!
    }
}
