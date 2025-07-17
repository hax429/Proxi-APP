//
//  DeviceRowView.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/17/25.
//

import SwiftUI

// MARK: - Device Row View
struct DeviceRowView: View {
    let peripheral: CBPeripheral
    let isConnected: Bool
    let connectedPeripheralID: UUID?
    let onConnect: () -> Void
    
    var body: some View {
        Button(action: onConnect) {
            HStack {
                deviceInfo
                Spacer()
                connectionIndicator
            }
            .padding(.vertical, 5)
        }
        .disabled(isConnected)
    }
    
    private var deviceInfo: some View {
        VStack(alignment: .leading) {
            Text(peripheral.name ?? "Unknown Device")
                .font(.subheadline)
                .foregroundColor(.primary)
            Text(peripheral.identifier.uuidString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var connectionIndicator: some View {
        Group {
            if isConnected && connectedPeripheralID == peripheral.identifier {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
    }
}
