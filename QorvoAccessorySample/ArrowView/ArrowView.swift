/*
 * @file      ArrowView.swift
 *
 * @brief     Implementation of the 3D Arrow, that can be turned to point to a Qorvo device ranging,
 *            or to a point related to the Qorvo device.
 *
 * @author    Decawave Applications
 *
 * @attention Copyright (c) 2021 - 2022, Qorvo US, Inc.
 * All rights reserved
 * Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright notice, this
 *  list of conditions, and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *  this list of conditions and the following disclaimer in the documentation
 *  and/or other materials provided with the distribution.
 * 3. You may only use this software, with or without any modification, with an
 *  integrated circuit developed by Qorvo US, Inc. or any of its affiliates
 *  (collectively, "Qorvo"), or any module that contains such integrated circuit.
 * 4. You may not reverse engineer, disassemble, decompile, decode, adapt, or
 *  otherwise attempt to derive or gain access to the source code to any software
 *  distributed under this license in binary or object code form, in whole or in
 *  part.
 * 5. You may not use any Qorvo name, trademarks, service marks, trade dress,
 *  logos, trade names, or other symbols or insignia identifying the source of
 *  Qorvo's products or services, or the names of any of Qorvo's developers to
 *  endorse or promote products derived from this software without specific prior
 *  written permission from Qorvo US, Inc. You must not call products derived from
 *  this software "Qorvo", you must not have "Qorvo" appear in their name, without
 *  the prior permission from Qorvo US, Inc.
 * 6. Qorvo may publish revised or new version of this license from time to time.
 *  No one other than Qorvo US, Inc. has the right to modify the terms applicable
 *  to the software provided under this license.
 * THIS SOFTWARE IS PROVIDED BY QORVO US, INC. "AS IS" AND ANY EXPRESS OR IMPLIED
 *  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. NEITHER
 *  QORVO, NOR ANY PERSON ASSOCIATED WITH QORVO MAKES ANY WARRANTY OR
 *  REPRESENTATION WITH RESPECT TO THE COMPLETENESS, SECURITY, RELIABILITY, OR
 *  ACCURACY OF THE SOFTWARE, THAT IT IS ERROR FREE OR THAT ANY DEFECTS WILL BE
 *  CORRECTED, OR THAT THE SOFTWARE WILL OTHERWISE MEET YOUR NEEDS OR EXPECTATIONS.
 * IN NO EVENT SHALL QORVO OR ANYBODY ASSOCIATED WITH QORVO BE LIABLE FOR ANY
 *  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 *  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 *  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 *  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 *  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 *  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 *
 */

import UIKit
import ARKit
import simd

class ArrowView: UIView {
    let arrowImgView = SCNView()
    let scanning = UIImageView()
    let infoLabel = UITextField(frame: .zero)
    
    let scene = SCNScene(named: "3d_arrow.usdz")
    
    // Used to animate scanning images
    var imageScanning = [UIImage]()
    
    // Auxiliary variables to handle the 3D arrow
    var curAzimuth: Int = 0
    var curElevation: Int = 0
    var curSpin: Int = 0
    
    var arrow3DEnabled = true;
    
    override init(frame: CGRect) {
        // Add subviews to the parent view
        super.init(frame: frame)
        addSubview(infoLabel)
        addSubview(arrowImgView)
        addSubview(scanning)
        
        // Prepare the "scanning" animation
        let image = UIImage(named: "spinner.svg")!
        for i in 0...24 {
            imageScanning.append(image.rotate(radians: Float(i) * .pi / 12)!)
        }
        scanning.animationImages = imageScanning
        scanning.translatesAutoresizingMaskIntoConstraints = false
        scanning.animationDuration = 1
        scanning.isHidden = false
        scanning.startAnimating()
        
        // Creating and adding ambien light to scene
        scene?.rootNode.light = SCNLight()
        scene?.rootNode.light?.type = .ambient
        scene?.rootNode.light?.color = UIColor.darkGray
        
        // AR settings for the Arrow Image View
        arrowImgView.translatesAutoresizingMaskIntoConstraints = false
        arrowImgView.autoenablesDefaultLighting = true
        arrowImgView.allowsCameraControl = false
        arrowImgView.backgroundColor = .white
        
        // Set scene settings
        arrowImgView.scene = scene
        initArrowPosition()
        switch3DArrow(arrow3DEnabled)
        arrowImgView.isHidden = true
        
        // Configure Info Label Text field
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.font = .dinNextRegular_m
        infoLabel.textAlignment = .center
        infoLabel.textColor = .black
        infoLabel.backgroundColor = UIColor.clear
        infoLabel.text = "ScanningAccessory".localized
        
        // Set up Stack view's constraints
        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            infoLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            arrowImgView.heightAnchor.constraint(equalToConstant: ARROW_IMAGE_HEIGHT_CONSTRAINT),
            arrowImgView.widthAnchor.constraint(equalToConstant: ARROW_IMAGE_WIDTH_CONSTRAINT),
            arrowImgView.centerXAnchor.constraint(equalTo: centerXAnchor),
            arrowImgView.centerYAnchor.constraint(equalTo: centerYAnchor),
            scanning.heightAnchor.constraint(equalToConstant: SCANNING_SIDE_CONSTRAINT),
            scanning.widthAnchor.constraint(equalToConstant: SCANNING_SIDE_CONSTRAINT),
            scanning.centerXAnchor.constraint(equalTo: centerXAnchor),
            scanning.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        // Set up the parent view's constraints
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: topAnchor),
            leadingAnchor.constraint(equalTo: leadingAnchor),
            trailingAnchor.constraint(equalTo: trailingAnchor),
            heightAnchor.constraint(equalToConstant: ARROW_VIEW_HEIGHT_CONSTRAINT)
        ])
        
        backgroundColor = .white
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Field Update Functions
    func initArrowPosition() {
        let degree = 1.0 * Float.pi / 180.0
        
        arrowImgView.scene?.rootNode.eulerAngles.x = -90 * degree
        arrowImgView.scene?.rootNode.eulerAngles.y = 0
        arrowImgView.scene?.rootNode.eulerAngles.z = 0
        
        curAzimuth = 0
        curElevation = 0
        curSpin = 0
    }
    
    func switch3DArrow(_ isEnabled: Bool) {
        if isEnabled {
            arrowImgView.autoenablesDefaultLighting = true
            scene?.rootNode.light?.color = UIColor.darkGray
        }
        else {
            arrowImgView.autoenablesDefaultLighting = false
            scene?.rootNode.light?.color = UIColor.black
        }
        
        arrow3DEnabled = isEnabled
    }
    
    func setArrowAngle(newElevation: Int, newAzimuth: Int) {
        let oneDegree = 1.0 * Float.pi / 180.0
        var deltaX, deltaY, deltaZ: Int
        
        if arrow3DEnabled {
            deltaX = newElevation - curElevation
            deltaY = newAzimuth - curAzimuth
            deltaZ = 0 - curSpin
            
            curElevation = newElevation
            curAzimuth = newAzimuth
            curSpin = 0
        }
        else {
            deltaX = 90 - curElevation
            deltaY = 0 - curAzimuth
            deltaZ = newAzimuth - curSpin
            
            curElevation = 90
            curAzimuth = 0
            curSpin = newAzimuth
        }
        
        arrowImgView.scene?.rootNode.eulerAngles.x += Float(deltaX) * oneDegree
        arrowImgView.scene?.rootNode.eulerAngles.y -= Float(deltaY) * oneDegree
        arrowImgView.scene?.rootNode.eulerAngles.z -= Float(deltaZ) * oneDegree
    }
    
    func setScanning(_ isScanning: Bool) {
        if isScanning {
            scanning.startAnimating()
            scanning.isHidden = false
        }
        else {
            scanning.stopAnimating()
            scanning.isHidden = true
        }
    }
    
    func infoLabelUpdate(with text: String) {
        infoLabel.text = text
        infoLabel.sizeToFit()
    }
    
    func enable3DArrow(_ isEnabled: Bool,_ isDirectionEnable: Bool) {
        arrowImgView.isHidden = !isEnabled
        //To check if we hide the label or not (used for indicate to user for Iphone14)
        infoLabel.isHidden =  appSettings.isDirectionEnable // Settings().isDirectionEnable
        isScanning(!isEnabled)
    }
    
    func isScanning(_ isScanning: Bool) {
        if isScanning {
            scanning.isHidden = false
            scanning.startAnimating()
        }
        else {
            scanning.isHidden = true
            scanning.stopAnimating()
        }
    }
    
    // MARK: - Private Utils
    // Provides the azimuth from an argument 3D directional.
    private func getAzimuth(_ direction: simd_float3) -> Int {
        let azimuthRad = asin(direction.x)
        
        return Int(90 * azimuthRad)
    }
    
    // Provides the elevation from the argument 3D directional.
    private func getElevation(_ direction: simd_float3) -> Int {
        let elevationRad =  atan2(direction.z, direction.y) + .pi / 2
        
        return Int(90 * elevationRad)
    }
}
