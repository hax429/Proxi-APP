import SwiftUI
import CoreBluetooth
import MessageUI

struct SettingsView: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var bleManager: BLEManager
    @State var showingDebugLog = false
    @State var showingProfile = false
    @State var showingNotifications = false
    @State var showingPrivacy = false
    @State var showingMailComposer = false
    @State var displayName: String = SettingsView.loadDisplayName()
    @State var editingDisplayName: Bool = false
    @State var tempDisplayName: String = ""
    @FocusState var isEditingName: Bool
    @Binding var isSidebarOpen: Bool
    
    // Developer options state
    @State var versionClickCount: Int = 0
//    @State private var isDeveloperModeEnabled: Bool = UserDefaults.standard.bool(forKey: "isDeveloperModeEnabled")
    @State var isDeveloperModeEnabled: Bool = false

    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                TopBarView(selectedTab: $selectedTab, isSidebarOpen:$isSidebarOpen)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Section
                        profileSection
                        
                        // Device Management Section
                        deviceManagementSection
                        
                        // App Settings Section
                        appSettingsSection
                        
                        // Support Section
                        supportSection
                        
                        // Debug Section (conditionally shown)
                        if isDeveloperModeEnabled {
                            debugSection
                        }
                        
                        // Version Section
                        versionSection
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingDebugLog) {
            DebugLogView(debugLog: bleManager.debugLog)
        }
        .sheet(isPresented: $showingProfile) {
            ProfileView()
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyView()
        }
        .sheet(isPresented: $showingMailComposer) {
            if MFMailComposeViewController.canSendMail() {
                MailComposeView(
                    recipients: ["superkatiebros@gmail.com"],
                    subject: "Proxi Support"
                )
            } else {
                MailUnavailableView()
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(selectedTab: Binding.constant(4), isSidebarOpen: Binding.constant(false))
    }
}

