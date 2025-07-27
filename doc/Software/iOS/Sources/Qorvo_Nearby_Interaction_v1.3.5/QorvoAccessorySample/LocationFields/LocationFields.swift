/*
 * @file      LocationFields.swift
 *
 * @brief     Implementation of the Location Fields to shopw Distance, Azimuth and Elevation.
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
import simd

enum FieldName: UInt8 {
    case fieldDistance = 0x1
    case fieldElevation = 0x2
    case fieldAzimuth = 0x3
}

class LocationFields: UIView {
    let distance  = Field(image: UIImage(named: "distance_icon"),  fieldTitle: "distance")
    let azimuth   = Field(image: UIImage(named: "azimuth_icon"),   fieldTitle: "azimuth")
    let elevation = Field(image: UIImage(named: "elevation_icon"), fieldTitle: "elevation")
    
    override init(frame: CGRect) {
        // Add your subviews to the horizontal stack view
        let LocationStackView = UIStackView(arrangedSubviews: [distance, azimuth, elevation])
        LocationStackView.translatesAutoresizingMaskIntoConstraints = false
        LocationStackView.axis = .horizontal
        LocationStackView.distribution = .fillEqually
        
        // Add your subview to the parent view
        super.init(frame: frame)
        addSubview(LocationStackView)
        
        // Set up Stack view's constraints
        NSLayoutConstraint.activate([
            LocationStackView.topAnchor.constraint(equalTo: topAnchor),
            LocationStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            LocationStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            LocationStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        // Set up the parent view's constraints
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: LOCATION_FIELD_HEIGHT_CONSTRAINT)
        ])
        
        backgroundColor = .white
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Field Update Functions
    func updateFields(newDistance: Float) {
        distance.setValue(String(format: "meters".localized, newDistance))
    }
    
    func updateFields(newDirection: simd_float3) {
        let newAzimuth = getAzimuth(newDirection)
        azimuth.setValue(String(format: "degrees".localized, newAzimuth))
        
        let newElevation = getElevation(newDirection)
        if Settings().isDirectionEnable {
            elevation.setValue(String(format: "degrees".localized, newElevation))
        } else {
            elevation.setValue(getElevationFromInt(elevation: newElevation))
        }
    }
    
    func updateFields(newDistance: Float, newDirection: simd_float3) {
        updateFields(newDistance: newDistance)
        updateFields(newDirection: newDirection)
    }
    
    func updateFields(fieldName: FieldName, newText: String) {
        switch fieldName {
        case .fieldDistance:
            distance.setValue(newText)
        case .fieldAzimuth:
            azimuth.setValue(newText)
        case .fieldElevation:
            elevation.setValue(newText)
        }
    }
    
    func disableFields(_ noUpdated: Bool) {
        azimuth.setDisable(noUpdated)
        elevation.setDisable(noUpdated)
    }
    
    func clearFields() {
        distance.setValue("-".localized)
        azimuth.setValue("-".localized)
        elevation.setValue("-".localized)
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
