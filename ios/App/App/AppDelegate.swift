import UIKit
import SwiftUI
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let contentView = MeditationAppView()
        
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }

}

// MARK: - Native Background Timer Helper

class BackgroundTimer: ObservableObject {
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.goldenmeditation.timer", qos: .userInteractive)
    
    var onTick: (() -> Void)?
    
    func start() {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 1.0)
        t.setEventHandler {
            DispatchQueue.main.async {
                self.onTick?()
            }
        }
        t.resume()
        self.timer = t
    }
    
    func stop() {
        timer?.cancel()
        timer = nil
    }
}

// MARK: - Native SwiftUI Application UI

struct MeditationAppView: View {
    // Session State
    @State private var totalTime: TimeInterval = 15 * 60 // 15 mins default
    @State private var timeLeft: TimeInterval = 15 * 60
    @State private var isRunning = false
    
    // Absolute Time Tracking State for flawless background running
    @State private var sessionStartTime: Date? = nil
    @State private var accumulatedElapsed: TimeInterval = 0
    @State private var lastProcessedSecond: Int = 0
    
    // Interval State
    @State private var intervalX: TimeInterval = 7.5 * 60
    @State private var isCustomInterval = false
    @State private var intervalSound = "tingsha" // "bowl" or "tingsha"
    @State private var intervalInputMode = "count" // Default is 'count'
    @State private var intervalCount: Int = 2 // Persistent numeric gong count state
    
    // Countdown State
    @State private var isCountdownEnabled = false
    @State private var countdownDuration: TimeInterval = 10
    @State private var countdownActive = false
    @State private var countdownTimeLeft: TimeInterval = 10
    
    // Bottom Sheet Visibility
    @State private var showSettings = false
    
    // Text Inputs (synchronized with values on commit/blur)
    @State private var totalMinsInput = "15"
    @State private var totalSecsInput = "00"
    @State private var intervalMinsInput = "7"
    @State private var intervalSecsInput = "30"
    @State private var intervalCountInput = "2"
    @State private var countdownDurationInput = "10"
    
    // Focused state to show step buttons
    @State private var focusedField: String? = nil
    
    // Audio Players
    @State private var startPlayer: AVAudioPlayer?
    @State private var tingshaPlayer: AVAudioPlayer?
    @State private var silentPlayer: AVAudioPlayer? // Looped silent audio to keep app executing in background
    
    // Breathing Outer Ring Animation States
    @State private var breathingScale: CGFloat = 0.95
    @State private var breathingOpacity: Double = 0.8
    
    // Background-safe dispatcher
    @StateObject private var bgTimer = BackgroundTimer()
    
    var body: some View {
        ZStack {
            // 1. Immersive Buddha Background (aligned to trailing to keep Buddha centered & fully visible on iPhone)
            GeometryReader { geometry in
                buddhaImageView
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .offset(x: -geometry.size.height * 0.44) // Mathematically precise alignment to center the Buddha (at 85% of landscape width)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .edgesIgnoringSafeArea(.all)
            
            // Warm Golden Overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 218.0 / 255.0, green: 165.0 / 255.0, blue: 32.0 / 255.0).opacity(0.35),
                    Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0).opacity(0.55)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            // 2. Main Content
            VStack(spacing: 0) {
                Spacer()
                
                Text("GOLDEN MEDITATION")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0))
                    .tracking(2.0)
                    .shadow(color: Color(red: 62.0 / 255.0, green: 39.0 / 255.0, blue: 35.0 / 255.0).opacity(0.25), radius: 6, x: 0, y: 2)
                    .padding(.bottom, 40)
                
                // Circular Timer
                timerCircleView
                
                Spacer()
                
                // Controls Group
                controlsGroupView
                    .padding(.bottom, 40)
            }
            
            // 3. Apple-Style Fixed Bottom Sheet settings panel
            if showSettings {
                ZStack(alignment: .bottom) {
                    // Soft dark touch-dismiss scrim
                    Color.black.opacity(0.25)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                hideKeyboard()
                                showSettings = false
                            }
                        }
                    
                    // Slide up native SwiftUI Options sheet
                    settingsSheetView
                        .transition(.move(edge: .bottom))
                }
                .edgesIgnoringSafeArea(.bottom)
            }
        }
        .preferredColorScheme(.light) // Force light color scheme (bronze/gold text) in Dark Mode
        .onAppear {
            loadAudioEngine()
            syncAllInputs()
            startBreathingAnimation()
        }
    }
    
    // MARK: - Subviews
    
    private var buddhaImageView: Image {
        if let path = Bundle.main.path(forResource: "buddha", ofType: "jpg", inDirectory: "public"),
           let uiImage = UIImage(contentsOfFile: path) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
    }
    
    private var timerCircleView: some View {
        ZStack {
            // Breathing Outer Ring
            Circle()
                .stroke(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.5), lineWidth: 2)
                .frame(width: 260, height: 260)
                .scaleEffect(isRunning ? breathingScale : 0.95)
                .opacity(isRunning ? breathingOpacity : 0)
                .animation(isRunning ? Animation.easeInOut(duration: 4.0).repeatForever(autoreverses: true) : .default, value: isRunning)
            
            // Solid Inner Timer Card
            Circle()
                .fill(Color(red: 255.0 / 255.0, green: 250.0 / 255.0, blue: 240.0 / 255.0).opacity(0.4))
                .frame(width: 240, height: 240)
                .overlay(
                    Circle()
                        .stroke(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.5), lineWidth: 2)
                )
                .shadow(color: Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0).opacity(0.1), radius: 24, x: 0, y: 8)
            
            // Timer details
            VStack(spacing: 2) {
                if countdownActive {
                    Text("PREPARE")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 196.0 / 255.0, green: 146.0 / 255.0, blue: 62.0 / 255.0))
                        .tracking(1.5)
                        .opacity(breathingOpacity)
                }
                
                Text(formatTime(countdownActive ? countdownTimeLeft : timeLeft))
                    .font(.system(size: 64, weight: .thin, design: .rounded))
                    .foregroundColor(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0))
                    .shadow(color: Color(red: 255.0 / 255.0, green: 250.0 / 255.0, blue: 240.0 / 255.0).opacity(0.8), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    private var controlsGroupView: some View {
        HStack(spacing: 12) {
            // Start/Pause Button
            Button(action: toggleTimer) {
                Text(isRunning ? "Pause" : "Start")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 62.0 / 255.0, green: 39.0 / 255.0, blue: 37.0 / 255.0))
                    .frame(width: 100, height: 44)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(red: 255.0 / 255.0, green: 215.0 / 255.0, blue: 0), Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(22)
                    .shadow(color: Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.3), radius: 8, x: 0, y: 4)
            }
            
            // Reset Button
            Button(action: resetTimer) {
                Text("Reset")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0))
                    .frame(width: 100, height: 44)
                    .background(Color(red: 255.0 / 255.0, green: 250.0 / 255.0, blue: 240.0 / 255.0).opacity(0.8))
                    .cornerRadius(22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.4), lineWidth: 1)
                    )
            }
            
            // Options Toggle Button
            Button(action: {
                triggerHaptic()
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSettings = true
                }
            }) {
                Text("Options")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0))
                    .frame(width: 100, height: 44)
                    .background(Color(red: 255.0 / 255.0, green: 250.0 / 255.0, blue: 240.0 / 255.0).opacity(0.8))
                    .cornerRadius(22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.4), lineWidth: 1)
                    )
            }
        }
    }
    
    private var settingsSheetView: some View {
        VStack(spacing: 16) {
            // Drag handle indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0).opacity(0.25))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
            
            // Title & Native Close Button
            HStack {
                Text("Session Options")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0))
                
                Spacer()
                
                Button(action: {
                    triggerHaptic()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        hideKeyboard()
                        showSettings = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0))
                        .frame(width: 28, height: 28)
                        .background(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0).opacity(0.12))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            
            VStack(spacing: 20) {
                
                // ROW 1: Meditation Duration
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Meditation Time:")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0))
                        
                        Spacer()
                        
                        // Direct text keypad group (Minutes only)
                        HStack(spacing: 4) {
                            stepperTextField(value: $totalMinsInput, suffix: "m", field: "totalMins", increment: { adjustValue(type: "totalMins", up: true) }, decrement: { adjustValue(type: "totalMins", up: false) })
                        }
                    }
                    
                    Slider(value: Binding(get: { totalTime }, set: { val in
                        totalTime = val
                        timeLeft = val
                        isRunning = false
                        if intervalInputMode == "count" {
                            intervalX = val / Double(max(1, intervalCount))
                        } else {
                            if !isCustomInterval {
                                intervalX = round(val / 2)
                                intervalCount = 2
                            } else if intervalX > val {
                                intervalX = val
                                intervalCount = 1
                            } else {
                                intervalCount = Int(round(val / intervalX))
                            }
                        }
                        syncAllInputs()
                    }), in: 60...5400, step: 60)
                    .accentColor(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0))
                }
                
                // ROW 2: Gong Interval
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Gong Interval:")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0))
                        
                        Spacer()
                        
                        CustomSegmentedPicker(
                            selection: Binding(get: { intervalInputMode }, set: { val in
                                triggerHaptic()
                                intervalInputMode = val
                                handleIntervalModeChange()
                            }),
                            options: [("By Count", "count"), ("By Time", "time")]
                        )
                    }
                    
                    if intervalInputMode == "time" {
                        HStack {
                            Text("Interval Duration:")
                                .font(.system(size: 13))
                                .foregroundColor(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0).opacity(0.85))
                            Spacer()
                            HStack(spacing: 4) {
                                stepperTextField(value: $intervalMinsInput, suffix: "m", field: "intervalMins", increment: { adjustValue(type: "intervalMins", up: true) }, decrement: { adjustValue(type: "intervalMins", up: false) })
                                stepperTextField(value: $intervalSecsInput, suffix: "s", field: "intervalSecs", increment: { adjustValue(type: "intervalSecs", up: true) }, decrement: { adjustValue(type: "intervalSecs", up: false) })
                            }
                        }
                        
                        Slider(value: Binding(get: { min(intervalX, totalTime) }, set: { val in
                            intervalX = val
                            intervalCount = Int(round(totalTime / val))
                            isCustomInterval = true
                            isRunning = false
                            timeLeft = totalTime
                            syncAllInputs()
                        }), in: 5...max(5, totalTime), step: 5)
                        .accentColor(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0))
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text("Once every:")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0))
                                        Text(getCountIntervalLengthText())
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(Color(red: 184.0 / 255.0, green: 134.0 / 255.0, blue: 11.0 / 255.0))
                                    }
                                }
                                Spacer()
                                stepperTextField(value: $intervalCountInput, suffix: "intervals", field: "intervalCount", increment: { adjustValue(type: "intervalCount", up: true) }, decrement: { adjustValue(type: "intervalCount", up: false) })
                            }
                        }
                    }
                }
                
                // ROW 3: Sound Choice
                HStack {
                    Text("Interval Bell Sound:")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0))
                    
                    Spacer()
                    
                    CustomSegmentedPicker(
                        selection: Binding(get: { intervalSound }, set: { val in
                            intervalSound = val
                            playIntervalGong()
                        }),
                        options: [("Bowl", "bowl"), ("Tingsha", "tingsha")]
                    )
                }
                
                // ROW 4: Preparation Switch
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Preparation Countdown:")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0))
                        
                        Spacer()
                        
                        if isCountdownEnabled {
                            stepperTextField(value: $countdownDurationInput, suffix: "s", field: "countdown", increment: { adjustValue(type: "countdown", up: true) }, decrement: { adjustValue(type: "countdown", up: false) })
                        }
                        
                        Toggle("", isOn: $isCountdownEnabled)
                            .labelsHidden()
                            .toggleStyle(SwitchToggleStyle(tint: Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0)))
                    }
                    
                    if isCountdownEnabled {
                        Slider(value: Binding(get: { countdownDuration }, set: { val in
                            countdownDuration = val
                            syncAllInputs()
                        }), in: 5...60, step: 1)
                        .accentColor(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity)
        .background(
            Color(red: 255.0 / 255.0, green: 252.0 / 255.0, blue: 245.0 / 255.0)
                .opacity(0.9)
                .background(VisualEffectBlur(blurStyle: .systemMaterial))
        )
        .cornerRadius(24)
        .shadow(color: Color(red: 62.0 / 255.0, green: 39.0 / 255.0, blue: 37.0 / 255.0).opacity(0.18), radius: 32, x: 0, y: -8)
    }
    
    // Direct numerical steppers helper
    private func stepperTextField(value: Binding<String>, suffix: String, field: String, increment: @escaping () -> Void, decrement: @escaping () -> Void) -> some View {
        HStack(spacing: 2) {
            Button(action: {
                triggerHaptic()
                decrement()
            }) {
                Text("−")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 184.0 / 255.0, green: 134.0 / 255.0, blue: 11.0 / 255.0))
                    .frame(width: 18, height: 18)
                    .background(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.15))
                    .clipShape(Circle())
            }
            
            TextField("", text: value, onEditingChanged: { isEditing in
                if isEditing {
                    focusedField = field
                } else {
                    focusedField = nil
                    commitField(field)
                }
            })
            .keyboardType(.numberPad)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color(red: 184.0 / 255.0, green: 134.0 / 255.0, blue: 11.0 / 255.0))
            .frame(width: field == "intervalCount" ? 30 : 22, alignment: .trailing)
            .multilineTextAlignment(.trailing)
            
            Text(suffix)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0))
            
            Button(action: {
                triggerHaptic()
                increment()
            }) {
                Text("+")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 184.0 / 255.0, green: 134.0 / 255.0, blue: 11.0 / 255.0))
                    .frame(width: 18, height: 18)
                    .background(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(red: 255.0 / 255.0, green: 250.0 / 255.0, blue: 240.0 / 255.0).opacity(0.6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(focusedField == field ? 0.8 : 0.4), lineWidth: 1)
        )
    }
    
    // MARK: - Logic & Actions
    
    private func startBreathingAnimation() {
        withAnimation(Animation.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            breathingScale = 1.08
            breathingOpacity = 0.3
        }
    }
    
    private func getCountIntervalLengthText() -> String {
        let count = intervalInputMode == "count" ? intervalCount : (intervalX > 0 ? Int(round(totalTime / intervalX)) : 2)
        let lengthSecs = totalTime / Double(max(1, count))
        let mins = Int(lengthSecs) / 60
        let secs = Int(round(lengthSecs.truncatingRemainder(dividingBy: 60)))
        if mins > 0 && secs > 0 {
            return "\(mins)m \(secs)s"
        } else if mins > 0 {
            return "\(mins)m"
        } else {
            return "\(secs)s"
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalRounded = Int(round(seconds))
        let mins = totalRounded / 60
        let secs = totalRounded % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func stopAllGongs() {
        if let player = startPlayer, player.isPlaying {
            player.stop()
        }
        if let player = tingshaPlayer, player.isPlaying {
            player.stop()
        }
    }
    
    private func toggleTimer() {
        triggerHaptic()
        if !isRunning {
            if timeLeft == totalTime && !countdownActive {
                if isCountdownEnabled {
                    countdownActive = true
                    countdownTimeLeft = countdownDuration
                } else {
                    playGong()
                }
            }
            sessionStartTime = Date()
            isRunning = true
            
            // Loop silent player on repeat to keep background audio thread alive
            silentPlayer?.currentTime = 0
            silentPlayer?.play()
            
            // Start queue-driven background timer
            bgTimer.onTick = {
                timerTick()
            }
            bgTimer.start()
        } else {
            if let start = sessionStartTime {
                accumulatedElapsed += Date().timeIntervalSince(start)
            }
            sessionStartTime = nil
            isRunning = false
            stopAllGongs()
            
            // Stop background timers
            silentPlayer?.stop()
            bgTimer.stop()
        }
    }
    
    private func resetTimer() {
        triggerHaptic()
        isRunning = false
        countdownActive = false
        sessionStartTime = nil
        accumulatedElapsed = 0
        lastProcessedSecond = 0
        timeLeft = totalTime
        stopAllGongs()
        
        // Stop background timers
        silentPlayer?.stop()
        bgTimer.stop()
    }
    
    private func timerTick() {
        guard isRunning else { return }
        
        if countdownActive {
            if countdownTimeLeft <= 1 {
                countdownActive = false
                playGong()
                sessionStartTime = Date()
                accumulatedElapsed = 0
                lastProcessedSecond = 0
            } else {
                countdownTimeLeft -= 1
            }
        } else {
            guard let start = sessionStartTime else { return }
            let totalElapsed = accumulatedElapsed + Date().timeIntervalSince(start)
            let newTimeLeft = max(0, totalTime - totalElapsed)
            timeLeft = newTimeLeft
            
            let currentSecond = Int(totalElapsed)
            if currentSecond > lastProcessedSecond {
                for sec in (lastProcessedSecond + 1)...currentSecond {
                    var shouldPlay = false
                    if sec > 0 && Double(sec) < totalTime {
                        if intervalInputMode == "time" {
                            shouldPlay = sec % Int(round(intervalX)) == 0
                        } else {
                            let count = intervalInputMode == "count" ? intervalCount : (intervalX > 0 ? Int(round(totalTime / intervalX)) : 2)
                            if count > 1 {
                                for i in 1..<count {
                                    let expectedSecond = Int(round(Double(i) * totalTime / Double(count)))
                                    if sec == expectedSecond {
                                        shouldPlay = true
                                        break
                                    }
                                }
                            }
                        }
                    }
                    
                    if shouldPlay {
                        playIntervalGong()
                    }
                }
                lastProcessedSecond = currentSecond
            }
            
            if newTimeLeft <= 0 {
                playEndGong()
                isRunning = false
                sessionStartTime = nil
                silentPlayer?.stop()
                bgTimer.stop()
            }
        }
    }
    
    // Direct inputs committing
    private func commitField(_ field: String) {
        switch field {
        case "totalMins":
            let mins = Int(totalMinsInput) ?? 0
            let newTotal = TimeInterval(mins * 60)
            if newTotal >= 60 {
                let capped = min(10800, newTotal) // 3 hours
                totalTime = capped
                timeLeft = capped
                isRunning = false
                
                if intervalInputMode == "count" {
                    intervalX = capped / Double(max(1, intervalCount))
                } else {
                    if !isCustomInterval {
                        intervalX = round(capped / 2)
                        intervalCount = 2
                    } else if intervalX > capped {
                        intervalX = capped
                        intervalCount = 1
                    } else {
                        intervalCount = Int(round(capped / intervalX))
                    }
                }
            }
            syncAllInputs()
            
        case "intervalMins", "intervalSecs":
            let mins = Int(intervalMinsInput) ?? 0
            let secs = min(59, Int(intervalSecsInput) ?? 0)
            let newInterval = TimeInterval(mins * 60 + secs)
            if newInterval >= 5 && newInterval <= totalTime {
                intervalX = newInterval
                intervalCount = Int(round(totalTime / newInterval))
                isCustomInterval = true
                isRunning = false
                timeLeft = totalTime
            }
            syncAllInputs()
            
        case "intervalCount":
            let count = Int(intervalCountInput) ?? 2
            if count >= 1 {
                let calculated = totalTime / Double(count)
                intervalX = max(5, min(totalTime, calculated))
                intervalCount = count
                isCustomInterval = true
                isRunning = false
                timeLeft = totalTime
            }
            syncAllInputs()
            
        case "countdown":
            let val = Int(countdownDurationInput) ?? 10
            countdownDuration = max(3, min(300, TimeInterval(val)))
            syncAllInputs()
            
        default:
            break
        }
    }
    
    private func adjustValue(type: String, up: Bool) {
        switch type {
        case "totalMins":
            let current = Int(totalMinsInput) ?? 0
            totalMinsInput = String(max(1, current + (up ? 1 : -1)))
            commitField("totalMins")
        case "intervalMins":
            let current = Int(intervalMinsInput) ?? 0
            intervalMinsInput = String(max(0, current + (up ? 1 : -1)))
            commitField("intervalMins")
        case "intervalSecs":
            let current = Int(intervalSecsInput) ?? 0
            let diff = up ? 5 : -5
            var next = (current + diff) % 60
            if next < 0 { next += 60 }
            intervalSecsInput = String(format: "%02d", next)
            commitField("intervalSecs")
        case "intervalCount":
            let current = intervalCount
            intervalCountInput = String(max(1, current + (up ? 1 : -1)))
            commitField("intervalCount")
        case "countdown":
            let current = Int(countdownDurationInput) ?? 10
            countdownDurationInput = String(max(3, current + (up ? 1 : -1)))
            commitField("countdown")
        default:
            break
        }
    }
    
    private func handleIntervalModeChange() {
        if intervalInputMode == "time" {
            let rounded = round(intervalX)
            intervalX = rounded
            intervalCount = Int(round(totalTime / rounded))
            if rounded == round(totalTime / 2) {
                isCustomInterval = false
            }
        } else {
            let count = intervalCount
            if count >= 1 {
                let calculated = totalTime / Double(count)
                intervalX = calculated
                if count == 2 || round(calculated) == round(totalTime / 2) {
                    isCustomInterval = false
                }
            }
        }
        syncAllInputs()
    }
    
    private func syncAllInputs() {
        // sync total time inputs
        let tm = Int(totalTime) / 60
        totalMinsInput = String(tm)
        totalSecsInput = "00"
        
        // sync interval time inputs
        let im = Int(intervalX) / 60
        let isSec = Int(round(intervalX.truncatingRemainder(dividingBy: 60)))
        intervalMinsInput = String(im)
        intervalSecsInput = String(format: "%02d", isSec)
        
        // sync count input
        let count = intervalInputMode == "count" ? intervalCount : (intervalX > 0 ? Int(round(totalTime / intervalX)) : 2)
        intervalCountInput = String(count)
        
        // sync countdown
        countdownDurationInput = String(Int(countdownDuration))
    }
    
    // MARK: - Audio Engine Helpers
    
    private func loadAudioEngine() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to initialize AVAudioSession: \(error)")
        }
        
        if let startPath = Bundle.main.path(forResource: "start", ofType: "mp3", inDirectory: "public") {
            let url = URL(fileURLWithPath: startPath)
            startPlayer = try? AVAudioPlayer(contentsOf: url)
            startPlayer?.prepareToPlay()
        }
        
        if let tingshaPath = Bundle.main.path(forResource: "tingsha3", ofType: "mp3", inDirectory: "public") {
            let url = URL(fileURLWithPath: tingshaPath)
            tingshaPlayer = try? AVAudioPlayer(contentsOf: url)
            tingshaPlayer?.prepareToPlay()
            
            // Set up inaudible silent background looper
            silentPlayer = try? AVAudioPlayer(contentsOf: url)
            silentPlayer?.numberOfLoops = -1 // Repeat infinitely
            silentPlayer?.volume = 0.0 // Completely silent
            silentPlayer?.prepareToPlay()
        }
    }
    
    private func playGong() {
        triggerHaptic()
        if let player = startPlayer {
            player.rate = 0.60 // Elegantly lower-pitched, highly grounding resonant frequency
            player.volume = 0.0 // Start at 0 volume to suppress the harsh mallet hit
            player.enableRate = true
            player.currentTime = 0
            player.play()
            player.setVolume(0.8, fadeDuration: 0.6) // Smoothly swell in the resonance over 0.6 seconds
        }
    }
    
    private func playIntervalGong() {
        triggerHaptic()
        if intervalSound == "bowl" {
            if let player = startPlayer {
                player.rate = 0.60 // Elegantly lower-pitched, highly grounding resonant frequency
                player.volume = 0.0 // Start at 0 volume to suppress the harsh mallet hit
                player.enableRate = true
                player.currentTime = 0
                player.play()
                player.setVolume(0.8, fadeDuration: 0.6) // Smoothly swell in the resonance over 0.6 seconds
            }
        } else {
            if let player = tingshaPlayer {
                player.rate = 0.85 // Pitch-down Tingsha slightly for a calmer, softer background chime
                player.volume = 0.0 // Start at 0 volume to suppress the harsh mallet hit
                player.enableRate = true
                player.currentTime = 0
                player.play()
                player.setVolume(0.5, fadeDuration: 0.2) // Softer Tingsha hit swell
            }
        }
    }
    
    private func playEndGong() {
        playGong()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.playGong()
        }
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// Visual Effect Blur helper for premium glassmorphism sheet background
struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// Custom premium Segmented Control representing elegant capsules, golden gradients, and spring animations
struct CustomSegmentedPicker: View {
    @Binding var selection: String
    var options: [(String, String)] // Array of (displayName, tagValue)
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.1) { option in
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        selection = option.1
                    }
                }) {
                    Text(option.0)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(selection == option.1 ? Color(red: 62.0 / 255.0, green: 39.0 / 255.0, blue: 37.0 / 255.0) : Color(red: 139.0 / 255.0, green: 115.0 / 255.0, blue: 85.0 / 255.0))
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .frame(minWidth: 62)
                        .background(
                            ZStack {
                                if selection == option.1 {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 255.0 / 255.0, green: 215.0 / 255.0, blue: 0),
                                                    Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.35), radius: 3, x: 0, y: 1.5)
                                }
                            }
                        )
                }
            }
        }
        .padding(2)
        .background(Color(red: 255.0 / 255.0, green: 250.0 / 255.0, blue: 240.0 / 255.0).opacity(0.55))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.35), lineWidth: 1)
        )
    }
}
