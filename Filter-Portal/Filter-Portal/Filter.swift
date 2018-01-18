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
        1: "CIPhotoEffectNoir",
        2: "CILineOverlay",
        3: "CIEdges",
        4: "CIColorPosterize",
        5: "CIColorInvert"
    ]
}

struct Filter {
    
    /// Applies selected filters to the portal / scene.
    func apply(to frameImage: CIImage, withMaskOf cropShape: UIBezierPath, using filterIndex: Int) -> CIImage {
        var filteredImage = CIImage.init()

        let filterName = FilterIdentification().name[filterIndex]
        
        if let filterName = filterName, let ciFilter = CIFilter(name: filterName){
            
            var shouldBeScaled: Bool = false
            var scaleFactor: CGFloat = 0.0
            
            // Adds additional conditions for some filters.
            switch filterName {
            case "CILineOverlay":
                ciFilter.setValue(1.0, forKey: kCIInputContrastKey)
                ciFilter.setValue(0.2, forKey: "inputThreshold")
                ciFilter.setValue(1, forKey: "inputEdgeIntensity")
                ciFilter.setValue(0.6, forKey: "inputNRSharpness")
                ciFilter.setValue(0.02, forKey: "inputNRNoiseLevel")
                shouldBeScaled = true
                scaleFactor = 4.0
            default:
                shouldBeScaled = false
                break
            }
            
            // Calculates if portal node is in camera's frustum.
            guard let cameraView = sceneView.pointOfView else { return }
            isPortalVisible = sceneView.isNode(portal, insideFrustumOf: cameraView)
            
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
                    var tempScaledImage = CIImage()
                    
                    if shouldBeScaled {
                        tempScaledImage = scale(image: croppedImage, by: 1/scaleFactor)
                        ciFilter.setValue(tempScaledImage, forKey: kCIInputImageKey)
                    } else {
                        ciFilter.setValue(croppedImage, forKey: kCIInputImageKey)
                    }
                    
                    if let result = ciFilter.outputImage {
                        if let background = backgroundImage(for: tempScaledImage) {
                            var croppedWithBackgroundImage = result.composited(over: background)
                            // This filter image needs to be scaled down always.
                            croppedWithBackgroundImage = scale(image: croppedWithBackgroundImage, by: scaleFactor)
                            filteredImage = croppedWithBackgroundImage.composited(over: frameImage)
                            
                        } else {
                            if shouldBeScaled {
                                tempScaledImage = scale(image: result, by: scaleFactor)
                                filteredImage = tempScaledImage.composited(over: frameImage)
                            } else {
                                filteredImage = result.composited(over: frameImage)
                            }
                        }
                    }
                    
                    // If camera is in filtered side, inside portal.
                } else {
                    if shouldBeScaled {
                        let tempScaledImage = scale(image: frameImage, by: 1/scaleFactor)
                        ciFilter.setValue(tempScaledImage, forKey: kCIInputImageKey)
                    } else {
                        ciFilter.setValue(frameImage, forKey: kCIInputImageKey)
                    }
                    
                    if let result = ciFilter.outputImage {
                        if let background = backgroundImage(for: frameImage) {
                            var croppedWithBackgroundImage = result.composited(over: background)
                            croppedWithBackgroundImage = scale(image: croppedWithBackgroundImage, by: scaleFactor)
                            filteredImage = croppedImage.composited(over: croppedWithBackgroundImage)
                         
                        } else {
                            if shouldBeScaled {
                                let tempScaledImage = scale(image: result, by: scaleFactor)
                                filteredImage = croppedImage.composited(over: tempScaledImage)
                            } else {
                                filteredImage = croppedImage.composited(over: result)
                            }
                        }
                    }
                }
                
                // Portal frame is bigger than camera's frame - portal edges are not visible or portal is not in frame at all.
            } else if isPortalVisible && isPortalFrameBiggerThanCameras && !didEnterPortal {
                
                if isInFilteredSide {
                    filteredImage = frameImage
                   
                } else {
                    if shouldBeScaled {
                        var tempScaledImage = scale(image: frameImage, by: 1/scaleFactor)
                        
                        ciFilter.setValue(tempScaledImage, forKey: kCIInputImageKey)
                        
                        if let result = ciFilter.outputImage {
                            
                            if let background = backgroundImage(for: tempScaledImage) {
                                tempScaledImage = result.composited(over: background)
                            } else {
                                tempScaledImage = result
                            }
                            
                            filteredImage = scale(image: tempScaledImage, by: scaleFactor)
                        }
                    } else {
                        ciFilter.setValue(frameImage, forKey: kCIInputImageKey)
                        
                        if let result = ciFilter.outputImage {
                            filteredImage = result
                        }
                    }
                }
            } else {
                
                if !isInFilteredSide {
                     filteredImage = frameImage
                  
                } else {
                    if shouldBeScaled {
                        var tempScaledImage = scale(image: frameImage, by: 1/scaleFactor)
                        
                        ciFilter.setValue(tempScaledImage, forKey: kCIInputImageKey)
                        
                        if let result = ciFilter.outputImage {
                            
                            if let background = backgroundImage(for: tempScaledImage) {
                                tempScaledImage = result.composited(over: background)
                            } else {
                                tempScaledImage = result
                            }
                            filteredImage = scale(image: tempScaledImage, by: scaleFactor)
                          
                        }
                    } else {
                        ciFilter.setValue(frameImage, forKey: kCIInputImageKey)
                        
                        if let result = ciFilter.outputImage {
                            filteredImage = result
                        }
                    }
                }
            }
        }
        
        return filteredImage
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
        let cgImage = CIContext().createCGImage(transformedImage, from: image.extent)!
        currentGraphicsContext.draw(cgImage, in: image.extent)
        let maskedImage = UIGraphicsGetImageFromCurrentImageContext()!
        
        // Restore previous drawing context
        currentGraphicsContext.restoreGState()
        UIGraphicsEndImageContext()
        
        CIContext().clearCaches()
        
        return CIImage.init(image: maskedImage)!
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
    
    private func scale(image: CIImage, by factor: CGFloat) -> CIImage {
        let scaleFilter = CIFilter(name: "CIAffineTransform")!
        scaleFilter.setValue(image, forKey: kCIInputImageKey)
        scaleFilter.setValue(CGAffineTransform.init(scaleX: factor, y: factor), forKey: "inputTransform")
        let scaledImage = scaleFilter.outputImage!
        return scaledImage
    }
}
