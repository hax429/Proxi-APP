/*
 * @file      Field.swift
 *
 * @brief     Field class for each parameter
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

class Field: UIView {
    // Info fields
    let fieldIcon: UIImageView
    let valueText: UITextField
    let titleText: UITextField
    // Stack View to organise
    let verticalStackView: UIStackView
    
    init(image: UIImage?, fieldTitle: String) {
        // Creating subviews
        fieldIcon = UIImageView(image: image)
        fieldIcon.contentMode = .scaleAspectFit
        fieldIcon.translatesAutoresizingMaskIntoConstraints = false
        
        valueText = UITextField(frame: .zero)
        valueText.translatesAutoresizingMaskIntoConstraints = false
        valueText.font = UIFont.systemFont(ofSize: 22, weight: .medium)
        valueText.contentVerticalAlignment = .bottom
        valueText.textAlignment = .center
        valueText.textColor = .black
        valueText.text = "-"
        
        titleText = UITextField(frame: .zero)
        titleText.translatesAutoresizingMaskIntoConstraints = false
        titleText.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        titleText.textAlignment = .center
        titleText.textColor = .qorvoGray33
        titleText.text = fieldTitle
        
        verticalStackView = UIStackView(arrangedSubviews: [fieldIcon, valueText, titleText])
        verticalStackView.translatesAutoresizingMaskIntoConstraints = false
        verticalStackView.axis = .vertical
        verticalStackView.distribution = .equalSpacing
        verticalStackView.spacing = 0
        
        super.init(frame: .zero)
        
        // Add the stack view to the subview
        addSubview(verticalStackView)
        
        // Set up the stack view's constraints with priorities to avoid conflicts
        let iconWidthConstraint = fieldIcon.widthAnchor.constraint(equalToConstant: FIELD_ICON_SIDE_CONSTRAINT)
        iconWidthConstraint.priority = UILayoutPriority(999) // High priority but not required
        
        let iconHeightConstraint = fieldIcon.heightAnchor.constraint(equalToConstant: FIELD_ICON_SIDE_CONSTRAINT)
        iconHeightConstraint.priority = UILayoutPriority(999) // High priority but not required
        
        let valueHeightConstraint = valueText.heightAnchor.constraint(equalToConstant: VALUE_TEXT_HEIGHT_CONSTRAINT)
        valueHeightConstraint.priority = UILayoutPriority(999) // High priority but not required
        
        let titleHeightConstraint = titleText.heightAnchor.constraint(equalToConstant: TITLE_TEXT_HEIGHT_CONSTRAINT)
        titleHeightConstraint.priority = UILayoutPriority(999) // High priority but not required
        
        NSLayoutConstraint.activate([
            fieldIcon.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconWidthConstraint,
            iconHeightConstraint,
            
            valueText.centerXAnchor.constraint(equalTo: centerXAnchor),
            valueHeightConstraint,
            
            titleText.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleHeightConstraint,
            
            verticalStackView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            verticalStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            verticalStackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            verticalStackView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Set content compression resistance and hugging priorities
        fieldIcon.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        fieldIcon.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        fieldIcon.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        fieldIcon.setContentHuggingPriority(.defaultHigh, for: .vertical)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setValue(_ newValue: String) {
        valueText.text = newValue
    }
    
    func setDisable(_ disable: Bool) {
        if (disable) {
            valueText.textColor = .lightGray
        }
        else {
            valueText.textColor = .black
        }
    }
}
