import SwiftUI

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

// Main App
@main
struct ChickenCareApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: String = "home"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeDashboardView()
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
                    QuickActionButton(icon: "chicken.fill", title: "Add Chicken")
                    QuickActionButton(icon: "snowflake", title: "Check Freshness")
                }
                .padding(.horizontal)
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

// Preview
#Preview {
    ContentView()
        .environmentObject(AppState())
}
