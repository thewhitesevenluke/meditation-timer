import UIKit
import SwiftUI
import AVFoundation

private let maxMeditationTime: TimeInterval = 60 * 60
private let defaultCountdownDuration: TimeInterval = 15
private let maxCountdownDuration: TimeInterval = 60

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
    @State private var totalTime: TimeInterval = 20 * 60 // 20 mins default
    @State private var timeLeft: TimeInterval = 20 * 60
    @State private var isRunning = false
    
    // Absolute Time Tracking State for flawless background running
    @State private var sessionStartTime: Date? = nil
    @State private var accumulatedElapsed: TimeInterval = 0
    @State private var lastProcessedSecond: Int = 0
    @State private var overtimeActive = false
    @State private var overtimeStartTime: Date? = nil
    @State private var overtimeAccumulated: TimeInterval = 0
    @State private var overtimeElapsed: TimeInterval = 0
    
    // Interval State
    @State private var intervalX: TimeInterval = 10 * 60
    @State private var isCustomInterval = false
    @State private var intervalSound = "tingsha" // "bowl" or "tingsha"
    @State private var intervalInputMode = "count" // Default is 'count'
    @State private var intervalCount: Int = 2 // Persistent section count state
    
    // Countdown State
    @State private var isCountdownEnabled = true
    @State private var countdownDuration: TimeInterval = defaultCountdownDuration
    @State private var countdownActive = false
    @State private var countdownTimeLeft: TimeInterval = defaultCountdownDuration
    
    // Bottom Sheet Visibility
    @State private var showSettings = false
    @GestureState private var settingsDragOffset: CGFloat = 0
    
    // Text Inputs (synchronized with values on commit/blur)
    @State private var totalMinsInput = "20"
    @State private var intervalMinsInput = "10"
    @State private var intervalSecsInput = "30"
    @State private var intervalCountInput = "2"
    @State private var countdownDurationInput = String(Int(defaultCountdownDuration))
    
    // Focused state to show step buttons
    @State private var focusedField: String? = nil
    
    // Audio Players
    @State private var startPlayer: AVAudioPlayer?
    @State private var tingshaPlayer: AVAudioPlayer?
    @State private var silentPlayer: AVAudioPlayer? // Looped silent audio to keep app executing in background
    @State private var endGongReplayWorkItem: DispatchWorkItem?
    
    // Background-safe dispatcher
    @StateObject private var bgTimer = BackgroundTimer()
    
    var body: some View {
        ZStack {
            // 1. Immersive Buddha Background
            GeometryReader { geometry in
                homeBackgroundImageView
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            }
            .edgesIgnoringSafeArea(.all)
            
            // Warm Golden Overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 223.0 / 255.0, green: 172.0 / 255.0, blue: 54.0 / 255.0).opacity(0.38),
                    Color(red: 82.0 / 255.0, green: 69.0 / 255.0, blue: 39.0 / 255.0).opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            // 2. Main Content
            mainContentView
            
            // 3. Apple-Style Fixed Bottom Sheet settings panel
            if showSettings {
                ZStack(alignment: .bottom) {
                    // Soft dark touch-dismiss scrim
                    Color.black.opacity(0.25)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            dismissSettings()
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
        }
    }
    
    // MARK: - Subviews

    private var dhammaGold: Color {
        Color(red: 224.0 / 255.0, green: 174.0 / 255.0, blue: 64.0 / 255.0)
    }

    private var dhammaDeepGold: Color {
        Color(red: 197.0 / 255.0, green: 145.0 / 255.0, blue: 43.0 / 255.0)
    }

    private var dhammaSoftGold: Color {
        Color(red: 246.0 / 255.0, green: 217.0 / 255.0, blue: 151.0 / 255.0)
    }

    private var dhammaAntiqueGold: Color {
        Color(red: 176.0 / 255.0, green: 137.0 / 255.0, blue: 62.0 / 255.0)
    }

    private var dhammaInk: Color {
        Color(red: 44.0 / 255.0, green: 37.0 / 255.0, blue: 22.0 / 255.0)
    }

    private var dhammaPanel: Color {
        Color(red: 34.0 / 255.0, green: 31.0 / 255.0, blue: 21.0 / 255.0)
    }

    private var dhammaPanelStrong: Color {
        Color(red: 24.0 / 255.0, green: 23.0 / 255.0, blue: 17.0 / 255.0)
    }

    private var isSessionActive: Bool {
        isRunning || countdownActive || overtimeActive || timeLeft < totalTime
    }

    private var mainContentView: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 312)

            timerCircleView

            sessionSummaryView
                .padding(.top, isSessionActive ? 14 : 0)

            if isSessionActive {
                Spacer()

                focusControlsGroupView
                    .padding(.horizontal, 34)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Spacer(minLength: 28)

                setupOptionsPanelView
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                setupStartButton
                    .padding(.top, 18)
                    .padding(.horizontal, 34)
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: isSessionActive)
    }
    
    private var homeBackgroundImageView: Image {
        if let path = Bundle.main.path(forResource: "buddha-ios-home", ofType: "jpg", inDirectory: "public"),
           let uiImage = UIImage(contentsOfFile: path) {
            return Image(uiImage: uiImage)
        }
        return buddhaImageView
    }
    
    private var buddhaImageView: Image {
        if let path = Bundle.main.path(forResource: "buddha", ofType: "jpg", inDirectory: "public"),
           let uiImage = UIImage(contentsOfFile: path) {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "photo")
    }
    
    private var timerCircleView: some View {
        ZStack {
            // Timer details
            VStack(spacing: isSessionActive ? 10 : 2) {
                if countdownActive || overtimeActive {
                    Text(overtimeActive ? "Extra time" : "Preparing")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(dhammaSoftGold)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 16)
                        .background(dhammaPanelStrong.opacity(0.58))
                        .clipShape(Capsule())
                }
                
                Text(formatTime(overtimeActive ? overtimeElapsed : (countdownActive ? countdownTimeLeft : timeLeft)))
                    .font(.system(size: isSessionActive ? 74 : 72, weight: .light, design: .rounded))
                    .foregroundColor(dhammaSoftGold)
                    .shadow(color: Color.black.opacity(0.46), radius: isSessionActive ? 8 : 7, x: 0, y: 3)
                    .monospacedDigit()
            }
            .padding(.vertical, isSessionActive ? 18 : 12)
            .padding(.horizontal, isSessionActive ? 26 : 24)
            .frame(minWidth: isSessionActive ? 260 : 282)
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(dhammaPanelStrong.opacity(isSessionActive ? 0.52 : 0.44))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(dhammaGold.opacity(isSessionActive ? 0.16 : 0.28), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isSessionActive ? 0.22 : 0.28), radius: 18, x: 0, y: 10)
        }
    }

    private var sessionSummaryView: some View {
        VStack(spacing: 8) {
            if let bellStatusText = sessionBellStatusText {
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(bellStatusText)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(dhammaSoftGold)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(dhammaPanelStrong.opacity(0.62))
                .clipShape(Capsule())
            }
        }
    }

    private var setupOptionsPanelView: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                HStack {
                    Text("Duration")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(dhammaSoftGold.opacity(0.9))
                    Spacer(minLength: 0)
                }

                Slider(value: Binding(get: { totalTime }, set: { val in
                    updateTotalTime(val)
                }), in: 60...maxMeditationTime, step: 60)
                .accentColor(dhammaGold)
            }

            Divider()
                .background(dhammaGold.opacity(0.24))

            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: effectiveIntervalCount > 1 ? "chart.bar.fill" : "bell.slash.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(dhammaGold)
                        .frame(width: 28, height: 28)
                        .background(dhammaGold.opacity(0.18))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(intervalInputMode == "count" ? "Interval bells" : "Bell interval")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(dhammaSoftGold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.86)
                        Text(intermediateBellSummaryText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(dhammaSoftGold.opacity(0.82))
                    }
                }

                Spacer()

                if intervalInputMode == "count" {
                    bellCountStepperView
                } else {
                    Image(systemName: "clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(dhammaGold)
                        .frame(width: 40, height: 32)
                        .background(dhammaGold.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(dhammaPanelStrong.opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(dhammaGold.opacity(0.3), lineWidth: 1)
            )

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Preparation")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(dhammaSoftGold)
                    Text(isCountdownEnabled ? "\(Int(countdownDuration)) seconds before start" : "Start immediately")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(dhammaSoftGold.opacity(0.78))
                }

                Spacer()

                Toggle("", isOn: $isCountdownEnabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0)))
            }

            Button(action: {
                triggerHaptic()
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSettings = true
                }
            }) {
                Text("More settings")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(dhammaGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
        .padding(16)
        .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(dhammaPanel.opacity(0.68))
                .background(
                    VisualEffectBlur(blurStyle: .systemThinMaterialDark)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(dhammaGold.opacity(0.28), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.26), radius: 22, x: 0, y: 12)
    }

    private var setupStartButton: some View {
        Button(action: toggleTimer) {
            Text("Start")
                .font(.system(size: 23, weight: .bold))
                .foregroundColor(dhammaInk)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [dhammaGold, dhammaDeepGold]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(28)
                .shadow(color: Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.28), radius: 12, x: 0, y: 6)
        }
    }

    private var bellCountStepperView: some View {
        HStack(spacing: 9) {
            Button(action: {
                triggerHaptic()
                adjustValue(type: "intervalCount", up: false)
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(dhammaSoftGold)
                    .frame(width: 28, height: 28)
                    .background(dhammaPanelStrong.opacity(0.5))
                    .clipShape(Circle())
            }

            Text("\(effectiveIntervalCount)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(dhammaSoftGold)
                .frame(width: 28)
                .monospacedDigit()

            Button(action: {
                triggerHaptic()
                adjustValue(type: "intervalCount", up: true)
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(dhammaSoftGold)
                    .frame(width: 28, height: 28)
                    .background(dhammaPanelStrong.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            Capsule()
                .fill(dhammaPanelStrong.opacity(0.46))
        )
        .overlay(
            Capsule()
                .stroke(dhammaGold.opacity(0.34), lineWidth: 1)
        )
    }

    private var focusControlsGroupView: some View {
        HStack(spacing: 16) {
            Button(action: toggleTimer) {
                Text(isRunning ? "Pause" : "Resume")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(dhammaInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(dhammaGold.opacity(0.92))
                    .cornerRadius(26)
            }

            Button(action: resetTimer) {
                Text("Stop")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(dhammaInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color(red: 255.0 / 255.0, green: 250.0 / 255.0, blue: 240.0 / 255.0).opacity(0.86))
                    .cornerRadius(26)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26)
                            .stroke(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0).opacity(0.35), lineWidth: 1)
                    )
            }
        }
    }
    
    private var settingsSheetView: some View {
        VStack(spacing: 16) {
            // Drag handle indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(dhammaAntiqueGold.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
            
            // Title & Native Close Button
            HStack {
                Text("More Settings")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(dhammaAntiqueGold)
                
                Spacer()
                
                Button(action: {
                    triggerHaptic()
                    dismissSettings()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(dhammaAntiqueGold)
                        .frame(width: 28, height: 28)
                        .background(dhammaGold.opacity(0.14))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 24)
            
            VStack(spacing: 20) {
                // Advanced bell behavior
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Bell spacing")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(dhammaAntiqueGold)
                        
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
                            Text("Interval length")
                                .font(.system(size: 13))
                                .foregroundColor(dhammaAntiqueGold.opacity(0.9))
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
                        Text(hasIntermediateBells ? "Sections are adjusted on the main screen. Current spacing: \(formatIntervalLengthText(intermediateBellSpacing))" : "1 section means end bell only.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(dhammaAntiqueGold.opacity(0.78))
                    }
                }
                
                // Sound Choice
                HStack {
                    Text("Bell sound:")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(dhammaAntiqueGold)
                    
                    Spacer()
                    
                    CustomSegmentedPicker(
                        selection: Binding(get: { intervalSound }, set: { val in
                            intervalSound = val
                            playIntervalGong()
                        }),
                        options: [("Bowl", "bowl"), ("Tingsha", "tingsha")]
                    )
                }
                
                // Preparation length only; the on/off switch lives on the main screen.
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Preparation length")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(dhammaAntiqueGold)
                        
                        Spacer()
                        
                        stepperTextField(value: $countdownDurationInput, suffix: "s", field: "countdown", increment: { adjustValue(type: "countdown", up: true) }, decrement: { adjustValue(type: "countdown", up: false) })
                    }
                    
                    Slider(value: Binding(get: { countdownDuration }, set: { val in
                        countdownDuration = val
                        syncAllInputs()
                    }), in: 5...60, step: 1)
                    .accentColor(Color(red: 212.0 / 255.0, green: 175.0 / 255.0, blue: 55.0 / 255.0))
                }
            }
            .padding(.horizontal, 24)

            Text("Made by Luke for Dad, with Love ❤️😊")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(dhammaAntiqueGold.opacity(0.48))
                .padding(.top, 2)
                .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity)
        .background(
            Color(red: 255.0 / 255.0, green: 252.0 / 255.0, blue: 245.0 / 255.0)
                .opacity(0.9)
                .background(VisualEffectBlur(blurStyle: .systemMaterial))
        )
        .cornerRadius(24)
        .shadow(color: dhammaInk.opacity(0.16), radius: 32, x: 0, y: -8)
        .offset(y: settingsDragOffset)
        .gesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .updating($settingsDragOffset) { value, state, _ in
                    if value.translation.height > 0 {
                        state = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 70 || value.predictedEndTranslation.height > 140 {
                        triggerHaptic()
                        dismissSettings()
                    }
                }
        )
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
                .foregroundColor(dhammaAntiqueGold)
            
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
    
    private func formatIntervalLengthText(_ seconds: TimeInterval) -> String {
        let totalRounded = Int(round(seconds))
        let mins = totalRounded / 60
        let secs = totalRounded % 60
        return String(format: "%d:%02dm", mins, secs)
    }

    private var effectiveIntervalCount: Int {
        if intervalInputMode == "time" {
            guard intervalX > 0 else { return 1 }
            return max(1, Int(round(totalTime / intervalX)))
        }
        return max(1, intervalCount)
    }

    private var maxIntervalSectionCount: Int {
        max(1, Int(totalTime / 5))
    }

    private func sectionCount(forTotal total: TimeInterval, fixedInterval: TimeInterval) -> Int {
        guard fixedInterval > 0 else { return 1 }
        return max(1, Int(round(total / fixedInterval)))
    }

    private var intermediateBellSpacing: TimeInterval {
        if intervalInputMode == "time" {
            return max(5, min(totalTime, intervalX))
        }
        return totalTime / Double(max(1, effectiveIntervalCount))
    }

    private var intermediateBellCount: Int {
        if intervalInputMode == "time" {
            guard intervalX > 0, intervalX < totalTime else { return 0 }
            return max(0, Int(floor((totalTime - 0.001) / intervalX)))
        }
        return max(0, effectiveIntervalCount - 1)
    }

    private var hasIntermediateBells: Bool {
        return intermediateBellCount > 0
    }

    private var intermediateBellSummaryText: String {
        guard hasIntermediateBells else {
            return "End bell only"
        }

        return "Bell every \(formatTime(intermediateBellSpacing))"
    }

    private var scheduledIntermediateBellSeconds: [Int] {
        guard hasIntermediateBells else { return [] }

        if intervalInputMode == "time" {
            let spacing = max(1, Int(round(intervalX)))
            let total = Int(round(totalTime))
            return Array(stride(from: spacing, to: total, by: spacing))
        }

        let count = effectiveIntervalCount
        guard count > 1 else { return [] }
        return (1..<count).map { index in
            Int(round(Double(index) * totalTime / Double(count)))
        }
    }

    private var nextIntermediateBellRemaining: TimeInterval? {
        let elapsed = max(0, totalTime - timeLeft)
        for bellSecond in scheduledIntermediateBellSeconds {
            let remaining = TimeInterval(bellSecond) - elapsed
            if remaining > 0.5 {
                return remaining
            }
        }
        return nil
    }

    private var nextOvertimeBellRemaining: TimeInterval? {
        guard hasIntermediateBells else { return nil }
        let spacing = max(1, Int(round(intermediateBellSpacing)))
        let elapsed = max(0, overtimeElapsed)
        let nextBell = ceil((elapsed + 0.001) / Double(spacing)) * Double(spacing)
        return max(0, nextBell - elapsed)
    }

    private var sessionBellStatusText: String? {
        guard isSessionActive && !countdownActive && hasIntermediateBells else {
            return nil
        }

        if overtimeActive {
            guard let remaining = nextOvertimeBellRemaining else { return nil }
            return "Next bell in \(formatBellCountdownText(remaining))"
        }

        guard let remaining = nextIntermediateBellRemaining else { return nil }
        return "Next bell in \(formatBellCountdownText(remaining))"
    }

    private func formatBellCountdownText(_ seconds: TimeInterval) -> String {
        let roundedMinutes = Int(ceil(max(0, seconds) / 60))
        guard roundedMinutes > 0 else {
            return "<1m"
        }
        return "\(roundedMinutes)m"
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalRounded = Int(round(seconds))
        let mins = totalRounded / 60
        let secs = totalRounded % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    private func stopAllGongs() {
        cancelPendingEndGongReplay()
        if let player = startPlayer, player.isPlaying {
            player.stop()
        }
        if let player = tingshaPlayer, player.isPlaying {
            player.stop()
        }
    }

    private func updateTotalTime(_ value: TimeInterval) {
        let capped = min(maxMeditationTime, max(60, value))
        totalTime = capped
        timeLeft = capped
        isRunning = false
        countdownActive = false
        sessionStartTime = nil
        accumulatedElapsed = 0
        lastProcessedSecond = 0
        overtimeActive = false
        overtimeStartTime = nil
        overtimeAccumulated = 0
        overtimeElapsed = 0

        if intervalInputMode == "count" {
            intervalCount = min(max(1, intervalCount), maxIntervalSectionCount)
            intervalX = capped / Double(intervalCount)
        } else {
            intervalX = max(5, intervalX)
            intervalCount = sectionCount(forTotal: capped, fixedInterval: intervalX)
        }

        silentPlayer?.stop()
        bgTimer.stop()
        syncAllInputs()
    }
    
    private func toggleTimer() {
        triggerHaptic()
        if !isRunning {
            hideKeyboard()
            showSettings = false
            if overtimeActive {
                overtimeStartTime = Date()
            } else if timeLeft == totalTime && !countdownActive {
                if isCountdownEnabled {
                    countdownActive = true
                    countdownTimeLeft = countdownDuration
                } else {
                    playGong()
                }
                sessionStartTime = Date()
            } else {
                sessionStartTime = Date()
            }
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
            if overtimeActive, let start = overtimeStartTime {
                overtimeAccumulated += Date().timeIntervalSince(start)
                overtimeElapsed = overtimeAccumulated
            } else if let start = sessionStartTime {
                accumulatedElapsed += Date().timeIntervalSince(start)
            }
            sessionStartTime = nil
            overtimeStartTime = nil
            isRunning = false
            stopAllGongs()
            
            // Stop background timers
            silentPlayer?.stop()
            bgTimer.stop()
        }
    }
    
    private func resetTimer() {
        triggerHaptic()
        hideKeyboard()
        showSettings = false
        isRunning = false
        countdownActive = false
        sessionStartTime = nil
        overtimeStartTime = nil
        accumulatedElapsed = 0
        lastProcessedSecond = 0
        overtimeActive = false
        overtimeAccumulated = 0
        overtimeElapsed = 0
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
            if overtimeActive {
                if let start = overtimeStartTime {
                    overtimeElapsed = overtimeAccumulated + Date().timeIntervalSince(start)
                }
                playOvertimeIntermediateBellIfNeeded(currentSecond: Int(overtimeElapsed))
                timeLeft = 0
                return
            }

            guard let start = sessionStartTime else { return }
            let totalElapsed = accumulatedElapsed + Date().timeIntervalSince(start)
            let newTimeLeft = max(0, totalTime - totalElapsed)
            timeLeft = newTimeLeft
            
            let currentSecond = Int(totalElapsed)
            if currentSecond > lastProcessedSecond {
                let scheduledBells = Set(scheduledIntermediateBellSeconds)
                for sec in (lastProcessedSecond + 1)...currentSecond {
                    if scheduledBells.contains(sec) {
                        playIntervalGong()
                    }
                }
                lastProcessedSecond = currentSecond
            }
            
            if newTimeLeft <= 0 {
                playEndGong()
                overtimeActive = true
                overtimeStartTime = Date()
                overtimeAccumulated = 0
                overtimeElapsed = 0
                timeLeft = 0
                sessionStartTime = nil
                accumulatedElapsed = 0
                lastProcessedSecond = 0
            }
        }
    }

    private func playOvertimeIntermediateBellIfNeeded(currentSecond: Int) {
        guard hasIntermediateBells, currentSecond > lastProcessedSecond else { return }

        let spacing = max(1, Int(round(intermediateBellSpacing)))
        for sec in (lastProcessedSecond + 1)...currentSecond {
            if sec > 0 && sec % spacing == 0 {
                playIntervalGong()
            }
        }
        lastProcessedSecond = currentSecond
    }

    private func cancelPendingEndGongReplay() {
        endGongReplayWorkItem?.cancel()
        endGongReplayWorkItem = nil
    }

    private func endGongReplayDelay() -> TimeInterval {
        guard let player = startPlayer else {
            return 4.0
        }

        let rate = max(0.1, Double(player.rate))
        return max(1.5, player.duration / rate + 0.25)
    }
    
    // Direct inputs committing
    private func commitField(_ field: String) {
        switch field {
        case "totalMins":
            let mins = Int(totalMinsInput) ?? 0
            let newTotal = TimeInterval(mins * 60)
            if newTotal >= 60 {
                let capped = min(maxMeditationTime, newTotal)
                totalTime = capped
                timeLeft = capped
                isRunning = false
                
                if intervalInputMode == "count" {
                    intervalCount = min(max(1, intervalCount), maxIntervalSectionCount)
                    intervalX = capped / Double(intervalCount)
                } else {
                    intervalX = max(5, intervalX)
                    intervalCount = sectionCount(forTotal: capped, fixedInterval: intervalX)
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
            let count = min(max(1, Int(intervalCountInput) ?? 2), maxIntervalSectionCount)
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
            let val = Int(countdownDurationInput) ?? Int(defaultCountdownDuration)
            countdownDuration = max(3, min(maxCountdownDuration, TimeInterval(val)))
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
            intervalCountInput = String(min(maxIntervalSectionCount, max(1, current + (up ? 1 : -1))))
            commitField("intervalCount")
        case "countdown":
            let current = Int(countdownDurationInput) ?? Int(defaultCountdownDuration)
            countdownDurationInput = String(max(3, current + (up ? 1 : -1)))
            commitField("countdown")
        default:
            break
        }
    }
    
    private func handleIntervalModeChange() {
        if intervalInputMode == "time" {
            let rounded = max(5, round(intervalX))
            intervalX = rounded
            intervalCount = sectionCount(forTotal: totalTime, fixedInterval: rounded)
            isCustomInterval = true
        } else {
            let count = min(max(1, intervalCount), maxIntervalSectionCount)
            if count >= 1 {
                intervalCount = count
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
        
        // sync interval time inputs
        let im = Int(intervalX) / 60
        let isSec = Int(round(intervalX.truncatingRemainder(dividingBy: 60)))
        intervalMinsInput = String(im)
        intervalSecsInput = String(format: "%02d", isSec)
        
        // sync count input
        let count = intervalInputMode == "count" ? min(intervalCount, maxIntervalSectionCount) : (intervalX > 0 ? Int(round(totalTime / intervalX)) : 2)
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
        cancelPendingEndGongReplay()
        playGong()
        let replay = DispatchWorkItem {
            self.playGong()
            self.endGongReplayWorkItem = nil
        }
        endGongReplayWorkItem = replay
        DispatchQueue.main.asyncAfter(deadline: .now() + endGongReplayDelay(), execute: replay)
    }
    
    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func dismissSettings() {
        withAnimation(.easeInOut(duration: 0.3)) {
            hideKeyboard()
            showSettings = false
        }
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
                        .foregroundColor(selection == option.1 ? Color(red: 44.0 / 255.0, green: 37.0 / 255.0, blue: 22.0 / 255.0) : Color(red: 176.0 / 255.0, green: 137.0 / 255.0, blue: 62.0 / 255.0))
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
                                                    Color(red: 224.0 / 255.0, green: 174.0 / 255.0, blue: 64.0 / 255.0),
                                                    Color(red: 197.0 / 255.0, green: 145.0 / 255.0, blue: 43.0 / 255.0)
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
