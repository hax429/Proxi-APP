//
//  DebugLogView.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/17/25.
//

import SwiftUI

// MARK: - Debug Log View
struct DebugLogView: View {
    let debugLog: [String]
    
    var body: some View {
        NavigationView {
            List(debugLog, id: \.self) { logEntry in
                Text(logEntry)
                    .font(.system(.caption, design: .monospaced))
            }
            .navigationTitle("Debug Log")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


