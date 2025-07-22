#ifndef CONFIG_H
#define CONFIG_H

// Multi-device configuration
#define MAX_CONNECTED_DEVICES 8
#define HEARTBEAT_INTERVAL 5000      // 5 seconds
#define CONNECTION_TIMEOUT 30000     // 30 seconds
#define UWB_SESSION_TIMEOUT 60000    // 60 seconds for UWB session timeout
#define MAX_DEVICE_NAME_LENGTH 32

// BLE Configuration
#define BLE_DEVICE_NAME "Gabriel's Pilot"
#define BLE_ADVERTISING_INTERVAL 100 // milliseconds

// UWB Configuration
#define UWB_RANGING_INTERVAL 100     // milliseconds between ranging measurements
#define UWB_MAX_RANGE 100            // maximum range in meters
#define UWB_MIN_RANGE 0.1            // minimum range in meters

// Debug Configuration
#define DEBUG_ENABLED true
#define DEBUG_LEVEL 2                // 0=off, 1=basic, 2=detailed, 3=verbose

// Performance Configuration
#define LOOP_DELAY 100               // milliseconds
#define STATUS_UPDATE_INTERVAL 5000  // milliseconds

// Error handling
#define MAX_RECONNECT_ATTEMPTS 3
#define RECONNECT_DELAY 1000         // milliseconds

// Device states
enum DeviceState {
  DEVICE_DISCONNECTED = 0,
  DEVICE_CONNECTED = 1,
  DEVICE_SESSION_ACTIVE = 2,
  DEVICE_RANGING = 3,
  DEVICE_ERROR = 4
};

// Connection quality levels
enum ConnectionQuality {
  QUALITY_POOR = 0,
  QUALITY_FAIR = 1,
  QUALITY_GOOD = 2,
  QUALITY_EXCELLENT = 3
};

#endif // CONFIG_H 