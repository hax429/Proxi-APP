#include <ArduinoBLE.h>
#include <StellaUWB.h>

// Enhanced multi-device support
#define MAX_CONNECTED_DEVICES 8
#define HEARTBEAT_INTERVAL 5000  // 5 seconds
#define CONNECTION_TIMEOUT 30000  // 30 seconds

// Device tracking structure
struct ConnectedDevice {
  BLEDevice device;
  String address;
  bool isActive;
  unsigned long lastActivity;
  bool hasActiveSession;
  uint8_t deviceId;
};

// Global variables for multi-device support
ConnectedDevice connectedDevices[MAX_CONNECTED_DEVICES];
uint8_t deviceCount = 0;
bool uwbInitialized = false;
unsigned long lastHeartbeat = 0;

// Device ID counter for unique identification
uint8_t nextDeviceId = 1;

/**
 * @brief Find device in connected devices array
 * @param address Device BLE address
 * @return Index of device or -1 if not found
 */
int findDeviceIndex(String address) {
  for (int i = 0; i < deviceCount; i++) {
    if (connectedDevices[i].address == address) {
      return i;
    }
  }
  return -1;
}

/**
 * @brief Add new device to connected devices array
 * @param dev BLE device to add
 * @return true if successfully added, false if array is full
 */
bool addDevice(BLEDevice dev) {
  if (deviceCount >= MAX_CONNECTED_DEVICES) {
    Serial.println("ERROR: Maximum number of connected devices reached");
    return false;
  }
  
  String address = dev.address();
  connectedDevices[deviceCount].device = dev;
  connectedDevices[deviceCount].address = address;
  connectedDevices[deviceCount].isActive = true;
  connectedDevices[deviceCount].lastActivity = millis();
  connectedDevices[deviceCount].hasActiveSession = false;
  connectedDevices[deviceCount].deviceId = nextDeviceId++;
  
  Serial.print("Added device ");
  Serial.print(deviceCount);
  Serial.print(": ");
  Serial.print(address);
  Serial.print(" (ID: ");
  Serial.print(connectedDevices[deviceCount].deviceId);
  Serial.println(")");
  
  deviceCount++;
  return true;
}

/**
 * @brief Remove device from connected devices array
 * @param address Device BLE address
 */
void removeDevice(String address) {
  int index = findDeviceIndex(address);
  if (index == -1) {
    Serial.print("WARNING: Device not found for removal: ");
    Serial.println(address);
    return;
  }
  
  Serial.print("Removing device ");
  Serial.print(index);
  Serial.print(": ");
  Serial.print(address);
  Serial.print(" (ID: ");
  Serial.print(connectedDevices[index].deviceId);
  Serial.println(")");
  
  // Shift remaining devices to fill the gap
  for (int i = index; i < deviceCount - 1; i++) {
    connectedDevices[i] = connectedDevices[i + 1];
  }
  
  deviceCount--;
  
  // Reset device ID counter if all devices disconnected
  if (deviceCount == 0) {
    nextDeviceId = 1;
  }
}

/**
 * @brief Update device activity timestamp
 * @param address Device BLE address
 */
void updateDeviceActivity(String address) {
  int index = findDeviceIndex(address);
  if (index != -1) {
    connectedDevices[index].lastActivity = millis();
  }
}

/**
 * @brief Check for inactive devices and clean them up
 */
void cleanupInactiveDevices() {
  unsigned long currentTime = millis();
  
  for (int i = deviceCount - 1; i >= 0; i--) {
    if (currentTime - connectedDevices[i].lastActivity > CONNECTION_TIMEOUT) {
      Serial.print("Device ");
      Serial.print(connectedDevices[i].address);
      Serial.println(" timed out - removing");
      removeDevice(connectedDevices[i].address);
    }
  }
}

/**
 * @brief Get number of active devices
 * @return Number of devices with active sessions
 */
uint8_t getActiveDeviceCount() {
  uint8_t activeCount = 0;
  for (int i = 0; i < deviceCount; i++) {
    if (connectedDevices[i].hasActiveSession) {
      activeCount++;
    }
  }
  return activeCount;
}

/**
 * @brief notification handler for ranging data
 * @param rangingData the received data
 */
void rangingHandler(UWBRangingData &rangingData) {
  Serial.print("GOT RANGING DATA - Type: ");
  Serial.println(rangingData.measureType());

  //nearby interaction is based on Double-sided Two-way Ranging method
  if(rangingData.measureType()==(uint8_t)uwb::MeasurementType::TWO_WAY) {
    //get the TWR (Two-Way Ranging) measurements
    RangingMeasures twr=rangingData.twoWayRangingMeasure();
    //loop for the number of available measurements
    for(int j=0;j<rangingData.available();j++) {
      //if the measure is valid
      if(twr[j].status==0 && twr[j].distance!=0xFFFF) {
        //print the measure
        Serial.print("Distance: ");
        Serial.println(twr[j].distance);
      }
    }
  }
}

/**
 * @brief callback invoked when a BLE client connects
 * @param dev the client BLE device
 */
void clientConnected(BLEDevice dev) {
  Serial.print("BLE Client connected: ");
  Serial.println(dev.address());
  
  // Add device to tracking array
  if (!addDevice(dev)) {
    Serial.println("ERROR: Failed to add device - maximum connections reached");
    return;
  }
  
  // Initialize UWB stack upon first connection
  if (deviceCount == 1) {
    Serial.println("First device connected - initializing UWB stack...");
    if (!uwbInitialized) {
      UWB.begin();
      uwbInitialized = true;
      Serial.println("UWB stack initialized successfully");
    }
  }
  
  Serial.print("Total connected devices: ");
  Serial.println(deviceCount);
}

/**
 * @brief callback for BLE client disconnection
 * @param dev 
 */
void clientDisconnected(BLEDevice dev) {
  Serial.print("BLE Client disconnected: ");
  Serial.println(dev.address());
  
  // Remove device from tracking array
  removeDevice(dev.address());
  
  Serial.print("Remaining connected devices: ");
  Serial.println(deviceCount);
  
  // Deinitialize UWB stack if no devices are connected
  if(deviceCount == 0) {
    Serial.println("No devices connected, stopping UWB...");
    if (uwbInitialized) {
      UWB.end();
      uwbInitialized = false;
      Serial.println("UWB stack stopped");
    }
  }
}

/**
 * @brief callback for when a UWB session with a client is started
 * @param dev 
 */
void sessionStarted(BLEDevice dev) {
  String address = dev.address();
  Serial.print("UWB Session started with: ");
  Serial.println(address);
  
  // Update device session status
  int index = findDeviceIndex(address);
  if (index != -1) {
    connectedDevices[index].hasActiveSession = true;
    connectedDevices[index].lastActivity = millis();
    Serial.print("Device ");
    Serial.print(connectedDevices[index].deviceId);
    Serial.println(" now has active UWB session");
  }
  
  Serial.print("Active UWB sessions: ");
  Serial.println(getActiveDeviceCount());
}

/**
 * @brief callback for when a UWB session with a client is terminated
 * @param dev 
 */
void sessionStopped(BLEDevice dev) {
  String address = dev.address();
  Serial.print("UWB Session stopped with: ");
  Serial.println(address);
  
  // Update device session status
  int index = findDeviceIndex(address);
  if (index != -1) {
    connectedDevices[index].hasActiveSession = false;
    Serial.print("Device ");
    Serial.print(connectedDevices[index].deviceId);
    Serial.println(" UWB session terminated");
  }
  
  Serial.print("Active UWB sessions: ");
  Serial.println(getActiveDeviceCount());
}

/**
 * @brief Print detailed status information
 */
void printStatus() {
  Serial.println("=== Device Status ===");
  Serial.print("Total connected devices: ");
  Serial.println(deviceCount);
  Serial.print("Active UWB sessions: ");
  Serial.println(getActiveDeviceCount());
  Serial.print("UWB initialized: ");
  Serial.println(uwbInitialized ? "YES" : "NO");
  
  if (deviceCount > 0) {
    Serial.println("Connected devices:");
    for (int i = 0; i < deviceCount; i++) {
      Serial.print("  ");
      Serial.print(i);
      Serial.print(": ");
      Serial.print(connectedDevices[i].address);
      Serial.print(" (ID: ");
      Serial.print(connectedDevices[i].deviceId);
      Serial.print(") - Active: ");
      Serial.print(connectedDevices[i].isActive ? "YES" : "NO");
      Serial.print(", Session: ");
      Serial.print(connectedDevices[i].hasActiveSession ? "YES" : "NO");
      Serial.print(", Last activity: ");
      Serial.print((millis() - connectedDevices[i].lastActivity) / 1000);
      Serial.println("s ago");
    }
  }
  Serial.println("===================");
}

void setup() {
  Serial.begin(115200);
  while (!Serial) {
    ; // Wait for serial port to connect
  }
  
  Serial.println("=== Proxi Arduino UWB Device (Multi-Device Enhanced) ===");
  Serial.println("Initializing...");

#if defined(ARDUINO_PORTENTA_C33)
  /* Only the Portenta C33 has an RGB LED. */
  pinMode(LEDR, OUTPUT);
  digitalWrite(LEDR, LOW);
  Serial.println("Portenta C33 detected");
#endif

  Serial.println("Starting enhanced nearby interaction app...");
  Serial.print("Maximum supported devices: ");
  Serial.println(MAX_CONNECTED_DEVICES);

  // Initialize device tracking array
  for (int i = 0; i < MAX_CONNECTED_DEVICES; i++) {
    connectedDevices[i].isActive = false;
    connectedDevices[i].hasActiveSession = false;
    connectedDevices[i].lastActivity = 0;
  }

  //register the callback for ranging data
  UWB.registerRangingCallback(rangingHandler);
  
  //register the callback for client connection/disconnection events
  UWBNearbySessionManager.onConnect(clientConnected);
  UWBNearbySessionManager.onDisconnect(clientDisconnected);

  //register the callbacks for client session start and stop events
  UWBNearbySessionManager.onSessionStart(sessionStarted);
  UWBNearbySessionManager.onSessionStop(sessionStopped);

  //init the BLE services and characteristic, advertise with device name
  UWBNearbySessionManager.begin("Gabriel's Pilot");
  Serial.println("BLE services initialized successfully");
  Serial.println("Advertising as 'Gabriel's Pilot'");
  
  Serial.println("Setup complete. Waiting for connections...");
}

void loop() {
  delay(100);
  
  //poll the BLE stack
  UWBNearbySessionManager.poll();
  
  // Clean up inactive devices
  cleanupInactiveDevices();
  
  // Periodic status updates
  if (millis() - lastHeartbeat > HEARTBEAT_INTERVAL) {
    printStatus();
    lastHeartbeat = millis();
  }
} 