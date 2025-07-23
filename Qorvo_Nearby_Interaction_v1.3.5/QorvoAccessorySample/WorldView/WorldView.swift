/*
 * @file      WorldView.swift
 *
 * @brief     Simple AR View Class, set to work with NI Sessions (Camera Assistance)
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

import Foundation
import ARKit
import RealityKit

class WorldView: ARView {
    
    let arConfig = ARWorldTrackingConfiguration()
    let anchor = AnchorEntity(world: SIMD3(x: 0, y: 0, z: 0))
    var entityDict = [Int:ModelEntity]()
    let pinShape = MeshResource.generateSphere(radius: 0.05)
    let material = SimpleMaterial(color: .yellow, isMetallic: false)
    
    required init(frame: CGRect) {
        // Set/start AR Session to provide camera assistance to new NI Sessions
        arConfig.worldAlignment = .gravity
        arConfig.isCollaborationEnabled = false
        arConfig.userFaceTrackingEnabled = false
        arConfig.initialWorldMap = nil
        
        super.init(frame: .zero)
        
        // Set/start the AR Session. This AR Session will be shared with NISessions
        session = ARSession()
        session.delegate = self
        session.run(arConfig)
        scene.addAnchor(anchor)
        
        isHidden = true
        contentMode = .scaleToFill
        
        // Set up the parent view's constraints
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: WORLD_VIEW_HEIGHT_CONSTRAINT)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func insertEntity(_ deviceID: Int) {
        // Create a new entity include ie to the anchor
        entityDict[deviceID] = ModelEntity(mesh: pinShape, materials: [material])
        entityDict[deviceID]!.position = [0, 0, 100]
        anchor.addChild(entityDict[deviceID]!)
    }
    
    func removeEntity(_ deviceID: Int) {
        // Remove entity and delete etityDict entry
        anchor.removeChild(entityDict[deviceID]!)
        entityDict.removeValue(forKey: deviceID)
    }
    
    func updateEntityPosition(_ deviceID: Int,_ transform: simd_float4x4) {
        entityDict[deviceID]!.transform.matrix = transform
    }
    
}

// MARK: - `ARSessionDelegate`.

extension WorldView: ARSessionDelegate {
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return false
    }
}
