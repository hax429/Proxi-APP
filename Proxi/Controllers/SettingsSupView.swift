//
//  SettingsSupView.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/20/25.
//

import SwiftUI
import PhotosUI
import MessageUI
import UserNotifications

// MARK: - Placeholder Views for Sheets
struct ProfileView: View {
    @EnvironmentObject var userManager: UserManager
    @State private var editingName = false
    @State private var tempName = ""
    @State private var selectedImage: PhotosPickerItem?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Edit Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Profile Image Section
                        VStack(spacing: 16) {
                            PhotosPicker(selection: $selectedImage,
                                        matching: .images,
                                        photoLibrary: .shared()) {
                                if let profileImage = userManager.getProfileImage() {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.blue, lineWidth: 3)
                                        )
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 120, height: 120)
                                        
                                        VStack {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 30))
                                                .foregroundColor(.gray)
                                            Text("Add Photo")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                            .onChange(of: selectedImage) { newItem in
                                Task {
                                    if let newItem = newItem {
                                        if let data = try? await newItem.loadTransferable(type: Data.self),
                                           let image = UIImage(data: data) {
                                            DispatchQueue.main.async {
                                                _ = userManager.setProfileImage(image)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            Text("Tap to change photo")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Name Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Display Name")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if editingName {
                                VStack(spacing: 12) {
                                    TextField("Enter your name", text: $tempName)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .foregroundColor(.black)
                                    
                                    HStack(spacing: 12) {
                                        Button("Save") {
                                            userManager.updateProfile(name: tempName)
                                            editingName = false
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.blue)
                                        .cornerRadius(8)
                                        .disabled(tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                        
                                        Button("Cancel") {
                                            tempName = userManager.userProfile?.name ?? ""
                                            editingName = false
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.gray)
                                        .cornerRadius(8)
                                    }
                                }
                            } else {
                                HStack {
                                    Text(userManager.userProfile?.name ?? "No name set")
                                        .font(.body)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Button("Edit") {
                                        tempName = userManager.userProfile?.name ?? ""
                                        editingName = true
                                    }
                                    .foregroundColor(.blue)
                                }
                                .padding()
                                .background(Color(hex: "232229"))
                                .cornerRadius(12)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            tempName = userManager.userProfile?.name ?? ""
        }
    }
}

struct NotificationsView: View {
    @State private var showingScheduleNotification = false
    @State private var scheduledNotifications: [ScheduledNotification] = []
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Back") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Notifications")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Add") {
                        showingScheduleNotification = true
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Scheduled Notifications Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Scheduled Notifications")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            if scheduledNotifications.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "bell.slash")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    
                                    Text("No scheduled notifications")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    Text("Tap 'Add' to create your first notification")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                ForEach(scheduledNotifications) { notification in
                                    NotificationRowView(
                                        notification: notification,
                                        onDelete: { deleteNotification(notification) },
                                        onToggle: { toggleNotification(notification) }
                                    )
                                }
                            }
                        }
                        .padding()
                        .background(Color(hex: "232229"))
                        .cornerRadius(12)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingScheduleNotification) {
            ScheduleNotificationView { notification in
                addNotification(notification)
            }
        }
        .onAppear {
            loadNotifications()
            requestNotificationPermission()
        }
    }
    
    private func loadNotifications() {
        if let data = UserDefaults.standard.data(forKey: "scheduledNotifications"),
           let notifications = try? JSONDecoder().decode([ScheduledNotification].self, from: data) {
            scheduledNotifications = notifications
        }
    }
    
    private func saveNotifications() {
        if let data = try? JSONEncoder().encode(scheduledNotifications) {
            UserDefaults.standard.set(data, forKey: "scheduledNotifications")
        }
    }
    
    private func addNotification(_ notification: ScheduledNotification) {
        scheduledNotifications.append(notification)
        saveNotifications()
        scheduleLocalNotification(notification)
    }
    
    private func deleteNotification(_ notification: ScheduledNotification) {
        scheduledNotifications.removeAll { $0.id == notification.id }
        saveNotifications()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notification.id.uuidString])
    }
    
    private func toggleNotification(_ notification: ScheduledNotification) {
        if let index = scheduledNotifications.firstIndex(where: { $0.id == notification.id }) {
            scheduledNotifications[index].isEnabled.toggle()
            saveNotifications()
            
            if scheduledNotifications[index].isEnabled {
                scheduleLocalNotification(scheduledNotifications[index])
            } else {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notification.id.uuidString])
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    private func scheduleLocalNotification(_ notification: ScheduledNotification) {
        let content = UNMutableNotificationContent()
        content.title = "Proxi Reminder"
        content.body = notification.message
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = Calendar.current.component(.hour, from: notification.time)
        dateComponents.minute = Calendar.current.component(.minute, from: notification.time)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: notification.repeats)
        let request = UNNotificationRequest(identifier: notification.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}

struct PrivacyView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Text("Privacy & Security")
                    .font(.title)
                    .foregroundColor(.white)
                Text("Privacy settings coming soon...")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

struct AboutView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("About Proxi")
                    .font(.title)
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    Text("Version 1.0.0")
                        .foregroundColor(.white.opacity(0.7))
                    Text("© 2024 Proxi Team")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

struct DirectionOverrideView: View {
    @State private var selectedAngle: Double = UserDefaults.standard.double(forKey: "forcedDirectionAngle")
    @State private var isDirectionOverrideEnabled: Bool = UserDefaults.standard.bool(forKey: "isDirectionOverrideEnabled")
    @State private var angleText: String = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Direction Override")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Enable/Disable Toggle
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Override Direction")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Toggle("Enable Direction Override", isOn: $isDirectionOverrideEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .onChange(of: isDirectionOverrideEnabled) { value in
                                    UserDefaults.standard.set(value, forKey: "isDirectionOverrideEnabled")
                                }
                        }
                        .padding()
                        .background(Color(hex: "232229"))
                        .cornerRadius(12)
                        
                        if isDirectionOverrideEnabled {
                            // Compass Interface
                            VStack(spacing: 24) {
                                Text("Set Direction")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                // Compass Circle
                                ZStack {
                                    // Outer circle
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                        .frame(width: 250, height: 250)
                                    
                                    // Degree markings
                                    ForEach(0..<12) { i in
                                        Rectangle()
                                            .fill(Color.white.opacity(0.6))
                                            .frame(width: 2, height: 15)
                                            .offset(y: -117.5)
                                            .rotationEffect(.degrees(Double(i) * 30))
                                    }
                                    
                                    // Cardinal directions
                                    VStack {
                                        Text("N")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                            .offset(y: -100)
                                        Spacer()
                                        Text("S")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                            .offset(y: 100)
                                    }
                                    .frame(height: 250)
                                    
                                    HStack {
                                        Text("W")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                            .offset(x: -100)
                                        Spacer()
                                        Text("E")
                                            .foregroundColor(.white)
                                            .font(.headline)
                                            .offset(x: 100)
                                    }
                                    .frame(width: 250)
                                    
                                    // Direction Arrow
                                    Image(systemName: "location.north.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.red)
                                        .offset(y: -90)
                                        .rotationEffect(.degrees(selectedAngle))
                                        .animation(.easeInOut(duration: 0.3), value: selectedAngle)
                                    
                                    // Center dot
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 8, height: 8)
                                }
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let center = CGPoint(x: 125, y: 125)
                                            let angle = atan2(value.location.y - center.y, value.location.x - center.x)
                                            let degrees = angle * 180 / .pi + 90
                                            selectedAngle = degrees < 0 ? degrees + 360 : degrees
                                            angleText = String(format: "%.0f", selectedAngle)
                                            UserDefaults.standard.set(selectedAngle, forKey: "forcedDirectionAngle")
                                        }
                                )
                                
                                // Angle Display and Input
                                VStack(spacing: 16) {
                                    Text("\(String(format: "%.0f", selectedAngle))°")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                    
                                    HStack {
                                        Text("Manual Input:")
                                            .foregroundColor(.white)
                                        
                                        TextField("0-359", text: $angleText)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .keyboardType(.numberPad)
                                            .frame(width: 80)
                                            .onSubmit {
                                                if let angle = Double(angleText), angle >= 0, angle <= 359 {
                                                    selectedAngle = angle
                                                    UserDefaults.standard.set(selectedAngle, forKey: "forcedDirectionAngle")
                                                }
                                            }
                                        
                                        Button("Set") {
                                            if let angle = Double(angleText), angle >= 0, angle <= 359 {
                                                selectedAngle = angle
                                                UserDefaults.standard.set(selectedAngle, forKey: "forcedDirectionAngle")
                                            }
                                        }
                                        .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(hex: "232229"))
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            angleText = String(format: "%.0f", selectedAngle)
        }
    }
}

struct CalibrationView: View {
    @State private var calibrationOffset: String = {
        let offset = UserDefaults.standard.double(forKey: "distanceCalibrationOffset")
        return String(format: "%.0f", offset)
    }()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Distance Calibration")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Done") {
                        // Save the calibration offset
                        if let offset = Double(calibrationOffset) {
                            UserDefaults.standard.set(offset, forKey: "distanceCalibrationOffset")
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Explanation Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Calibration Adjustment")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("Adjust the distance reading by a fixed number of centimeters. Positive values increase the displayed distance, negative values decrease it.")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                        .background(Color(hex: "232229"))
                        .cornerRadius(12)
                        
                        // Calibration Input Section
                        VStack(spacing: 24) {
                            Text("Adjustment Value")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(spacing: 16) {
                                Text("Enter centimeters to add/subtract:")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                HStack(spacing: 16) {
                                    TextField("0", text: $calibrationOffset)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .keyboardType(.numbersAndPunctuation)
                                        .frame(width: 120)
                                        .multilineTextAlignment(.center)
                                        .font(.title2)
                                    
                                    Text("cm")
                                        .font(.title2)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                VStack(spacing: 8) {
                                    Text("Current Adjustment:")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    if let offset = Double(calibrationOffset) {
                                        Text("\(offset > 0 ? "+" : "")\(String(format: "%.0f", offset)) cm")
                                            .font(.headline)
                                            .foregroundColor(offset > 0 ? .green : offset < 0 ? .orange : .white)
                                    } else {
                                        Text("Invalid input")
                                            .font(.headline)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(hex: "232229"))
                        .cornerRadius(12)
                        
                        // Quick Adjustment Buttons
                        VStack(spacing: 16) {
                            Text("Quick Adjustments")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                ForEach([-10, -5, -1, 0, 1, 5, 10], id: \.self) { value in
                                    Button(action: {
                                        calibrationOffset = String(value)
                                    }) {
                                        Text("\(value > 0 ? "+" : "")\(value) cm")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(value == 0 ? Color.gray.opacity(0.3) : Color.blue.opacity(0.6))
                                            )
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(hex: "232229"))
                        .cornerRadius(12)
                        
                        // Example Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Examples")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("•")
                                        .foregroundColor(.blue)
                                    Text("Actual: 100cm, Adjustment: +5cm → Display: 105cm")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                HStack {
                                    Text("•")
                                        .foregroundColor(.orange)
                                    Text("Actual: 50cm, Adjustment: -10cm → Display: 40cm")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                HStack {
                                    Text("•")
                                        .foregroundColor(.red)
                                    Text("If result < 0cm → Display: 0cm")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        .padding()
                        .background(Color(hex: "232229"))
                        .cornerRadius(12)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }
}

//MARK: Profile selection


struct ProfileSettingsView: View {
    @StateObject private var userManager = UserManager()
    @State private var editingName = false
    @State private var tempName = ""
    @State private var selectedImage: PhotosPickerItem?
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Image Section
            VStack {
                PhotosPicker(selection: $selectedImage,
                            matching: .images,
                            photoLibrary: .shared()) {
                    if let profileImage = userManager.getProfileImage() {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue, lineWidth: 3)
                            )
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 120, height: 120)
                            
                            VStack {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                                Text("Add Photo")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .onChange(of: selectedImage) { newItem in
                    Task {
                        if let newItem = newItem {
                            if let data = try? await newItem.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    _ = userManager.setProfileImage(image)
                                }
                            }
                        }
                    }
                }
                
                Text("Tap to change photo")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Name Section
            VStack(alignment: .leading) {
                Text("Name")
                    .font(.headline)
                
                if editingName {
                    HStack {
                        TextField("Enter your name", text: $tempName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Save") {
                            userManager.updateProfile(name: tempName)
                            editingName = false
                        }
                        .disabled(tempName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Button("Cancel") {
                            tempName = userManager.userProfile?.name ?? ""
                            editingName = false
                        }
                    }
                } else {
                    HStack {
                        Text(userManager.userProfile?.name ?? "")
                            .font(.body)
                        
                        Spacer()
                        
                        Button("Edit") {
                            tempName = userManager.userProfile?.name ?? ""
                            editingName = true
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Profile Settings")
        .onAppear {
            tempName = userManager.userProfile?.name ?? ""
        }
    }
}


// MARK: - Mail Composer Views
struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients(recipients)
        mailComposer.setSubject(subject)
        return mailComposer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct MailUnavailableView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.red)
                
                Text("Mail Not Available")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Please configure your Mail app or contact us directly at:")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Text("superkatiebros@gmail.com")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .onTapGesture {
                        UIPasteboard.general.string = "superkatiebros@gmail.com"
                    }
                
                Text("Tap email to copy")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}


// MARK: - Notification Models and Views

struct ScheduledNotification: Identifiable, Codable {
    let id = UUID()
    var time: Date
    var message: String
    var isEnabled: Bool = true
    var repeats: Bool = false
}

struct NotificationRowView: View {
    let notification: ScheduledNotification
    let onDelete: () -> Void
    let onToggle: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.message)
                    .font(.body)
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                HStack {
                    Text(DateFormatter.timeFormatter.string(from: notification.time))
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    if notification.repeats {
                        Image(systemName: "repeat")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            VStack {
                Toggle("", isOn: Binding(
                    get: { notification.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(8)
    }
}

struct ScheduleNotificationView: View {
    @State private var selectedTime = Date()
    @State private var notificationMessage = ""
    @State private var repeatsDaily = false
    @Environment(\.presentationMode) var presentationMode
    
    let onSave: (ScheduledNotification) -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("Schedule Notification")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button("Save") {
                        let notification = ScheduledNotification(
                            time: selectedTime,
                            message: notificationMessage,
                            repeats: repeatsDaily
                        )
                        onSave(notification)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.blue)
                    .disabled(notificationMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Time Selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Notification Time")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(WheelDatePickerStyle())
                                .labelsHidden()
                                .colorScheme(.dark)
                        }
                        .padding()
                        .background(Color(hex: "232229"))
                        .cornerRadius(12)
                        
                        // Message Input
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Notification Message")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            TextField("Enter your reminder message...", text: $notificationMessage, axis: .vertical)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .lineLimit(3...6)
                        }
                        .padding()
                        .background(Color(hex: "232229"))
                        .cornerRadius(12)
                        
                        // Repeat Option
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Repeat Settings")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Toggle("Repeat Daily", isOn: $repeatsDaily)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color(hex: "232229"))
                        .cornerRadius(12)
                        
                        // Preview
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Preview")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "bell")
                                        .foregroundColor(.blue)
                                    Text("Proxi Reminder")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                
                                Text(notificationMessage.isEmpty ? "Your reminder message will appear here" : notificationMessage)
                                    .font(.body)
                                    .foregroundColor(notificationMessage.isEmpty ? .white.opacity(0.5) : .white)
                                    .italic(notificationMessage.isEmpty)
                                
                                HStack {
                                    Text(DateFormatter.timeFormatter.string(from: selectedTime))
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    
                                    if repeatsDaily {
                                        Text("• Daily")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                        }
                        .padding()
                        .background(Color(hex: "232229"))
                        .cornerRadius(12)
                        
                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

//MARK: Setting Extensions

