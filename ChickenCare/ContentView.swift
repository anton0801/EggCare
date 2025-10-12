import SwiftUI
import AppsFlyerLib
import Firebase
import FirebaseMessaging
import UserNotifications
import WebKit
import Network
import AppTrackingTransparency

class AppDelegate: UIResponder, UIApplicationDelegate, AppsFlyerLibDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    
    var window: UIWindow?
    private var conversionData: [AnyHashable: Any] = [:]
    private var isFirstLaunch: Bool = true
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()
        
        // Initialize AppsFlyer
        AppsFlyerLib.shared().appsFlyerDevKey = "t7wmt7Ap8ZPiRfgTXoMo67"
        AppsFlyerLib.shared().appleAppID = "6753303972"
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().start()
        
        // Firebase Messaging delegat
        Messaging.messaging().delegate = self
        
        UNUserNotificationCenter.current().delegate = self
        
        application.registerForRemoteNotifications()
        
        if let remoteNotification = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            handleNotificationPayload(remoteNotification)
        }
        
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            if path.status != .satisfied {
                self.handleNoInternet()
                return
            }
        }
        monitor.start(queue: DispatchQueue.global())
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(activateApps),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        return true
    }
    
    
    @objc private func activateApps() {
        AppsFlyerLib.shared().start()
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
            }
        }
    }
    
    // AppsFlyer Delegate Methods
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        conversionData = data
        NotificationCenter.default.post(name: Notification.Name("ConversionDataReceived"), object: nil, userInfo: ["conversionData": conversionData])
    }
    
    func onConversionDataFail(_ error: Error) {
        NotificationCenter.default.post(name: Notification.Name("ConversionDataReceived"), object: nil, userInfo: ["conversionData": [:]])
//        if UserDefaults.standard.string(forKey: "saved_url") == nil {
//            setModeToFuntik()
//        }
    }
    
    private func handleConfigError() {
        if let savedURL = UserDefaults.standard.string(forKey: "saved_url") {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("UpdateUI"), object: nil)
            }
        } else {
            setModeToFuntik()
        }
    }
    
    private func setModeToFuntik() {
        UserDefaults.standard.set("Funtik", forKey: "app_mode")
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("UpdateUI"), object: nil)
        }
    }
    
    private func handleNoInternet() {
        let mode = UserDefaults.standard.string(forKey: "app_mode")
        if mode == "WebView" {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("ShowNoInternet"), object: nil)
            }
        } else {
            setModeToFuntik()
        }
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        // Upon token update, send new request
        messaging.token { token, error in
            if let error = error {
            }
            UserDefaults.standard.set(token, forKey: "fcm_token")
        }
        // sendConfigRequest()
    }
    
    // APNS Token
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }
    
    // Notification Delegates
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        handleNotificationPayload(userInfo)
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        handleNotificationPayload(userInfo)
        completionHandler()
    }
    
    func application(_ application: UIApplication,
                             didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        handleNotificationPayload(userInfo)
        completionHandler(.newData)
    }
    
    private func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        var urlString: String?
        if let url = userInfo["url"] as? String {
            urlString = url
        } else if let data = userInfo["data"] as? [String: Any], let url = data["url"] as? String {
            urlString = url
        }
        
        if let urlString = urlString {
            UserDefaults.standard.set(urlString, forKey: "temp_url")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                NotificationCenter.default.post(name: NSNotification.Name("LoadTempURL"), object: nil, userInfo: ["tempUrl": urlString])
            }
        }
    }
    
    private func showNotificationPermissionScreen() {
        // Check if already asked and time elapsed
        if let lastAsk = UserDefaults.standard.value(forKey: "last_notification_ask") as? Date,
           Date().timeIntervalSince(lastAsk) < 259200 {
            return
        }
        
        // Show custom screen via notification or something, handled in SwiftUI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ShowNotificationScreen"), object: nil)
        }
    }
}

// Define colors based on the design from screenshots
extension Color {
    static let warmWhite = Color(hex: "#FFF9E6") // Background
    static let sunnyYellow = Color(hex: "#FFD93D") // Eggs, buttons
    static let coralPink = Color(hex: "#FF6B6B") // Accents, charts
    static let skyBlue = Color(hex: "#4A90E2") // Chickens, buttons
    static let freshGreen = Color(hex: "#3DD598") // Health, trends
    static let goldenOrange = Color(hex: "#FFB84C") // Tabs, accents
    static let violetPurple = Color(hex: "#A259FF") // Freshness status
    static let darkText = Color(hex: "#333333") // Main text
    static let grayText = Color(hex: "#6B7280") // Subtext
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    static func getColorFromName(_ name: String, default: Color = .gray) -> Color {
        switch name {
        case "freshGreen": return .freshGreen
        case "sunnyYellow": return .sunnyYellow
        case "coralPink": return .coralPink
        default: return `default`
        }
    }
}

// Data models
struct Chicken: Identifiable, Codable {
    let id = UUID()
    var name: String
    var breed: String
    var health: String
    var age: String
    var avatar: String
}

struct EggLogEntry: Identifiable, Codable {
    let id = UUID()
    let date: Date
    var count: Int
}

struct Achievement: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let unlocked: Bool
    let icon: String
    let progress: Double?
}

struct FreshnessResult: Codable {
    let status: String
    let daysOld: Int
    let message: String
    let emoji: String
    let color: String
}

// Data Storage Struct
struct AppData: Codable {
    let chickens: [Chicken]
    let eggLogs: [EggLogEntry]
    let achievements: [Achievement]
    let eggsToday: Int
}

class AppState: ObservableObject {
    @Published var chickens: [Chicken] = [] {
        didSet { saveData() }
    }
    @Published var eggLogs: [EggLogEntry] = [] {
        didSet { saveData() }
    }
    @Published var achievements: [Achievement] = [] {
        didSet { saveData() }
    }
    @Published var eggsToday: Int = 0 {
        didSet {
            if let index = eggLogs.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
                eggLogs[index].count = eggsToday
            } else {
                eggLogs.insert(EggLogEntry(date: Date(), count: eggsToday), at: 0)
            }
            saveData()
        }
    }
    
    @Published var showAlert = false
    
    init() {
        loadData()
        if chickens.isEmpty || eggLogs.isEmpty || achievements.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            chickens = [
                Chicken(name: "Clucky", breed: "Rhode Island Red", health: "excellent", age: "8 months", avatar: "chicken1"),
                Chicken(name: "Henrietta", breed: "Leghorn", health: "good", age: "6 months", avatar: "chicken2")
            ]
            eggLogs = [
                EggLogEntry(date: formatter.date(from: "26.09.2025") ?? Date(), count: 3),
                EggLogEntry(date: formatter.date(from: "25.09.2025") ?? Date(), count: 2)
            ]
            achievements = [
                Achievement(title: "First Egg", description: "Collected your first egg", unlocked: true, icon: "circle.fill", progress: nil),
                Achievement(title: "Dozen Master", description: "Collected 12 eggs in a day", unlocked: false, icon: "cube", progress: 0.3)
            ]
            eggsToday = eggLogs.first?.count ?? 0
            saveData()
        }
    }
    
    var totalEggs: Int { eggLogs.reduce(0) { $0 + $1.count } }
    var dailyAvg: Double { eggLogs.isEmpty ? 0 : Double(totalEggs) / Double(eggLogs.count) }
    var bestDay: Int { eggLogs.max(by: { $0.count < $1.count })?.count ?? 0 }
    var totalChickens: Int { chickens.count }
    var bestWeek: Int = 45
    var perChicken: Double = 7.3
    var monthlyTrend: Double = 12.5
    
    func addChicken(name: String, breed: String, age: String) {
        let newChicken = Chicken(name: name, breed: breed, health: "good", age: age, avatar: "chicken\(chickens.count + 1)")
        chickens.append(newChicken)
    }
    
    func addEgg() {
        eggsToday += 1
        showAlert = true
    }
    
    func getFreshness(collectionDate: Date) -> FreshnessResult {
        let daysOld = Calendar.current.dateComponents([.day], from: collectionDate, to: Date()).day ?? 0
        if daysOld <= 7 {
            return FreshnessResult(status: "FRESH", daysOld: daysOld, message: "These eggs are perfectly fresh and safe to eat!", emoji: "😊", color: "freshGreen")
        } else if daysOld <= 21 {
            return FreshnessResult(status: "USE SOON", daysOld: daysOld, message: "These eggs should be used soon but are still good!", emoji: "😅", color: "sunnyYellow")
        } else {
            return FreshnessResult(status: "EXPIRED", daysOld: daysOld, message: "These eggs are expired. Better discard them.", emoji: "😢", color: "coralPink")
        }
    }
    
    private func saveData() {
        let dataToSave = AppData(chickens: chickens, eggLogs: eggLogs, achievements: achievements, eggsToday: eggsToday)
        if let encoded = try? JSONEncoder().encode(dataToSave) {
            UserDefaults.standard.set(encoded, forKey: "ChickenCareData")
        }
    }
    
    private func loadData() {
        if let savedData = UserDefaults.standard.data(forKey: "ChickenCareData"),
           let decodedData = try? JSONDecoder().decode(AppData.self, from: savedData) {
            chickens = decodedData.chickens
            eggLogs = decodedData.eggLogs
            achievements = decodedData.achievements
            eggsToday = decodedData.eggsToday
        }
    }
}

struct NoInternetView: View {
    var retryAction: () -> Void
    
    var body: some View {
        VStack {
            Text("No Internet Connection")
            Button("Retry") {
                retryAction()
            }
        }
    }
}

struct NotificationPermissionView: View {
    var onYes: () -> Void
    var onSkip: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                if isLandscape {
                    Image("splash_back_land")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                } else {
                    Image("notifications_back")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                }
                
                VStack(spacing: isLandscape ? 10 : 20) {
                    Spacer()
                    
                    if isLandscape {
                        Image("title_1")
                            .resizable()
                            .frame(width: 520, height: 20)
                        Image("title_2")
                            .resizable()
                            .frame(width: 450, height: 20)
                            .padding(.bottom)
                    }
                    
                    Button(action: onYes) {
                        Image("want_btn")
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: isLandscape ? geometry.size.width * 0.6 : 350,
                                height: isLandscape ? 50 : 70
                            )
                    }
                    
                    Button(action: onSkip) {
                        Image("skip_btn")
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: isLandscape ? geometry.size.width * 0.2 : 50,
                                height: isLandscape ? 15 : 20
                            )
                    }
                    
                    Spacer()
                        .frame(height: isLandscape ? 20 : 10)
                }
                .padding(.horizontal, isLandscape ? 20 : 0)
            }
            
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

class SplashViewModel: ObservableObject {
    @Published var currentScreen: Screen = .loading
    @Published var webViewURL: URL?
    @Published var showNotificationScreen = false
    
    private var conversionData: [AnyHashable: Any] = [:]
    private var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "hasLaunched")
    }
    
    enum Screen {
        case loading
        case webView
        case funtik
        case noInternet
    }
    
    init() {
        // Setup notification observers
        NotificationCenter.default.addObserver(self, selector: #selector(handleConversionData(_:)), name: NSNotification.Name("ConversionDataReceived"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleConversionError(_:)), name: NSNotification.Name("ConversionDataFailed"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleFCMToken(_:)), name: NSNotification.Name("FCMTokenUpdated"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(retryConfig), name: NSNotification.Name("RetryConfig"), object: nil)
        
        // Start processing
        checkInternetAndProceed()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func checkInternetAndProceed() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status != .satisfied {
                    self.handleNoInternet()
                } else {
                    // self.checkExpiresAndRequest()
                }
            }
        }
        monitor.start(queue: DispatchQueue.global())
    }
    
    @objc private func handleConversionData(_ notification: Notification) {
        conversionData = (notification.userInfo ?? [:])["conversionData"] as? [AnyHashable: Any] ?? [:]
        processConversionData()
    }
    
    @objc private func handleConversionError(_ notification: Notification) {
        handleConfigError()
    }
    
    @objc private func handleFCMToken(_ notification: Notification) {
        // Trigger new config request on token update
        if let token = notification.object as? String {
            UserDefaults.standard.set(token, forKey: "fcm_token")
            // sendConfigRequest()
        }
    }
    
    @objc private func handleNotificationURL(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any],
              let tempUrl = userInfo["tempUrl"] as? String else {
            return
        }
        
        DispatchQueue.main.async {
            self.webViewURL = URL(string: tempUrl)!
            self.currentScreen = .webView
        }
    }
    
    @objc private func retryConfig() {
        checkInternetAndProceed()
    }
    
    private func processConversionData() {
        guard !conversionData.isEmpty else { return }
        
        if UserDefaults.standard.string(forKey: "app_mode") == "Funtik" {
            DispatchQueue.main.async {
                self.currentScreen = .funtik
            }
            return
        }
        
        if isFirstLaunch {
            if let afStatus = conversionData["af_status"] as? String, afStatus == "Organic" {
                self.setModeToFuntik()
                return
            }
        }
        
        if let link = UserDefaults.standard.string(forKey: "temp_url"), !link.isEmpty {
            webViewURL = URL(string: link)
            self.currentScreen = .webView
            NotificationCenter.default.post(name: Notification.Name("show_alert"), object: nil, userInfo: ["data": "url: \(link) link received and no config reuqest"])
            return
        }
        
        // усли не с пуша открыли запрашиваем
        if webViewURL == nil {
            if !UserDefaults.standard.bool(forKey: "accepted_notifications") && !UserDefaults.standard.bool(forKey: "system_close_notifications") {
                checkAndShowNotificationScreen()
            } else {
                sendConfigRequest()
            }
        }
    }
    
    func sendConfigRequest() {
        guard let url = URL(string: "https://eggcarre.com/config.php") else {
            handleConfigError()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body = conversionData
        body["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        body["bundle_id"] = Bundle.main.bundleIdentifier ?? "com.example.app"
        body["os"] = "iOS"
        body["store_id"] = "id6753303972"
        body["locale"] = Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"
        body["push_token"] = UserDefaults.standard.string(forKey: "fcm_token") ?? Messaging.messaging().fcmToken
        body["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            handleConfigError()
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let _ = error {
                    self.handleConfigError()
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let data = data else {
                    self.handleConfigError()
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let ok = json["ok"] as? Bool, ok {
                            if let urlString = json["url"] as? String, let expires = json["expires"] as? TimeInterval {
                                UserDefaults.standard.set(urlString, forKey: "saved_url")
                                UserDefaults.standard.set(expires, forKey: "saved_expires")
                                UserDefaults.standard.set("WebView", forKey: "app_mode")
                                UserDefaults.standard.set(true, forKey: "hasLaunched")
                                self.webViewURL = URL(string: urlString)
                                self.currentScreen = .webView
                                
                                if self.isFirstLaunch {
                                    self.checkAndShowNotificationScreen()
                                }
                            }
                        } else {
                            self.setModeToFuntik()
                        }
                    }
                } catch {
                    self.handleConfigError()
                }
            }
        }.resume()
    }
    
    private func handleConfigError() {
        if let savedURL = UserDefaults.standard.string(forKey: "saved_url"), let url = URL(string: savedURL) {
            webViewURL = url
            currentScreen = .webView
        } else {
            setModeToFuntik()
        }
    }
    
    private func setModeToFuntik() {
        UserDefaults.standard.set("Funtik", forKey: "app_mode")
        UserDefaults.standard.set(true, forKey: "hasLaunched")
        DispatchQueue.main.async {
            self.currentScreen = .funtik
        }
    }
    
    private func handleNoInternet() {
        let mode = UserDefaults.standard.string(forKey: "app_mode")
        if mode == "WebView" {
            DispatchQueue.main.async {
                self.currentScreen = .noInternet
            }
        } else {
            setModeToFuntik()
        }
    }
    
//    private func checkExpiresAndRequest() {
//        if let expires = UserDefaults.standard.value(forKey: "saved_expires") as? TimeInterval,
//           expires < Date().timeIntervalSince1970 {
//            sendConfigRequest()
//        } else if let savedURL = UserDefaults.standard.string(forKey: "saved_url"),
//                  let url = URL(string: savedURL) {
//            webViewURL = url
//            currentScreen = .webView
//        } else {
//            if conversionData == nil {
//                currentScreen = .loading
//            } else {
//                sendConfigRequest()
//            }
//        }
//    }
    
    private func checkAndShowNotificationScreen() {
        if let lastAsk = UserDefaults.standard.value(forKey: "last_notification_ask") as? Date,
           Date().timeIntervalSince(lastAsk) < 259200 {
            sendConfigRequest()
            return
        }
        showNotificationScreen = true
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    UserDefaults.standard.set(true, forKey: "accepted_notifications")
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    UserDefaults.standard.set(false, forKey: "accepted_notifications")
                    UserDefaults.standard.set(true, forKey: "system_close_notifications")
                }
                self.sendConfigRequest()
                self.showNotificationScreen = false
                if let error = error {
                    print("Permission error: \(error)")
                }
            }
        }
    }
}

struct SplashView: View {
    
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SplashViewModel()
    
    @State var alertVisible = false
    @State var alertMessage = ""
    
    var body: some View {
        ZStack {
            if viewModel.currentScreen == .loading || viewModel.showNotificationScreen {
                splashScreen
            }
            
            if viewModel.showNotificationScreen {
                NotificationPermissionView(
                    onYes: {
                        viewModel.requestNotificationPermission()
                    },
                    onSkip: {
                        UserDefaults.standard.set(Date(), forKey: "last_notification_ask")
                        viewModel.showNotificationScreen = false
                        viewModel.sendConfigRequest()
                    }
                )
            } else {
                switch viewModel.currentScreen {
                case .loading:
                    EmptyView()
                case .webView:
                    if let url = viewModel.webViewURL {
                        CoreInterfaceView()
                        // MainBrowserView(destinationLink: url)
                    } else {
                        ContentView()
                            .environmentObject(appState)
                    }
                case .funtik:
                    ContentView()
                        .environmentObject(appState)
                case .noInternet:
                    NoInternetView {
                        NotificationCenter.default.post(name: NSNotification.Name("RetryConfig"), object: nil)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("show_alert"))) { notification in
            let data = (notification.userInfo as? [String: Any])?["data"] as? String
            alertVisible = true
            alertMessage = "data: \(data)"
        }
        .alert(isPresented: $alertVisible) {
            Alert(title: Text("Alert"), message: Text(alertMessage))
        }
    }
    
    @State private var animate = false
    
    private var splashScreen: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                if isLandscape {
                    Image("splash_back_land")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                } else {
                    Image("splash_back")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea()
                }
                
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom) {
                        Image("loading_ic")
                            .resizable()
                            .frame(width: 150, height: 25)
                        
                        ForEach(1..<4) { i in
                            Image("loading_point_ic")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .offset(y: animate ? -8 : 8) // Move up and down
                                .animation(
                                    Animation.easeInOut(duration: 0.6)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.1),
                                    value: animate
                                )
                        }
                    }
                    
                    Spacer()
                        .frame(height: isLandscape ? 30 : 100)
                }
            }
            
        }
        .ignoresSafeArea()
        .onAppear {
            animate = true
        }
    }
    
}


#Preview {
    SplashView()
        .environmentObject(AppState())
}

// Main App
@main
struct ChickenCareApp: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(appState)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: String = "home"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeDashboardView(selectedTab: $selectedTab)
                .tabItem {
                    VStack {
                        Image(systemName: "house")
                        Text("Home")
                    }
                }
                .tag("home")
            
            ChickenManagerView()
                .tabItem {
                    VStack {
                        Image(systemName: "person.3")
                        Text("Chickens")
                    }
                }
                .tag("chickens")
            
            EggLogView()
                .tabItem {
                    VStack {
                        Image(systemName: "oval")
                        Text("Eggs")
                    }
                }
                .tag("eggs")
            
            FreshnessCheckerView()
                .tabItem {
                    VStack {
                        Image(systemName: "thermometer")
                        Text("Freshness")
                    }
                }
                .tag("freshness")
            
            StatsView()
                .tabItem {
                    VStack {
                        Image(systemName: "chart.bar")
                        Text("Stats")
                    }
                }
                .tag("stats")
        }
        .accentColor(.goldenOrange)
        .background(Color.warmWhite)
        .font(.system(.body, design: .rounded))
    }
}

// Home Dashboard
struct HomeDashboardView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            Text("Egg Care")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.coralPink)
                            Text("Your feathered friends await!")
                                .font(.subheadline)
                                .foregroundColor(.grayText)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.8))
                                .frame(width: 60, height: 60)
                            Image(systemName: "oval")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.white)
                            Text("😟")
                                .font(.system(size: 20))
                                .offset(y: 5)
                        }
                        .overlay(Circle().stroke(Color.sunnyYellow, lineWidth: 2))
                    }
                }
                .padding(.horizontal)
                
                // Overview cards
                HStack(spacing: 16) {
                    OverviewCard(title: "Total Chickens", value: "\(appState.totalChickens)", icon: "person.3.sequence", gradient: LinearGradient(colors: [Color(hex: "#A5D8FF"), Color(hex: "#4A90E2")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    OverviewCard(title: "Eggs Today", value: "\(appState.eggsToday)", icon: "oval", gradient: LinearGradient(colors: [Color(hex: "#FFEAA7"), Color(hex: "#FFD93D")], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .padding(.horizontal)
                
                OverviewCard(title: "Freshness Status", value: "All Fresh! ⭐️", icon: "exclamationmark.circle", gradient: LinearGradient(colors: [.violetPurple.opacity(0.8), .coralPink.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    .padding(.horizontal)
                
                // Add Egg button
                Button(action: {
                    appState.addEgg()
                }) {
                    HStack {
                        Text("+")
                            .font(.title2.bold())
                        Text("Add Egg")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [Color(hex: "#FFE066"), Color(hex: "#FFB84C")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .foregroundColor(.white)
                    .cornerRadius(30)
                }
                .padding(.horizontal)
                .alert("Egg Added!", isPresented: $appState.showAlert) {
                    Button("OK") { }
                } message: {
                    Text("A new egg has been added to today's count!")
                }
                
                Text("Quick Actions")
                    .font(.title3.bold())
                    .foregroundColor(.darkText)
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Button {
                        selectedTab = "chickens"
                    } label: {
                        QuickActionButton(icon: "chicken.fill", title: "Add Chicken")
                    }
                    Button {
                        selectedTab = "freshness"
                    } label: {
                        QuickActionButton(icon: "snowflake", title: "Check Freshness")
                    }
                }
                .padding(.horizontal)
                Button {
                    UIApplication.shared.open(URL(string: "https://eggcarre.com/privacy-policy.html")!)
                } label: {
                    QuickActionButton(icon: "lock", title: "Privacy Policy")
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color.warmWhite)
    }
}

struct OverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: LinearGradient
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.3)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding()
        .background(gradient)
        .cornerRadius(20)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.grayText)
            Text(title)
                .font(.caption)
                .foregroundColor(.grayText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Chicken Manager
struct ChickenManagerView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddChicken = false
    @State private var newName = ""
    @State private var newBreed = ""
    @State private var newAge = ""
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("My Chickens")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.darkText)
                    Spacer()
                    Button(action: { showingAddChicken = true }) {
                        Text("+ Add Chicken")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(LinearGradient(colors: [.freshGreen.opacity(0.8), .skyBlue.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal)
                
                ForEach(appState.chickens) { chicken in
                    HStack(spacing: 12) {
                        Image(systemName: "photo.circle.fill") // Placeholder
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(.gray)
                            .background(Circle().fill(Color.white))
                            .overlay(Circle().stroke(Color.sunnyYellow, lineWidth: 2))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chicken.name)
                                .font(.headline)
                                .foregroundColor(.darkText)
                            Text(chicken.breed)
                                .font(.subheadline)
                                .foregroundColor(.grayText)
                        }
                        Spacer()
                        Text(chicken.health.capitalized)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(chicken.health == "excellent" ? Color.freshGreen : Color.sunnyYellow)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        Text(chicken.age)
                            .font(.caption)
                            .foregroundColor(.grayText)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
            }
            .padding(.vertical)
        }
        .background(Color.warmWhite)
        .sheet(isPresented: $showingAddChicken) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add New Chicken")
                    .font(.headline)
                    .foregroundColor(.darkText)
                
                TextField("Chicken name", text: $newName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Breed", text: $newBreed)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                TextField("Age (months)", text: $newAge)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                
                HStack {
                    Button("Add Chicken") {
                        if !newName.isEmpty && !newBreed.isEmpty && !newAge.isEmpty {
                            appState.addChicken(name: newName, breed: newBreed, age: "\(newAge) months")
                            showingAddChicken = false
                            newName = ""
                            newBreed = ""
                            newAge = ""
                        }
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.freshGreen)
                    .foregroundColor(.white)
                    .cornerRadius(30)
                    
                    Button("Cancel") {
                        showingAddChicken = false
                    }
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .foregroundColor(.grayText)
                    .cornerRadius(30)
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.grayText, lineWidth: 1))
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(radius: 10)
            .padding()
        }
    }
}

// Egg Log
struct EggLogView: View {
    @EnvironmentObject var appState: AppState
    @State private var viewMode: String = "Week"
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Egg Production")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.darkText)
                Text("Track your daily harvest")
                    .font(.subheadline)
                    .foregroundColor(.grayText)
                    .padding(.horizontal)
                
                // Today's Eggs
                VStack(spacing: 8) {
                    Image(systemName: "oval.portrait.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    Text("Today's Eggs")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(appState.eggsToday)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    HStack(spacing: 16) {
                        Button("-") {
                            if appState.eggsToday > 0 {
                                appState.eggsToday -= 1
                            }
                        }
                        .font(.title.bold())
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(25)
                        
                        Button("+ Add Egg") {
                            appState.eggsToday += 1
                        }
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .foregroundColor(.sunnyYellow)
                        .cornerRadius(25)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(LinearGradient(colors: [Color(hex: "#FFE066"), Color(hex: "#FFD93D")], startPoint: .top, endPoint: .bottom))
                .cornerRadius(20)
                .padding(.horizontal)
                
                // Small stats
                HStack(spacing: 16) {
                    SmallStatCard(title: "Total", value: "\(appState.totalEggs)", icon: "chart.bar.fill", color: .white)
                    SmallStatCard(title: "Daily Avg", value: String(format: "%.1f", appState.dailyAvg), icon: "chart.line.uptrend.xyaxis", color: .white)
                    SmallStatCard(title: "Best Day", value: "\(appState.bestDay)", icon: "trophy.fill", color: .white)
                }
                .padding(.horizontal)
                
                // Weekly Production
                HStack {
                    Text("Weekly Production")
                        .font(.title3.bold())
                        .foregroundColor(.darkText)
                    Spacer()
                    ToggleButton(title: "Week", isSelected: viewMode == "Week") { viewMode = "Week" }
                    ToggleButton(title: "Month", isSelected: viewMode == "Month") { viewMode = "Month" }
                }
                .padding(.horizontal)
                
                // Bar chart with animation
                HStack(spacing: 8) {
                    ForEach(0..<6) { index in
                        let heights: [CGFloat] = [100, 50, 120, 80, 60, 140] // Sample data
                        let color = index % 2 == 0 ? Color.sunnyYellow : Color.coralPink
                        VStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color)
                                .frame(width: 30, height: heights[index])
                                .animation(.spring(), value: heights[index])
                            Text(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri"][index])
                                .font(.caption2)
                                .foregroundColor(.grayText)
                        }
                    }
                }
                .frame(height: 180)
                .padding(.horizontal)
                
                // Achievements
                Text("Achievements")
                    .font(.title3.bold())
                    .foregroundColor(.goldenOrange)
                    .padding(.horizontal)
                
                ForEach(appState.achievements) { achievement in
                    HStack(spacing: 12) {
                        Image(systemName: achievement.icon)
                            .font(.title3)
                            .foregroundColor(.sunnyYellow)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(achievement.title)
                                .font(.subheadline.bold())
                                .foregroundColor(.darkText)
                            Text(achievement.description)
                                .font(.caption)
                                .foregroundColor(.grayText)
                            if let progress = achievement.progress {
                                ProgressView(value: progress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .sunnyYellow))
                                    .frame(height: 4)
                                    .animation(.easeInOut, value: progress)
                            }
                        }
                        Spacer()
                        if achievement.unlocked {
                            Text("Unlocked")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.freshGreen)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                
                // Recent Entries
                Text("Recent Entries")
                    .font(.title3.bold())
                    .foregroundColor(.darkText)
                    .padding(.horizontal)
                
                ForEach(appState.eggLogs) { entry in
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.grayText)
                        Text(entry.date, format: .dateTime.day().month().year())
                            .foregroundColor(.darkText)
                        Spacer()
                        Text("\(entry.count) eggs")
                            .foregroundColor(.grayText)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
            }
            .padding(.vertical)
        }
        .background(Color.warmWhite)
    }
}

struct ToggleButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.coralPink : Color.white)
                .foregroundColor(isSelected ? .white : .grayText)
                .cornerRadius(20)
                .shadow(color: .black.opacity(isSelected ? 0.1 : 0), radius: 2, x: 0, y: 1)
        }
    }
}

struct SmallStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.grayText)
            Text(title)
                .font(.caption)
                .foregroundColor(.grayText)
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.coralPink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Freshness Checker
struct FreshnessCheckerView: View {
    @EnvironmentObject var appState: AppState
    @State private var collectionDate: Date = Date()
    @State private var showResult = false
    @State private var freshness: FreshnessResult?
    @State private var showTips = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Freshness Checker")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.darkText)
                Text("Check if your eggs are still fresh")
                    .font(.subheadline)
                    .foregroundColor(.grayText)
                    .padding(.horizontal)
                
                VStack(spacing: 8) {
                    Image(systemName: "oval.portrait.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.grayText)
                    Text("When did you collect these eggs?")
                        .font(.headline)
                        .foregroundColor(.darkText)
                    Text("Select the collection date to check freshness")
                        .font(.subheadline)
                        .foregroundColor(.grayText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.grayText)
                    DatePicker("", selection: $collectionDate, displayedComponents: .date)
                        .labelsHidden()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                Button(action: {
                    freshness = appState.getFreshness(collectionDate: collectionDate)
                    withAnimation(.spring()) {
                        showResult = true
                    }
                }) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.white)
                        Text("Check Freshness")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(colors: [.skyBlue.opacity(0.8), .freshGreen.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(30)
                }
                .padding(.horizontal)
                
                if showResult, let freshness = freshness {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color.getColorFromName(freshness.color))
                            .frame(width: 50, height: 50)
                            .overlay(Text(freshness.emoji).font(.title))
                        
                        Text(freshness.status)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.getColorFromName(freshness.color))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                        
                        Text("\(freshness.daysOld) days old")
                            .font(.title.bold())
                            .foregroundColor(.darkText)
                        
                        Text(freshness.message)
                            .font(.subheadline)
                            .foregroundColor(.grayText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.warmWhite)
                    .cornerRadius(20)
                    .padding(.horizontal)
                    .transition(.scale)
                    
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.sunnyYellow)
                        Text("Storage Tips")
                            .font(.headline)
                            .foregroundColor(.darkText)
                        Spacer()
                        Button(showTips ? "Hide Tips" : "Show Tips") {
                            withAnimation(.easeInOut) {
                                showTips.toggle()
                            }
                        }
                        .foregroundColor(.skyBlue)
                    }
                    .padding(.horizontal)
                    
                    if showTips {
                        VStack(alignment: .leading, spacing: 8) {
                            TipItem(text: "Refrigerate 35-40°F")
                            TipItem(text: "Original Carton Keep protected")
                            TipItem(text: "Avoid Door storage")
                        }
                        .padding(.horizontal)
                        .transition(.opacity)
                    }
                    
                    Button("Check Another Batch") {
                        withAnimation {
                            showResult = false
                            collectionDate = Date()
                        }
                    }
                    .font(.headline)
                    .padding()
                    .background(Color.sunnyYellow)
                    .foregroundColor(.darkText)
                    .cornerRadius(30)
                    .padding(.horizontal)
                }
                
                HStack(spacing: 16) {
                    DateShortcutButton(title: "Today", icon: "calendar.badge.clock", offset: 0) { collectionDate = $0 }
                    DateShortcutButton(title: "Yesterday", icon: "arrow.left.square", offset: -1) { collectionDate = $0 }
                    DateShortcutButton(title: "Week Ago", icon: "chart.bar.doc.horizontal", offset: -7) { collectionDate = $0 }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.warmWhite)
    }
}

struct TipItem: View {
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.freshGreen)
            Text(text)
                .foregroundColor(.grayText)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct DateShortcutButton: View {
    let title: String
    let icon: String
    let offset: Int
    let action: (Date) -> Void
    
    var body: some View {
        Button(action: { action(Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()) }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(.grayText)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.grayText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

// Stats
struct StatsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Statistics")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.darkText)
                Text("Track your farm's performance")
                    .font(.subheadline)
                    .foregroundColor(.grayText)
                    .padding(.horizontal)
                
                // Stat cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(title: "Total Eggs", value: "\(appState.totalEggs)", icon: "oval", gradient: LinearGradient(colors: [Color(hex: "#FFE066"), Color(hex: "#FFD93D")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    StatCard(title: "Daily Average", value: String(format: "%.1f", appState.dailyAvg), icon: "arrow.up", gradient: LinearGradient(colors: [Color(hex: "#A5D8FF"), Color(hex: "#4A90E2")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    StatCard(title: "Best Week", value: "\(appState.bestWeek)", icon: "crown", gradient: LinearGradient(colors: [.violetPurple.opacity(0.8), .coralPink.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    StatCard(title: "Per Chicken", value: String(format: "%.1f", appState.perChicken), icon: "person.3.sequence", gradient: LinearGradient(colors: [Color(hex: "#B2F2BB"), Color(hex: "#3DD598")], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .padding(.horizontal)
                
                // Weekly Performance
                VStack(alignment: .leading) {
                    Text("Weekly Performance")
                        .font(.title3.bold())
                        .foregroundColor(.darkText)
                    // Animated bar chart
                    HStack(spacing: 16) {
                        ForEach(1...4, id: \.self) { week in
                            let heights: [CGFloat] = [80, 120, 100, 140] // Sample data
                            VStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(week == 4 ? Color.gray : Color.skyBlue)
                                    .frame(width: 40, height: heights[week-1])
                                    .animation(.easeInOut(duration: 1.0).delay(Double(week) * 0.2), value: heights[week-1])
                                Text("Week \(week)")
                                    .font(.caption)
                                    .foregroundColor(.grayText)
                            }
                        }
                    }
                    .frame(height: 180)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal)
                
                // Chicken Health Overview
                VStack(alignment: .leading) {
                    Text("Chicken Health Overview")
                        .font(.title3.bold())
                        .foregroundColor(.darkText)
                    HStack {
                        PieChart(slices: [0.6, 0.3, 0.1], colors: [.freshGreen, .sunnyYellow, .coralPink])
                            .frame(width: 100, height: 100)
                        VStack(alignment: .leading) {
                            HealthLegend(color: .freshGreen, label: "Excellent", percent: "60%")
                            HealthLegend(color: .sunnyYellow, label: "Good", percent: "30%")
                            HealthLegend(color: .coralPink, label: "Needs Attention", percent: "10%")
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal)
                .animation(.easeInOut, value: 0.6)
                
                // Farm Alerts
                Text("Farm Alerts")
                    .font(.title3.bold())
                    .foregroundColor(.darkText)
                    .padding(.horizontal)
                
                VStack(spacing: 8) {
                    AlertItem(icon: "lightbulb", title: "Great productivity this month!", message: "Your chickens laid 12.5% more eggs than last month.")
                    AlertItem(icon: "alarm", title: "Coop cleaning reminder", message: "It's been 5 days since the last deep clean.")
                    AlertItem(icon: "star", title: "Achievement unlocked!", message: "You've collected over 100 eggs this month.")
                }
                .padding(.horizontal)
                
                // Bottom stats
                HStack(spacing: 16) {
                    SmallStatCard(title: "Days Active", value: "8", icon: "calendar", color: .white)
                    SmallStatCard(title: "Achievements", value: "8/12", icon: "trophy.fill", color: .white)
                    SmallStatCard(title: "Efficiency", value: "94%", icon: "chart.line.uptrend.xyaxis", color: .white)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color.warmWhite)
    }
}

struct PieChart: View {
    let slices: [Double]
    let colors: [Color]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<slices.count, id: \.self) { i in
                    PieSlice(startAngle: .degrees(calculateStartAngle(for: i)), endAngle: .degrees(calculateEndAngle(for: i)), color: colors[i])
                        .animation(.easeInOut(duration: 1.0).delay(Double(i) * 0.2))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private func calculateStartAngle(for index: Int) -> Double {
        let sumOfSlices = slices.reduce(0, +)
        var startAngle: Double = 0
        for i in 0..<index {
            startAngle += 360 * (slices[i] / sumOfSlices)
        }
        return startAngle
    }
    
    private func calculateEndAngle(for index: Int) -> Double {
        let sumOfSlices = slices.reduce(0, +)
        let angle = 360 * (slices[index] / sumOfSlices)
        return calculateStartAngle(for: index) + angle
    }
}

struct PieSlice: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    
    var body: some View {
        Path { path in
            let center = CGPoint(x: 50, y: 50)
            let radius: CGFloat = 50
            path.move(to: center)
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            path.closeSubpath()
        }
        .fill(color)
    }
}

struct HealthLegend: View {
    let color: Color
    let label: String
    let percent: String
    
    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label)
                .foregroundColor(.grayText)
            Spacer()
            Text(percent)
                .foregroundColor(.darkText)
        }
    }
}

struct AlertItem: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.sunnyYellow)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.darkText)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.grayText)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: LinearGradient
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.3)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                Text(value)
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding()
        .background(gradient)
        .cornerRadius(20)
    }
}

class BrowserDelegateManager: NSObject, WKNavigationDelegate, WKUIDelegate {
    private let contentManager: ContentManager
    
    private var redirectCount: Int = 0
    private let maxRedirects: Int = 70 // Для тестов
    private var lastValidURL: URL?

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let space = challenge.protectionSpace
        if space.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let trust = space.serverTrust {
                let cred = URLCredential(trust: trust)
                completionHandler(.useCredential, cred)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    init(manager: ContentManager) {
        self.contentManager = manager
        super.init()
    }
    
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else {
            return nil
        }
        
        let newBrowser = BrowserCreator.createPrimaryBrowser(with: configuration)
        setupNewBrowser(newBrowser)
        attachNewBrowser(newBrowser)
        
        contentManager.additionalBrowsers.append(newBrowser)
        if shouldLoadRequest(in: newBrowser, with: navigationAction.request) {
            newBrowser.load(navigationAction.request)
        }
        return newBrowser
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Enforce no-zoom policy with viewport and CSS overrides
        let script = """
                var viewportMeta = document.createElement('meta');
                viewportMeta.name = 'viewport';
                viewportMeta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
                document.getElementsByTagName('head')[0].appendChild(viewportMeta);
                var cssOverride = document.createElement('style');
                cssOverride.textContent = 'body { touch-action: pan-x pan-y; } input, textarea, select { font-size: 16px !important; maximum-scale=1.0; }';
                document.getElementsByTagName('head')[0].appendChild(cssOverride);
                document.addEventListener('gesturestart', function(e) { e.preventDefault(); });
                """;
        webView.evaluateJavaScript(script) { _, error in
            if let error = error {
                print("Script injection error: \(error)")
            }
        }
        
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        redirectCount += 1
        if redirectCount > maxRedirects {
            webView.stopLoading()
            if let fallbackURL = lastValidURL {
                webView.load(URLRequest(url: fallbackURL))
            }
            return
        }
        lastValidURL = webView.url // Сохраняем последний рабочий URL
        saveCookies(from: webView)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorHTTPTooManyRedirects, let fallbackURL = lastValidURL {
            webView.load(URLRequest(url: fallbackURL))
        }
    }
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let link = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        if link.absoluteString.starts(with: "http") || link.absoluteString.starts(with: "https") {
            lastValidURL = link
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(link, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
        }
    }
    
    private func setupNewBrowser(_ browser: WKWebView) {
        browser.translatesAutoresizingMaskIntoConstraints = false
        browser.scrollView.isScrollEnabled = true
        browser.scrollView.minimumZoomScale = 1.0
        browser.scrollView.maximumZoomScale = 1.0
        browser.scrollView.bouncesZoom = false
        browser.allowsBackForwardNavigationGestures = true
        browser.navigationDelegate = self
        browser.uiDelegate = self
        contentManager.primaryBrowser.addSubview(browser)
        
        // Добавляем свайп для наложенного WKWebView
        let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        edgePan.edges = .left
        browser.addGestureRecognizer(edgePan)
    }
    
    private func attachNewBrowser(_ browser: WKWebView) {
        NSLayoutConstraint.activate([
            browser.leadingAnchor.constraint(equalTo: contentManager.primaryBrowser.leadingAnchor),
            browser.trailingAnchor.constraint(equalTo: contentManager.primaryBrowser.trailingAnchor),
            browser.topAnchor.constraint(equalTo: contentManager.primaryBrowser.topAnchor),
            browser.bottomAnchor.constraint(equalTo: contentManager.primaryBrowser.bottomAnchor)
        ])
    }
    
    private func shouldLoadRequest(in browser: WKWebView, with request: URLRequest) -> Bool {
        if let urlString = request.url?.absoluteString, !urlString.isEmpty, urlString != "about:blank" {
            return true
        }
        return false
    }
    
    private func saveCookies(from browser: WKWebView) {
        browser.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            var cookiesByDomain: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            for cookie in cookies {
                var domainCookies = cookiesByDomain[cookie.domain] ?? [:]
                domainCookies[cookie.name] = cookie.properties as? [HTTPCookiePropertyKey: Any]
                cookiesByDomain[cookie.domain] = domainCookies
            }
            UserDefaults.standard.set(cookiesByDomain, forKey: "stored_cookies")
        }
    }
}

struct BrowserCreator {
    
    static func createPrimaryBrowser(with config: WKWebViewConfiguration? = nil) -> WKWebView {
        let configuration = config ?? buildConfiguration()
        return WKWebView(frame: .zero, configuration: configuration)
    }
    
    private static func buildConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.preferences = buildPreferences()
        config.defaultWebpagePreferences = buildWebpagePreferences()
        config.requiresUserActionForMediaPlayback = false
        return config
    }
    
    private static func buildPreferences() -> WKPreferences {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        return preferences
    }
    
    private static func buildWebpagePreferences() -> WKWebpagePreferences {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        return preferences
    }
    
    static func shouldCleanAdditional(_ primary: WKWebView, _ additions: [WKWebView], currentLink: URL?) -> Bool {
        if !additions.isEmpty {
            additions.forEach { $0.removeFromSuperview() }
            if let link = currentLink {
                primary.load(URLRequest(url: link))
            }
            return true
        } else if primary.canGoBack {
            primary.goBack()
            return false
        }
        return false
    }
}

extension Notification.Name {
    static let interfaceActions = Notification.Name("ui_actions")
}

class ContentManager: ObservableObject {
    @Published var primaryBrowser: WKWebView!
    @Published var additionalBrowsers: [WKWebView] = []
    
    func setupPrimaryBrowser() {
        primaryBrowser = BrowserCreator.createPrimaryBrowser()
        primaryBrowser.scrollView.minimumZoomScale = 1.0
        primaryBrowser.scrollView.maximumZoomScale = 1.0
        primaryBrowser.scrollView.bouncesZoom = false
        primaryBrowser.allowsBackForwardNavigationGestures = true
    }
    
    func loadStoredCookies() {
        guard let storedCookies = UserDefaults.standard.dictionary(forKey: "stored_cookies") as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        let cookieStore = primaryBrowser.configuration.websiteDataStore.httpCookieStore
        
        storedCookies.values.flatMap { $0.values }.forEach { properties in
            if let cookie = HTTPCookie(properties: properties as! [HTTPCookiePropertyKey: Any]) {
                cookieStore.setCookie(cookie)
            }
        }
    }
    
    func refreshContent() {
        primaryBrowser.reload()
    }
    
    func cleanAdditionalBrowsersIfNeeded(for link: URL?) {
//        if BrowserCreator.shouldCleanAdditional(primaryBrowser, additionalBrowsers, currentLink: link) {
//            additionalBrowsers.removeAll()
//        }
        
        
    }
    
    func shouldCleanAdditional(currentLink: URL?) {
        if !additionalBrowsers.isEmpty {
            if let lastOverlay = additionalBrowsers.last {
                lastOverlay.removeFromSuperview()
                additionalBrowsers.removeLast()
            }
            if let link = currentLink {
                primaryBrowser.load(URLRequest(url: link))
            }
        } else if primaryBrowser.canGoBack {
            primaryBrowser.goBack()
        }
    }
    
    func closeTopOverlay() {
        if let lastOverlay = additionalBrowsers.last {
            lastOverlay.removeFromSuperview()
            additionalBrowsers.removeLast()
            //objectWillChange.send()
        }
    }
    
}

struct MainBrowserView: UIViewRepresentable {
    let destinationLink: URL
    @StateObject private var manager = ContentManager()
    
    func makeUIView(context: Context) -> WKWebView {
        manager.setupPrimaryBrowser()
        manager.primaryBrowser.uiDelegate = context.coordinator
        manager.primaryBrowser.navigationDelegate = context.coordinator
    
        manager.loadStoredCookies()
        manager.primaryBrowser.load(URLRequest(url: destinationLink))
        return manager.primaryBrowser
    }
    
    func updateUIView(_ browser: WKWebView, context: Context) {
        // browser.load(URLRequest(url: destinationLink))
    }
    
    func makeCoordinator() -> BrowserDelegateManager {
        BrowserDelegateManager(manager: manager)
    }
    
}

extension BrowserDelegateManager {
//    @objc func handleEdgePan(_ recognizer: UIScreenEdgePanGestureRecognizer) {
//        if recognizer.state == .ended {
//            let currentView = contentManager.additionalBrowsers.last ?? contentManager.primaryBrowser
//            if let currentView = currentView {
//                if currentView.canGoBack {
//                    currentView.goBack()
//                } else if !contentManager.additionalBrowsers.isEmpty {
//                    contentManager.cleanAdditionalBrowsersIfNeeded(for: currentView.url)
//                }
//            }
//        }
//    }
    @objc func handleEdgePan(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        if recognizer.state == .ended {
            guard let currentView = recognizer.view as? WKWebView else { return }
            if currentView.canGoBack {
                currentView.goBack()
            } else if let lastOverlay = contentManager.additionalBrowsers.last, currentView == lastOverlay {
                contentManager.shouldCleanAdditional(currentLink: nil)
            }
        }
    }
}

struct CoreInterfaceView: View {
    
    @State var intercaceUrl: String = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let u = URL(string: intercaceUrl) {
                MainBrowserView(
                    destinationLink: u
                )
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            intercaceUrl = UserDefaults.standard.string(forKey: "temp_url") ?? (UserDefaults.standard.string(forKey: "saved_url") ?? "")
            if let l = UserDefaults.standard.string(forKey: "temp_url"), !l.isEmpty {
                UserDefaults.standard.set(nil, forKey: "temp_url")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LoadTempURL"))) { _ in
            if (UserDefaults.standard.string(forKey: "temp_url") ?? "") != "" {
                intercaceUrl = UserDefaults.standard.string(forKey: "temp_url") ?? ""
                UserDefaults.standard.set(nil, forKey: "temp_url")
            }
        }
    }
    
}

