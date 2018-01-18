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
    func apply(with filterIndex: Int, to portal: SCNNode?, for frameImage: CIImage, ofCamera frame: ARFrame) -> CIImage {
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
                            filteredImage = croppedWithBackgroundImage.composited(over: frameImage)
                            
                        } else {
                            if shouldBeScaled {
                                tempImage = scale(image: result, by: scaleFactor)
                                filteredImage = tempImage.composited(over: frameImage)
                            } else {
                                filteredImage = result.composited(over: frameImage)
                            }
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
                            filteredImage = croppedImage.composited(over: croppedWithBackgroundImage)
                         
                        } else {
                            var tempImage = CIImage()
                            
                            if shouldBeScaled {
                                tempImage = scale(image: result, by: scaleFactor)
                                filteredImage = croppedImage.composited(over: tempImage)
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
                        var tempImage = scale(image: frameImage, by: 1/scaleFactor)
                        ciFilter.setValue(tempImage, forKey: kCIInputImageKey)
                        if let result = ciFilter.outputImage {
                            
                            if let background = backgroundImage(for: tempImage) {
                                tempImage = result.composited(over: background)
                            } else {
                                tempImage = result
                            }
                            
                            filteredImage = scale(image: tempImage, by: scaleFactor)
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
                        var tempImage = scale(image: frameImage, by: 1/scaleFactor)
                        ciFilter.setValue(tempImage, forKey: kCIInputImageKey)
                        if let result = ciFilter.outputImage {
                            
                            if let background = backgroundImage(for: tempImage) {
                                tempImage = result.composited(over: background)
                            } else {
                                tempImage = result
                            }
                            
                            filteredImage = scale(image: tempImage, by: scaleFactor)
                          
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
