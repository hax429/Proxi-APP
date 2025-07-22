/*
 * @file      Feedback.swift
 *
 * @brief     Class to handle the Haptic Feedback.
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
import CoreHaptics
import AudioToolbox
import os.log

// Base struct for the feedback array implementing three different feedback levels
struct FeedbackLevel {
    var hummDuration: TimeInterval
    var timerIndexRef: Int
}

class Feedback {
    // Auxiliary variables for feedback
    var engine: CHHapticEngine?
    var timerIndex: Int = 0
    var shortDistance: Float = 1.0
    var longDistance: Float = 3.0
    var feedbackLevel: Int = 0
    var feedbackLevelOld: Int = 0
    var feedbackPar: [FeedbackLevel] = [FeedbackLevel(hummDuration: 1.0, timerIndexRef: 8),
                                        FeedbackLevel(hummDuration: 0.5, timerIndexRef: 4),
                                        FeedbackLevel(hummDuration: 0.1, timerIndexRef: 1)]
    
    let logger = os.Logger(subsystem: "com.qorvo.ni", category: "Feedback")
    
    func update() {
        // As the timer is fast timerIndex and timerIndexRef provides a
        // pre-scaler to achieve different patterns
        if  timerIndex != feedbackPar[feedbackLevel].timerIndexRef {
            timerIndex += 1
            return
        }
        
        timerIndex = 0
        
        // Handles Sound, if enabled
        let systemSoundID: SystemSoundID = 1052
        AudioServicesPlaySystemSound(systemSoundID)
        
        // Handles Haptic, if enabled
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        var events = [CHHapticEvent]()
        
        let humm = CHHapticEvent(eventType: .hapticContinuous,
                                 parameters: [],
                                 relativeTime: 0,
                                 duration: feedbackPar[feedbackLevel].hummDuration)
        events.append(humm)
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            logger.info("Failed to play pattern: \(error.localizedDescription).")
        }
    }
    
    func setLevel(distance: Float) {
        // Select feedback Level according to the distance
        if distance > longDistance {
            feedbackLevel = 0
        }
        else if distance > shortDistance {
            feedbackLevel = 1
        }
        else {
            feedbackLevel = 2
        }
        
        // If level changes, apply immediately
        if feedbackLevel != feedbackLevelOld {
            timerIndex = 0
            feedbackLevelOld = feedbackLevel
        }
    }
    
    func setDistanceThresholds(_ newShortDistance: Float,_ newLongDistance: Float) {
        shortDistance = newShortDistance
        longDistance = newLongDistance
    }
}
