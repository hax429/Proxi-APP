/*
 * @file      DesignSystem.swift
 *
 * @brief     Comprehensive design system for Proxi app including colors, fonts, and layout constraints
 *
 * @author    Proxi Team
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
 */

import UIKit
import SwiftUI

// MARK: - Color System
/**
 * Proxi Color System
 * 
 * Defines the color palette used throughout the Proxi app.
 * Colors are defined as UIColor extensions for UIKit compatibility
 * and can be easily converted to SwiftUI Color when needed.
 */
extension UIColor {
    // MARK: - Brand Colors
    static let qorvoBlue = UIColor(red: 0.00, green: 159/255, blue: 1.00, alpha: 1.00)
    static let qorvoRed = UIColor(red: 1.00, green: 123/255, blue: 123/255, alpha: 1.00)
    
    // MARK: - Gray Scale
    static let qorvoGray02 = UIColor(red: 249/255, green: 249/255, blue: 249/255, alpha: 1.00)
    static let qorvoGray05 = UIColor(red: 243/255, green: 243/255, blue: 243/255, alpha: 1.00)
    static let qorvoGray33 = UIColor(red: 169/255, green: 171/255, blue: 172/255, alpha: 1.00)
    static let qorvoGray50 = UIColor(red: 127/255, green: 129/255, blue: 133/255, alpha: 1.00)
}

// MARK: - SwiftUI Color Extensions
/**
 * SwiftUI Color Extensions
 * 
 * Provides SwiftUI Color equivalents for the Proxi color system.
 * These can be used directly in SwiftUI views.
 */
extension Color {
    // MARK: - Brand Colors
    static let qorvoBlue = Color(UIColor.qorvoBlue)
    static let qorvoRed = Color(UIColor.qorvoRed)
    
    // MARK: - Gray Scale
    static let qorvoGray02 = Color(UIColor.qorvoGray02)
    static let qorvoGray05 = Color(UIColor.qorvoGray05)
    static let qorvoGray33 = Color(UIColor.qorvoGray33)
    static let qorvoGray50 = Color(UIColor.qorvoGray50)
    
    // MARK: - Hex Color Initializer
    /**
     * Initialize Color from hex string
     * 
     * Supports 3-digit RGB, 6-digit RGB, and 8-digit ARGB formats
     * 
     * - Parameter hex: Hex color string (e.g., "#FF0000", "FF0000", "F00")
     */
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Layout Constraints
/**
 * Proxi Layout Constraints
 * 
 * Defines layout constants extracted from the app design.
 * These values ensure consistent spacing and sizing across the app.
 */
struct DesignConstraints {
    
    // MARK: - Table Constraints
    static let accessoryTableHeight: CGFloat = 261.0
    static let accessoryTableRowHeight: CGFloat = 87.0
    
    // MARK: - Device View Constraints
    static let deviceViewHeight: CGFloat = 52.0
    
    // MARK: - Button Constraints
    static let actionButtonWidth: CGFloat = 160.0
    static let connectingSide: CGFloat = 24.0
    
    // MARK: - Bar Constraints
    static let bottomBarHeight: CGFloat = 1.0
    static let bottomBarWidth: CGFloat = 370.0
    
    // MARK: - Icon Constraints
    static let pipeSide: CGFloat = 18.0
    static let miniArrowSide: CGFloat = 18.0
    static let fieldIconSide: CGFloat = 22.0
    static let scanningSide: CGFloat = 44.0
    
    // MARK: - Label Constraints
    static let miniLocationWidth: CGFloat = 160.0
    static let distanceLabelWidth: CGFloat = 52.0
    static let azimuthLabelWidth: CGFloat = 52.0
    static let valueTextHeight: CGFloat = 26.0
    static let titleTextHeight: CGFloat = 14.0
    
    // MARK: - Arrow View Constraints
    static let arrowViewHeight: CGFloat = 228.0
    static let arrowImageHeight: CGFloat = 164.0
    static let arrowImageWidth: CGFloat = 202.0
    
    // MARK: - Field Constraints
    static let locationFieldHeight: CGFloat = 100.0
    
    // MARK: - Separator Constraints
    static let separatorViewHeight: CGFloat = 52.0
    static let SEPARATOR_VIEW_HEIGHT_CONSTRAINT: CGFloat = 52.0
    
    // MARK: - World View Constraints
    static let worldViewHeight: CGFloat = 300.0
    static let WORLD_VIEW_HEIGHT_CONSTRAINT: CGFloat = 300.0
    
    // MARK: - Arrow View Constants
    static let ARROW_VIEW_HEIGHT_CONSTRAINT: CGFloat = 228.0
    static let ARROW_IMAGE_HEIGHT_CONSTRAINT: CGFloat = 164.0
    
    // MARK: - Device View Constants
    static let DEVICE_VIEW_HEIGHT_CONSTRAINT: CGFloat = 52.0
    
    // MARK: - Bar Constants
    static let BOTTOM_BAR_HEIGHT_CONSTRAINT: CGFloat = 1.0
    
    // MARK: - Text Constants
    static let VALUE_TEXT_HEIGHT_CONSTRAINT: CGFloat = 26.0
    static let TITLE_TEXT_HEIGHT_CONSTRAINT: CGFloat = 14.0
    
    // MARK: - Location Field Constants
    static let LOCATION_FIELD_HEIGHT_CONSTRAINT: CGFloat = 100.0
    
    // MARK: - Table Constants
    static let ACCESSORY_TABLE_HEIGHT_CONSTRAINT: CGFloat = 261.0
    static let ACCESSORY_TABLE_ROW_HEIGHT_CONSTRAINT: CGFloat = 87.0
    
    // MARK: - Arrow Image Constants
    static let ARROW_IMAGE_WIDTH_CONSTRAINT: CGFloat = 202.0
    
    // MARK: - Scanning Constants
    static let SCANNING_SIDE_CONSTRAINT: CGFloat = 44.0
    
    // MARK: - Field Icon Constants
    static let FIELD_ICON_SIDE_CONSTRAINT: CGFloat = 22.0
    
    // MARK: - Button Constants
    static let ACTION_BUTTON_WIDTH_CONSTRAINT: CGFloat = 160.0
    static let CONNECTING_SIDE_CONSTRAINT: CGFloat = 24.0
    
    // MARK: - Bar Constants
    static let BOTTOM_BAR_WIDTH_CONSTRAINT: CGFloat = 370.0
    
    // MARK: - Label Constants
    static let MINI_LOCATION_WIDTH_CONSTRAINT: CGFloat = 160.0
    static let DISTANCE_LABEL_WIDTH_CONSTRAINT: CGFloat = 52.0
    static let AZIMUTH_LABEL_WIDTH_CONSTRAINT: CGFloat = 52.0
    
    // MARK: - Icon Constants
    static let PIPE_SIDE_CONSTRAINT: CGFloat = 18.0
    static let MINI_ARROW_SIDE_CONSTRAINT: CGFloat = 18.0
}

// MARK: - Typography System
/**
 * Proxi Typography System
 * 
 * Defines font styles and typography constants for the app.
 * Note: Custom fonts are handled through asset catalogs for better performance.
 */
struct Typography {
    
    // MARK: - Font Sizes
    static let caption: CGFloat = 12.0
    static let body: CGFloat = 16.0
    static let title: CGFloat = 20.0
    static let largeTitle: CGFloat = 34.0
    
    // MARK: - Font Weights
    static let regular = Font.Weight.regular
    static let medium = Font.Weight.medium
    static let semibold = Font.Weight.semibold
    static let bold = Font.Weight.bold
    
    // MARK: - Predefined Text Styles
    static let captionText = Font.system(size: caption, weight: regular)
    static let bodyText = Font.system(size: body, weight: regular)
    static let titleText = Font.system(size: title, weight: semibold)
    static let largeTitleText = Font.system(size: largeTitle, weight: bold)
}

// MARK: - Spacing System
/**
 * Proxi Spacing System
 * 
 * Defines consistent spacing values used throughout the app.
 */
struct Spacing {
    static let xs: CGFloat = 4.0
    static let sm: CGFloat = 8.0
    static let md: CGFloat = 16.0
    static let lg: CGFloat = 24.0
    static let xl: CGFloat = 32.0
    static let xxl: CGFloat = 48.0
}

// MARK: - Corner Radius System
/**
 * Proxi Corner Radius System
 * 
 * Defines consistent corner radius values for UI elements.
 */
struct CornerRadius {
    static let small: CGFloat = 4.0
    static let medium: CGFloat = 8.0
    static let large: CGFloat = 12.0
    static let xlarge: CGFloat = 16.0
} 