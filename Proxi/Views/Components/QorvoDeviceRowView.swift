import SwiftUI

struct QorvoDeviceRowView: View {
    let qorvoDevice: qorvoDevice
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let isDeveloperMode: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Device Status Indicator
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)
            
            // Device Info
            VStack(alignment: .leading, spacing: 4) {
                Text(qorvoDevice.blePeripheralName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text(qorvoDevice.blePeripheralStatus ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    if isDeveloperMode {
                        Text("ID: \(qorvoDevice.bleUniqueID)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            
            Spacer()
            
            // Connection Status and Distance (if ranging)
            if qorvoDevice.blePeripheralStatus == statusRanging {
                VStack(alignment: .trailing, spacing: 2) {
                    if let distance = qorvoDevice.uwbLocation?.distance {
                        Text(String(format: "%.2fm", distance))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    if isDeveloperMode, let direction = qorvoDevice.uwbLocation?.direction {
                        Text("Dir: \(String(format: "%.2f,%.2f,%.2f", direction.x, direction.y, direction.z))")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            
            // Action Button
            Button(action: {
                if qorvoDevice.blePeripheralStatus == statusDiscovered {
                    onConnect()
                } else if qorvoDevice.blePeripheralStatus == statusRanging || qorvoDevice.blePeripheralStatus == statusConnected {
                    onDisconnect()
                }
            }) {
                Text(actionButtonTitle)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(actionButtonColor)
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    private var statusColor: Color {
        switch qorvoDevice.blePeripheralStatus {
        case statusDiscovered:
            return .orange
        case statusConnected:
            return .yellow
        case statusRanging:
            return .green
        default:
            return .red
        }
    }
    
    private var actionButtonTitle: String {
        switch qorvoDevice.blePeripheralStatus {
        case statusDiscovered:
            return "Connect"
        case statusConnected:
            return "Disconnect"
        case statusRanging:
            return "Disconnect"
        default:
            return "Unknown"
        }
    }
    
    private var actionButtonColor: Color {
        switch qorvoDevice.blePeripheralStatus {
        case statusDiscovered:
            return .blue
        case statusConnected:
            return .red
        case statusRanging:
            return .red
        default:
            return .gray
        }
    }
}
