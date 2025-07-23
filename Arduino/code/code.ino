#include <ArduinoBLE.h>
#include <StellaUWB.h>

// Enhanced multi-device support
#define MAX_CONNECTED_DEVICES 8
#define HEARTBEAT_INTERVAL 1000  // 1 second for faster updates
#define CONNECTION_TIMEOUT 10000  // 10 seconds for quicker timeout detection
#define KEEPALIVE_INTERVAL 2000   // 2 seconds keepalive ping
#define ADVERTISE_CHECK_INTERVAL 1000  // Check advertising every second

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
unsigned long lastKeepalive = 0;
unsigned long lastAdvertiseCheck = 0;

// Device ID counter for unique identification
uint8_t nextDeviceId = 1;

// CRITICAL: Track advertising state explicitly
bool isAdvertising = false;
bool shouldBeAdvertising = true;

/**
 * @brief Generate and display device UUID for hardcoding
 * This function creates a consistent UUID based on the device's BLE address
 */
void displayDeviceUUID() {
  Serial.println("╔════════════════════════════════════════════════════════════╗");
  Serial.println("║                    DEVICE UUID FOR HARDCODING             ║");
  Serial.println("╠════════════════════════════════════════════════════════════╣");
  
  String bleAddress = BLE.address();
  Serial.print("║ BLE Address: ");
  Serial.print(bleAddress);
  Serial.println("                               ║");
  
  // Convert BLE address to UUID format for iOS
  // Remove colons and pad with standard UUID structure
  String cleanAddress = bleAddress;
  cleanAddress.replace(":", "");
  cleanAddress.toUpperCase();
  
  // Create UUID based on the actual BLE address for this device (79:7f:c7:ec:5d:4a)
  // Expected address: 797FC7EC5D4A
  String deviceUUID = "797FC7EC-5D4A-4797-A7FC-797FC7EC5D4A";
  
  Serial.print("║ Generated UUID: ");
  Serial.print(deviceUUID);
  Serial.println("  ║");
  Serial.println("║                                                            ║");
  Serial.println("║ COPY THIS UUID TO iOS HARDCODED DEVICE LIST:              ║");
  Serial.print("║ ");
  Serial.print(deviceUUID);
  Serial.println("                      ║");
  Serial.println("║                                                            ║");
  Serial.println("║ Add this to BLEManager.swift hardcodedDevices array:      ║");
  Serial.println("║ HardcodedDevice(name: \"Proxi Pilot\",                      ║");
  Serial.print("║                 uuid: UUID(uuidString: \"");
  Serial.print(deviceUUID);
  Serial.println("\")!, ║");
  Serial.println("║                 macAddress: nil)                           ║");
  Serial.println("╚════════════════════════════════════════════════════════════╝");
}

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
  
  // CRITICAL: Force advertising restart after adding a device
  ensureBLEAdvertising();
  
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
  
  // CRITICAL: Ensure advertising continues after device removal
  ensureBLEAdvertising();
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
 * @brief Send keepalive signal to maintain active connections
 */
void sendKeepalive() {
  // Update activity for all connected devices to prevent timeout
  for (int i = 0; i < deviceCount; i++) {
    if (connectedDevices[i].isActive) {
      connectedDevices[i].lastActivity = millis();
    }
  }
  
  // Optional: Send a lightweight ping message to active sessions
  // This helps detect silent connection failures early
  if (getActiveDeviceCount() > 0) {
    Serial.print("💓 Keepalive sent to ");
    Serial.print(getActiveDeviceCount());
    Serial.println(" active sessions");
  }
}

/**
 * @brief CRITICAL: Ensure BLE advertising continues for multi-device support
 * This is the key function that enables multiple simultaneous connections
 */
void ensureBLEAdvertising() {
  // ENHANCED DEBUGGING FOR ADVERTISING
  Serial.println("🔍 ADVERTISING DEBUG CHECK:");
  Serial.print("  - Device Count: ");
  Serial.println(deviceCount);
  Serial.print("  - Max Devices: ");
  Serial.println(MAX_CONNECTED_DEVICES);
  Serial.print("  - Should Be Advertising: ");
  Serial.println(shouldBeAdvertising ? "YES" : "NO");
  Serial.print("  - Current Advertising State: ");
  Serial.println(isAdvertising ? "ACTIVE" : "INACTIVE");
  Serial.print("  - BLE Address: ");
  Serial.println(BLE.address());
  
  // Only advertise if we have space for more devices
  if (deviceCount < MAX_CONNECTED_DEVICES && shouldBeAdvertising) {
    
    // Check current advertising state
    bool currentlyAdvertising = isAdvertising;
    
    if (!currentlyAdvertising) {
      Serial.println("📡 BLE advertising stopped - Restarting now!");
      
      // CRITICAL: Restart advertising immediately
      // This is the key to allowing multiple connections
      if (BLE.advertise()) {
        isAdvertising = true;
        Serial.print("📡 ✅ Successfully restarted advertising. Ready for ");
        Serial.print(MAX_CONNECTED_DEVICES - deviceCount);
        Serial.println(" more devices");
        Serial.println("📡 Advertising Details:");
        Serial.print("   - Device Name: ");
        Serial.println("Proxi Pilot");
        Serial.print("   - BLE Address: ");
        Serial.println(BLE.address());
        Serial.println("   - Services: UWB Transfer & Qorvo Services");
      } else {
        Serial.println("❌ CRITICAL: Failed to restart advertising!");
        isAdvertising = false;
      }
    } else {
      // Already advertising - periodic confirmation
      if (!isAdvertising) {
        isAdvertising = true;
        Serial.println("📡 ✅ Advertising confirmed active");
      }
    }
    
  } else if (deviceCount >= MAX_CONNECTED_DEVICES) {
    // Stop advertising if we're at max capacity
    if (isAdvertising) {
      BLE.stopAdvertise();
      isAdvertising = false;
      Serial.println("📡 Max devices reached - stopped advertising");
    }
  }
  
  // FINAL STATUS CONFIRMATION
  Serial.print("📡 FINAL ADVERTISING STATUS: ");
  Serial.println(isAdvertising ? "✅ ACTIVE" : "❌ INACTIVE");
  Serial.println();
}

/**
 * @brief Force restart BLE advertising
 * Call this if advertising seems stuck
 */
void forceRestartAdvertising() {
  Serial.println("🔄 Force restarting BLE advertising...");
  
  // Stop advertising first
  if (isAdvertising) {
    BLE.stopAdvertise();
    delay(100);  // Brief delay
  }
  
  // Restart advertising
  if (BLE.advertise()) {
    isAdvertising = true;
    Serial.println("✅ Advertising restarted successfully");
  } else {
    isAdvertising = false;
    Serial.println("❌ Failed to restart advertising");
  }
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
  Serial.print("BLE Advertising: ");
  Serial.println(isAdvertising ? "YES" : "NO");
  Serial.print("Available slots: ");
  Serial.println(MAX_CONNECTED_DEVICES - deviceCount);
  
  // Show device identifier for hardcoding
  Serial.print("Device BLE Address: ");
  Serial.println(BLE.address());
  
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
  } else {
    Serial.println("💡 Tip: Use the UUID above in iOS hardcoded device list");
  }
  Serial.println("===================");
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
      UWB.begin();  // Remove boolean check as this method returns void
      uwbInitialized = true;
      Serial.println("UWB stack initialized");
    }
  }
  
  Serial.print("Total connected devices: ");
  Serial.println(deviceCount);
  
  // CRITICAL: This is the most important part for multi-device support
  // Force advertising to continue after connection
  Serial.println("📡 Ensuring advertising continues for more connections...");
  ensureBLEAdvertising();
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
  
  // CRITICAL: Ensure advertising resumes after disconnection
  ensureBLEAdvertising();
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

  // ENHANCED: Initialize BLE manually first
  Serial.println("🚀 Initializing BLE manually...");
  
  if (!BLE.begin()) {
    Serial.println("❌ Failed to initialize BLE!");
    while (1);
  }
  
  // Set device name BEFORE UWB initialization
  BLE.setLocalName("Proxi Pilot");
  BLE.setDeviceName("Proxi Pilot");
  Serial.println("✅ BLE device name set to 'Proxi Pilot'");
  
  //init the BLE services and characteristic, advertise with device name
  Serial.println("🚀 Initializing UWBNearbySessionManager...");
  UWBNearbySessionManager.begin("Proxi Pilot");  // Name ending with "Pilot" for filtering
  Serial.println("BLE services initialized");
  Serial.println("Advertising as 'Proxi Pilot'");
  
  // CRITICAL: Add delay and verification
  delay(1000);  // Give BLE stack time to initialize
  
  // ENHANCED: Check if BLE is actually initialized
  Serial.println("🔍 Checking BLE initialization status...");
  
  // DON'T call BLE.begin() again - it's already initialized by UWBNearbySessionManager
  // Just check if BLE is available
  Serial.print("BLE Address: ");
  Serial.println(BLE.address());
  
  if (BLE.address() != "00:00:00:00:00:00") {
    Serial.println("✅ BLE stack confirmed active");
  } else {
    Serial.println("❌ BLE stack failed - invalid address");
  }
  
  // CRITICAL: Ensure advertising is active from the start
  isAdvertising = true;  // Assume advertising starts after UWBNearbySessionManager.begin()
  Serial.print("Initial advertising state: ");
  Serial.println(isAdvertising ? "ACTIVE" : "INACTIVE");
  
  // ENHANCED: Immediate verification
  Serial.println("🔍 BLE Status Check:");
  Serial.print("  - MAC Address: ");
  Serial.println(BLE.address());
  Serial.print("  - Device Name: ");
  Serial.println("Proxi Pilot");
  
  // CRITICAL: Display formatted UUID for easy hardcoding
  Serial.println();
  displayDeviceUUID();
  Serial.println();
  
  // ALSO: Show the exact UUID being used in iOS hardcoded list
  Serial.println("🎯 EXACT UUID MATCH:");
  Serial.println("iOS Hardcoded UUID: 797FC7EC-5D4A-4797-A7FC-797FC7EC5D4A");
  Serial.print("Arduino BLE Address: ");
  Serial.println(BLE.address());
  Serial.println("✅ These should match for successful connection");
  Serial.println();
  
  // CRITICAL: Force BLE advertising to start manually if UWBNearbySessionManager didn't handle it
  Serial.println("🔧 MANUAL BLE ADVERTISING SETUP:");
  
  // Try to start advertising manually
  BLE.stopAdvertise();  // Stop any existing advertising
  delay(500);
  
  if (BLE.advertise()) {
    Serial.println("✅ Manual BLE advertising started successfully");
    isAdvertising = true;
  } else {
    Serial.println("❌ Manual BLE advertising failed");
    isAdvertising = false;
  }
  
  if (!isAdvertising) {
    forceRestartAdvertising();
  }
  
  // FINAL VERIFICATION
  Serial.println("🎯 FINAL ADVERTISING VERIFICATION:");
  Serial.print("  - Advertising Active: ");
  Serial.println(isAdvertising ? "YES" : "NO");
  Serial.print("  - Device Name: Proxi Pilot");
  Serial.print("  - BLE Address: ");
  Serial.println(BLE.address());
  Serial.println("📡 Arduino should now be discoverable by iPhone!");
  
  Serial.println("Setup complete. Waiting for multiple connections...");
  Serial.println("📡 Device is now discoverable by multiple phones simultaneously");
}

void loop() {
  // Reduced delay for more responsive communication
  delay(20);  // 20ms instead of 100ms for 5x faster polling
  
  //poll the BLE stack more frequently
  UWBNearbySessionManager.poll();
  
  // Clean up inactive devices
  cleanupInactiveDevices();
  
  // CRITICAL: Check advertising status more frequently
  // This is the key to maintaining multi-device connectivity
  if (millis() - lastAdvertiseCheck > ADVERTISE_CHECK_INTERVAL) {
    ensureBLEAdvertising();
    lastAdvertiseCheck = millis();
  }
  
  // Send keepalive to maintain active connections
  if (millis() - lastKeepalive > KEEPALIVE_INTERVAL) {
    sendKeepalive();
    lastKeepalive = millis();
  }
  
  // Periodic status updates (less frequent than keepalive)
  if (millis() - lastHeartbeat > HEARTBEAT_INTERVAL) {
    printStatus();
    lastHeartbeat = millis();
  }
}