# Multi-Device UWB Arduino Code

## Overview
This enhanced Arduino code supports multiple iPhone connections simultaneously, providing robust device management, connection tracking, and UWB session handling.

## Key Features

### 1. Multi-Device Support
- **Maximum Devices**: Supports up to 8 simultaneous BLE connections
- **Device Tracking**: Each connected device is tracked with unique ID and status
- **Session Management**: Tracks active UWB sessions per device
- **Connection Quality**: Monitors connection health and activity

### 2. Enhanced Device Management
- **Automatic Cleanup**: Removes inactive or disconnected devices
- **Activity Tracking**: Monitors last activity time for each device
- **Session States**: Tracks whether each device has an active UWB session
- **Unique Device IDs**: Assigns sequential IDs to connected devices

### 3. Improved Stability
- **Connection Timeout**: Automatically removes devices after 30 seconds of inactivity
- **UWB Session Timeout**: Handles UWB session termination gracefully
- **Error Recovery**: Better error handling and recovery mechanisms
- **Memory Management**: Efficient array-based device tracking

### 4. Debugging and Monitoring
- **Detailed Status Reports**: Periodic status updates every 5 seconds
- **Device Information**: Shows device addresses, IDs, and session status
- **Activity Timestamps**: Tracks when each device was last active
- **Connection Counts**: Shows total connected vs active session counts

## Configuration

### Device Limits
```cpp
#define MAX_CONNECTED_DEVICES 8      // Maximum simultaneous connections
#define CONNECTION_TIMEOUT 30000     // 30 seconds timeout
#define HEARTBEAT_INTERVAL 5000      // 5 seconds status updates
```

### Device States
- **DISCONNECTED**: Device not connected
- **CONNECTED**: BLE connected but no UWB session
- **SESSION_ACTIVE**: UWB session established
- **RANGING**: Actively receiving ranging data
- **ERROR**: Device in error state

## Usage

### Connecting Multiple Phones
1. **First Phone**: Connects and initializes UWB stack
2. **Additional Phones**: Connect and establish individual UWB sessions
3. **Automatic Management**: System handles all connections automatically

### Monitoring Connections
The Arduino will output detailed status information:
```
=== Device Status ===
Total connected devices: 3
Active UWB sessions: 2
UWB initialized: YES
Connected devices:
  0: AA:BB:CC:DD:EE:FF (ID: 1) - Active: YES, Session: YES, Last activity: 2s ago
  1: 11:22:33:44:55:66 (ID: 2) - Active: YES, Session: YES, Last activity: 1s ago
  2: FF:EE:DD:CC:BB:AA (ID: 3) - Active: YES, Session: NO, Last activity: 5s ago
===================
```

### Ranging Data
Each device's ranging data is processed independently:
```
GOT RANGING DATA - Type: 1
Distance: 48
```

## Benefits for iOS App

### 1. Stable Connections
- **Reduced Disconnections**: Better connection management reduces `uwb_bus_deinit` events
- **Session Persistence**: UWB sessions remain active even with multiple devices
- **Automatic Recovery**: System recovers from connection issues automatically

### 2. Better Performance
- **Efficient Polling**: Optimized BLE stack polling
- **Memory Efficiency**: Compact device tracking structure
- **Reduced Latency**: Faster connection and session establishment

### 3. Enhanced Debugging
- **Clear Status**: Easy to see which devices are connected and ranging
- **Activity Tracking**: Identify devices that may have connection issues
- **Session Monitoring**: Track UWB session status per device

## Troubleshooting

### Common Issues

1. **"Maximum number of connected devices reached"**
   - Increase `MAX_CONNECTED_DEVICES` if needed
   - Check for stale connections that need cleanup

2. **"Device timed out - removing"**
   - Device was inactive for 30 seconds
   - Normal behavior for disconnected devices

3. **"UWB stack stopped"**
   - Occurs when all devices disconnect
   - UWB will restart when new device connects

### Debug Commands
- Monitor Serial output for detailed status
- Check device activity timestamps
- Verify UWB session status per device

## Performance Considerations

### Memory Usage
- **Device Array**: ~64 bytes per device (8 devices = 512 bytes)
- **String Storage**: Device addresses stored as strings
- **Activity Tracking**: Timestamp storage per device

### Processing Overhead
- **Cleanup Loop**: Runs every 100ms, minimal impact
- **Status Updates**: Every 5 seconds, very low overhead
- **BLE Polling**: Standard StellaUWB polling frequency

## Future Enhancements

### Potential Improvements
1. **Connection Quality Metrics**: RSSI-based quality assessment
2. **Priority Device Support**: Designate primary/secondary devices
3. **Data Aggregation**: Combine ranging data from multiple devices
4. **Power Management**: Optimize for battery-powered operation
5. **OTA Updates**: Over-the-air firmware updates

### Configuration Options
- **Dynamic Device Limits**: Runtime configuration of max devices
- **Custom Timeouts**: Per-device timeout settings
- **Quality Thresholds**: Connection quality-based decisions 