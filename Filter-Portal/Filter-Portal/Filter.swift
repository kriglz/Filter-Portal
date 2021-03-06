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
    let context = CIContext()

    /// Applies selected filters to the portal / scene.
    func apply(to frameImage: CIImage,
               withMaskOf cropShape: UIBezierPath?,
               using filterIndex: Int,
               _ conditions: Conditions) -> CIImage
    {
        let filterName = FilterIdentification().name[filterIndex]
        guard let filterNamed = filterName, let ciFilter = CIFilter(name: filterNamed) else { return frameImage }
        
        // Adds additional conditions for the pink filter.
        if filterNamed == "CIColorClamp" {
            ciFilter.setValue(CIVector.init(x: 0.4, y: 0.2, z: 0.4, w: 0), forKeyPath: "inputMinComponents")
            ciFilter.setValue(CIVector.init(x: 1, y: 0.4, z: 1, w: 1), forKeyPath: "inputMaxComponents")
        }
        
        // Portal frame is not bigger than camera's frame - portal edges are visible.
        if !conditions.didEnterPortal && conditions.isPortalVisible && !conditions.isPortalFrameBiggerThanCameras, let cropShape = cropShape {
            // Gets cropped image.
            let croppedImage = applyMask(of: cropShape, for: frameImage)
            
            // If camera is in non filtered side - looking to portal from outside.
            if !conditions.isInFilteredSide {
                let filteredImage = filtered(croppedImage, with: ciFilter)
                return filteredImage.composited(over: frameImage)
                
                // If camera is in filtered side, inside portal.
            } else {
                let filteredImage = filtered(frameImage, with: ciFilter)
                return croppedImage.composited(over: filteredImage)
            }
            
            // Portal frame is bigger than camera's frame - portal edges are not visible or portal is not in frame at all.
        } else if conditions.isPortalVisible && conditions.isPortalFrameBiggerThanCameras && !conditions.didEnterPortal {
            if !conditions.isInFilteredSide {
                return filtered(frameImage, with: ciFilter)
            } else {
                return frameImage
            }
            
        } else {
            if !conditions.isInFilteredSide {
                return frameImage
            } else {
                return filtered(frameImage, with: ciFilter)
            }
        }
    }
    
    /// Applies CI Filter to the CI image.
    private func filtered(_ image: CIImage, with ciFilter: CIFilter) -> CIImage {
        ciFilter.setValue(image, forKey: kCIInputImageKey)
        if let result = ciFilter.outputImage {
            return result
        } else {
            return image
        }
    }
    
    /// Cropps image using custom shape.
    private func applyMask(of BezierPath: UIBezierPath, for image: CIImage) -> CIImage {
        // Define graphic context (canvas) to paint on
        UIGraphicsBeginImageContext(image.extent.size)
        guard let currentGraphicsContext = UIGraphicsGetCurrentContext() else { return image }
        currentGraphicsContext.saveGState()
        
        // Flips image upside down to match `UIGraphicsGetCurrentContext`.
        let transformedImage = image.transformed(by: CGAffineTransform.init(scaleX: 1, y: -1)).transformed(by: CGAffineTransform.init(translationX: 0, y: image.extent.size.height))
        
        // Set the clipping mask
        BezierPath.addClip()
        guard let cgImage = context.createCGImage(transformedImage, from: image.extent) else { return image }
        currentGraphicsContext.draw(cgImage, in: image.extent)
        guard let maskedImage = UIGraphicsGetImageFromCurrentImageContext() else { return image }
        
        // Restore previous drawing context
        currentGraphicsContext.restoreGState()
        UIGraphicsEndImageContext()
        context.clearCaches()
        
        return CIImage.init(image: maskedImage) ?? image
    }
}
