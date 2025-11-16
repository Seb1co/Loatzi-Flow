import SwiftUI
import FirebaseAuth
import MapKit
import CoreLocation
import PhotosUI

// MARK: - Extensie pentru a face CLLocationCoordinate2D Equatable
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// MARK: - User Model & Authentication Manager
class UserAuth: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?
    @Published var users: [User] = []
    @Published var hasSeenWelcome: Bool = false
    @Published var user: FirebaseAuth.User? = nil
    
    func login(email: String, password: String, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let firebaseUser = result?.user {
                DispatchQueue.main.async {
                    self.user = firebaseUser
                    self.isLoggedIn = true
                    
                    if let user = self.users.first(where: {
                        $0.email.lowercased() == email.lowercased() && $0.password == password
                    }) {
                        self.currentUser = user

                        // Save to UserDefaults
                        if let userData = try? JSONEncoder().encode(user) {
                            UserDefaults.standard.set(userData, forKey: "currentUser")
                        }
                    }
                }
                completion(.success(firebaseUser))
            }
        }
    }
    
    init() {
        // Check if user has seen welcome screen
        self.hasSeenWelcome = UserDefaults.standard.bool(forKey: "hasSeenWelcome")
        
        loadUsers()
        // Check if user is already logged in
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
            self.isLoggedIn = true
        }
    }
    
    func completeWelcomeScreen() {
        self.hasSeenWelcome = true
        UserDefaults.standard.set(true, forKey: "hasSeenWelcome")
    }
    
    func register(email: String, password: String, name: String, role: UserRole, completion: @escaping (Result<FirebaseAuth.User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
            } else if let firebaseUser = result?.user {
                // Create our local user object
                let newUser = User(
                    id: UUID(),
                    email: email,
                    password: password,
                    name: name,
                    role: role
                )
                
                // Update local state
                DispatchQueue.main.async {
                    self.users.append(newUser)
                    self.currentUser = newUser
                    self.isLoggedIn = true
                    self.user = firebaseUser
                    
                    // Save to UserDefaults
                    if let userData = try? JSONEncoder().encode(newUser) {
                        UserDefaults.standard.set(userData, forKey: "currentUser")
                    }
                    self.saveUsers()
                }
                
                completion(.success(firebaseUser))
            }
        }
    }
    
    func logout() {
        currentUser = nil
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }
    
    private func saveUsers() {
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: "savedUsers")
        }
    }
    
    private func loadUsers() {
        if let data = UserDefaults.standard.data(forKey: "savedUsers"),
           let savedUsers = try? JSONDecoder().decode([User].self, from: data) {
            users = savedUsers
        } else {
            // Create some default users for testing
            users = [
                User(id: UUID(), email: "primaria@oras.ro", password: "primaria123", name: "Primăria Oraș", role: .municipality),
                User(id: UUID(), email: "spital@oras.ro", password: "spital123", name: "Spitalul Oraș", role: .hospital),
                User(id: UUID(), email: "cetatean@exemplu.ro", password: "cetatean123", name: "Cetățean Exemplu", role: .citizen)
            ]
            saveUsers()
        }
    }
}

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    let password: String
    let name: String
    let role: UserRole
}

enum UserRole: String, Codable, CaseIterable {
    case citizen = "Cetățean"
    case municipality = "Primărie"
    case hospital = "Spital"
    
    var displayName: String {
        switch self {
        case .citizen:
            return "Cetățean"
        case .municipality:
            return "Reprezentant Primărie"
        case .hospital:
            return "Reprezentant Spital"
        }
    }
    
    var icon: String {
        switch self {
        case .citizen:
            return "person.fill"
        case .municipality:
            return "building.2.fill"
        case .hospital:
            return "cross.case.fill"
        }
    }
}

// MARK: - Welcome Screen
struct WelcomeView: View {
    @EnvironmentObject var authManager: UserAuth
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            Color(red: 0.0, green: 0.1, blue: 0.3)
                .ignoresSafeArea()
            
            VStack {
                TabView(selection: $currentPage) {
                    // First Slide
                    VStack(spacing: 40) {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 150, height: 150)
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: "shield.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color(red: 0.0, green: 0.1, blue: 0.3))
                        }
                        
                        VStack(spacing: 20) {
                            Text("Bine ai venit!")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Să facem orașul nostru un loc mai sigur împreună")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(red: 0.8, green: 0.9, blue: 1.0))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                        
                        Spacer()
                        
                        Text("Glisează spre stânga pentru a continua")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 30)
                    }
                    .tag(0)
                    
                    // Second Slide
                    VStack(spacing: 40) {
                        Spacer()
                        
                        VStack(spacing: 30) {
                            FeatureRow(icon: "map.fill", title: "Raportează probleme", description: "Plasează pin-uri pe hartă pentru problemele din oraș")
                            
                            FeatureRow(icon: "photo.fill", title: "Adaugă fotografii", description: "Încarcă poze ca dovadă pentru problemele raportate")
                            
                            FeatureRow(icon: "bell.fill", title: "Notifică autoritățile", description: "Problemele sunt trimise automat către primărie și spital")
                            
                            FeatureRow(icon: "clock.fill", title: "Urmărește progresul", description: "Vezi starea problemelor raportate în timp real")
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer()
                        
                        Text("Glisează spre stânga pentru a continua")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 30)
                    }
                    .tag(1)
                    
                    // Third Slide - Get Started
                    VStack(spacing: 50) {
                        Spacer()
                        
                        VStack(spacing: 30) {
                            Image(systemName: "hand.wave.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                            
                            Text("Ești gata să începi?")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Alătură-te comunității și contribuie la un oraș mai bun")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(red: 0.8, green: 0.9, blue: 1.0))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            authManager.completeWelcomeScreen()
                        }) {
                            Text("Începe acum")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Color(red: 0.0, green: 0.1, blue: 0.3))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .padding(.horizontal, 40)
                        }
                        
                        Text("Apasă butonul pentru a începe")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.bottom, 30)
                    }
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle())
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.8, green: 0.9, blue: 1.0))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Problem Pin Models
struct SavedProblemPin: Codable {
    let id: UUID
    let latitude: Double
    let longitude: Double
    let problemType: String
    let colorRed: Double
    let colorGreen: Double
    let colorBlue: Double
    let icon: String
    let description: String?
    let timestamp: Date
    let severity: Int
    let imageData: Data?
    let reporterName: String?
    let reporterEmail: String?
    let deadline: Date?
    let isResolved: Bool
    let resolvedDate: Date?
    
    init(from pin: ProblemPin) {
        self.id = pin.id
        self.latitude = pin.coordinate.latitude
        self.longitude = pin.coordinate.longitude
        self.problemType = pin.problemType
        self.colorRed = pin.color.components.red
        self.colorGreen = pin.color.components.green
        self.colorBlue = pin.color.components.blue
        self.icon = pin.icon
        self.description = pin.description
        self.timestamp = pin.timestamp
        self.severity = pin.severity
        self.imageData = pin.imageData
        self.reporterName = pin.reporterName
        self.reporterEmail = pin.reporterEmail
        self.deadline = pin.deadline
        self.isResolved = pin.isResolved
        self.resolvedDate = pin.resolvedDate
    }
    
    func toProblemPin() -> ProblemPin {
        ProblemPin(
            id: id,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            problemType: problemType,
            color: Color(red: colorRed, green: colorGreen, blue: colorBlue),
            icon: icon,
            description: description,
            timestamp: timestamp,
            severity: severity,
            imageData: imageData,
            reporterName: reporterName,
            reporterEmail: reporterEmail,
            deadline: deadline,
            isResolved: isResolved,
            resolvedDate: resolvedDate
        )
    }
}

extension Color {
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        #if canImport(UIKit)
        typealias NativeColor = UIColor
        #else
        typealias NativeColor = NSColor
        #endif
        
        let nativeColor = NativeColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        nativeColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var locationError: String?
    
    override init() {
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.requestWhenInUseAuthorization()
        self.locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
            self.locationError = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = error.localizedDescription
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.locationError = "Acces la locație refuzat. Activează locația în Setări."
            }
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    func requestLocation() {
        locationManager.requestLocation()
    }
}

// MARK: - Problem Pin Manager
class ProblemPinManager: ObservableObject {
    @Published var problemPins: [ProblemPin] = []
    private let saveKey = "savedProblemPins"
    
    init() {
        loadPins()
    }
    
    func addPin(_ pin: ProblemPin) {
        problemPins.append(pin)
        savePins()
    }
    
    func removePin(_ pin: ProblemPin) {
        problemPins.removeAll { $0.id == pin.id }
        savePins()
    }
    
    func removeAllPins() {
        problemPins.removeAll()
        savePins()
    }
    
    func pinsForMunicipality() -> [ProblemPin] {
        return problemPins.filter { $0.problemType != "Urgență Medicală" }
            .sorted {
                if $0.severity != $1.severity {
                    return $0.severity > $1.severity
                }
                return $0.timestamp > $1.timestamp
            }
    }
    
    func pinsForHospital() -> [ProblemPin] {
        return problemPins.filter { $0.problemType == "Urgență Medicală" }
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    func pinsForCitizen(email: String) -> [ProblemPin] {
        return problemPins.filter { $0.reporterEmail == email }
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    func updatePinStatus(_ pin: ProblemPin, isResolved: Bool, completion: @escaping (Bool) -> Void) {
        if let index = problemPins.firstIndex(where: { $0.id == pin.id }) {
            var updatedPin = problemPins[index]
            updatedPin.isResolved = isResolved
            if isResolved {
                updatedPin.resolvedDate = Date()
            } else {
                updatedPin.resolvedDate = nil
            }
            problemPins[index] = updatedPin
            savePins()
            completion(true)
        } else {
            completion(false)
        }
    }
    
    private func savePins() {
        let savedPins = problemPins.map { SavedProblemPin(from: $0) }
        if let encoded = try? JSONEncoder().encode(savedPins) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadPins() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let savedPins = try? JSONDecoder().decode([SavedProblemPin].self, from: data) {
            problemPins = savedPins.map { $0.toProblemPin() }
        }
    }
}

// MARK: - Problem Pin Model
struct ProblemPin: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let problemType: String
    let color: Color
    let icon: String
    var description: String?
    let timestamp: Date
    let severity: Int
    var imageData: Data?
    let reporterName: String?
    let reporterEmail: String?
    let deadline: Date?
    var isResolved: Bool
    var resolvedDate: Date?
    
    init(id: UUID = UUID(),
         coordinate: CLLocationCoordinate2D,
         problemType: String,
         color: Color,
         icon: String,
         description: String? = nil,
         timestamp: Date = Date(),
         severity: Int = 1,
         imageData: Data? = nil,
         reporterName: String? = nil,
         reporterEmail: String? = nil,
         deadline: Date? = nil,
         isResolved: Bool = false,
         resolvedDate: Date? = nil) {
        self.id = id
        self.coordinate = coordinate
        self.problemType = problemType
        self.color = color
        self.icon = icon
        self.description = description
        self.timestamp = timestamp
        self.severity = severity
        self.imageData = imageData
        self.reporterName = reporterName
        self.reporterEmail = reporterEmail
        self.deadline = deadline
        self.isResolved = isResolved
        self.resolvedDate = resolvedDate
    }
}

// MARK: - Problem Type Enum
enum ProblemType: CaseIterable {
    case accident, graffiti, trash, crime, infrastructure, trafficLight, pothole, flooding, fallenTree, powerOutage, brokenStreetlight, publicTransport, lostPet, blockedRoad, sewageLeak, fireHazard, animalDanger, trashOverflow, waterLeak, gasLeak, streetSign, parkingIssue, sidewalkDamage, bikeLane, minorityVulnerability, alcoholRisk, medicalEmergency, other
    
    var title: String {
        switch self {
        case .accident: return "Accident"
        case .graffiti: return "Graffiti/Vandalism"
        case .trash: return "Gunoi"
        case .crime: return "Infracțiune"
        case .infrastructure: return "Infrastructură"
        case .trafficLight: return "Semafor Defect"
        case .pothole: return "Groapă"
        case .flooding: return "Inundație"
        case .fallenTree: return "Copac Căzut"
        case .powerOutage: return "Întrerupere Curent"
        case .brokenStreetlight: return "Lampă Stinsă"
        case .publicTransport: return "Problemă Transport"
        case .lostPet: return "Animal Pierdut"
        case .blockedRoad: return "Drum Blocat"
        case .sewageLeak: return "Scurgere Canal"
        case .fireHazard: return "Pericol Incendiu"
        case .animalDanger: return "Animal Periculos"
        case .trashOverflow: return "Gunoi Excesiv"
        case .waterLeak: return "Scurgere Apă"
        case .gasLeak: return "Scurgere Gaz"
        case .streetSign: return "Indicator Lipsă"
        case .parkingIssue: return "Problemă Parcare"
        case .sidewalkDamage: return "Trotuar Deteriorat"
        case .bikeLane: return "Pistă Biciclete"
        case .minorityVulnerability: return "Vulnerabilitate Minorități"
        case .alcoholRisk: return "Risc Alcool"
        case .medicalEmergency: return "Urgență Medicală"
        case .other: return "Altceva"
        }
    }
    
    var iconName: String {
        switch self {
        case .accident: return "car.fill"
        case .graffiti: return "pencil.tip"
        case .trash: return "trash.fill"
        case .crime: return "shield.fill"
        case .infrastructure: return "hammer.fill"
        case .trafficLight: return "🚦"
        case .pothole: return "circle.circle"
        case .flooding: return "drop.fill"
        case .fallenTree: return "tree.fill"
        case .powerOutage: return "bolt.fill"
        case .brokenStreetlight: return "lightbulb.fill"
        case .publicTransport: return "bus.fill"
        case .lostPet: return "pawprint.fill"
        case .blockedRoad: return "xmark.octagon.fill"
        case .sewageLeak: return "exclamationmark.triangle.fill"
        case .fireHazard: return "flame.fill"
        case .animalDanger: return "ant.fill"
        case .trashOverflow: return "trash.fill"
        case .waterLeak: return "drop.triangle"
        case .gasLeak: return "wind"
        case .streetSign: return "signpost.right.fill"
        case .parkingIssue: return "parkingsign"
        case .sidewalkDamage: return "figure.walk"
        case .bikeLane: return "bicycle"
        case .minorityVulnerability: return "person.2.slash.fill"
        case .alcoholRisk: return "drop.fill"
        case .medicalEmergency: return "cross.case.fill"
        case .other: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .accident: return .red
        case .graffiti: return .pink
        case .trash: return .brown
        case .crime: return .purple
        case .infrastructure: return .blue
        case .trafficLight: return .yellow
        case .pothole: return .brown
        case .flooding: return .cyan
        case .fallenTree: return .green
        case .powerOutage: return .yellow
        case .brokenStreetlight: return .yellow
        case .publicTransport: return .blue
        case .lostPet: return .indigo
        case .blockedRoad: return .red
        case .sewageLeak: return .brown
        case .fireHazard: return .red
        case .animalDanger: return .orange
        case .trashOverflow: return .gray
        case .waterLeak: return .blue
        case .gasLeak: return .red
        case .streetSign: return .yellow
        case .parkingIssue: return .blue
        case .sidewalkDamage: return .gray
        case .bikeLane: return .green
        case .minorityVulnerability: return .purple
        case .alcoholRisk: return .orange
        case .medicalEmergency: return .red
        case .other: return .gray
        }
    }
    
    var severity: Int {
        switch self {
        case .medicalEmergency, .accident, .fireHazard: return 5
        case .gasLeak, .flooding, .crime: return 4
        case .blockedRoad, .powerOutage, .sewageLeak: return 3
        case .pothole, .brokenStreetlight, .waterLeak: return 2
        case .graffiti, .trash, .trashOverflow, .parkingIssue: return 1
        default: return 1
        }
    }
    
    var deadlineDays: Int {
        switch self.severity {
        case 5: return 1
        case 4: return 2
        case 3: return 4
        case 2: return 7
        default: return 14
        }
    }
    
    func calculateDeadline() -> Date {
        return Calendar.current.date(byAdding: .day, value: deadlineDays, to: Date()) ?? Date()
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Authentication Views
struct LoginView: View {
    @EnvironmentObject var authManager: UserAuth
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showRegistration = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.0, green: 0.1, blue: 0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 120, height: 120)
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: "shield.fill")
                                .font(.system(size: 50))
                                .foregroundColor(Color(red: 0.0, green: 0.1, blue: 0.3))
                        }
                        
                        Text("Bine ai revenit!")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Autentifică-te în contul tău")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 0.8, green: 0.9, blue: 1.0))
                    }
                    .padding(.top, 50)
                    
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            TextField("Introdu email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .foregroundColor(Color(red: 0.0, green: 0.1, blue: 0.3))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Parolă")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            
                            SecureField("Introdu parola", text: $password)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .foregroundColor(Color(red: 0.0, green: 0.1, blue: 0.3))
                        }
                        
                        if showError {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.system(size: 14, weight: .medium))
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: login) {
                            Text("Autentificare")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                    
                    VStack(spacing: 15) {
                        Text("Nu ai cont?")
                            .foregroundColor(.white.opacity(0.8))
                        
                        Button("Creează cont nou") {
                            showRegistration = true
                        }
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .medium))
                    }
                    .padding(.bottom, 30)
                }
            }
            .sheet(isPresented: $showRegistration) {
                RegistrationView()
                    .environmentObject(authManager)
            }
        }
    }
    
    private func login() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Completează toate câmpurile"
            showError = true
            return
        }
        
        authManager.login(email: email, password: password) { result in
            switch result {
            case .success(_):
                showError = false
            case .failure(let error):
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct RegistrationView: View {
    @EnvironmentObject var authManager: UserAuth
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var selectedRole: UserRole = .citizen
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informații personale")) {
                    TextField("Nume complet", text: $name)
                        .foregroundColor(.primary)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .foregroundColor(.primary)
                    SecureField("Parolă", text: $password)
                        .foregroundColor(.primary)
                    SecureField("Confirmă parola", text: $confirmPassword)
                        .foregroundColor(.primary)
                }
                
                Section(header: Text("Tipul contului")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Selectează tipul contului:")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        
                        VStack(spacing: 12) {
                            Button(action: {
                                selectedRole = .citizen
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.blue)
                                            Text("Cetățean")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.primary)
                                        }
                                        Text("Pot raporta probleme și văd doar rapoartele mele")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedRole == .citizen {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 20))
                                    } else {
                                        Circle()
                                            .stroke(Color.gray, lineWidth: 2)
                                            .frame(width: 20, height: 20)
                                    }
                                }
                                .padding()
                                .background(selectedRole == .citizen ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedRole == .citizen ? Color.blue : Color.clear, lineWidth: 2)
                                )
                            }
                            
                            Button(action: {
                                selectedRole = .municipality
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: "building.2.fill")
                                                .foregroundColor(.green)
                                            Text("Reprezentant Primărie")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.primary)
                                        }
                                        Text("Pot vedea toate rapoartele din oraș (cu excepția celor medicale)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedRole == .municipality {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 20))
                                    } else {
                                        Circle()
                                            .stroke(Color.gray, lineWidth: 2)
                                            .frame(width: 20, height: 20)
                                    }
                                }
                                .padding()
                                .background(selectedRole == .municipality ? Color.green.opacity(0.1) : Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedRole == .municipality ? Color.green : Color.clear, lineWidth: 2)
                                )
                            }
                            
                            Button(action: {
                                selectedRole = .hospital
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Image(systemName: "cross.case.fill")
                                                .foregroundColor(.red)
                                            Text("Reprezentant Spital")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.primary)
                                        }
                                        Text("Pot vedea doar urgențele medicale")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedRole == .hospital {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 20))
                                    } else {
                                        Circle()
                                            .stroke(Color.gray, lineWidth: 2)
                                            .frame(width: 20, height: 20)
                                    }
                                }
                                .padding()
                                .background(selectedRole == .hospital ? Color.red.opacity(0.1) : Color(.systemGray6))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedRole == .hospital ? Color.red : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                if selectedRole == .municipality {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Informație importantă")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text("Conturile de primărie necesită verificare manuală. Vei putea vedea toate rapoartele din oraș (cu excepția urgențelor medicale).")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                if selectedRole == .hospital {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.red)
                                Text("Informație importantă")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text("Conturile de spital necesită verificare manuală. Vei putea vedea doar rapoartele de urgență medicală.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    Button("Creează cont") {
                        register()
                    }
                    .disabled(!isFormValid)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                if showError {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .navigationBarTitle("Creează cont", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Anulează") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && !name.isEmpty && password == confirmPassword
    }
    
    private func register() {
        guard password == confirmPassword else {
            errorMessage = "Parolele nu coincid"
            showError = true
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Parola trebuie să aibă minim 6 caractere"
            showError = true
            return
        }
        
        authManager.register(email: email, password: password, name: name, role: selectedRole) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct ProblemTypeButtonLarge: View {
    let icon: String
    let title: String
    let color: Color
    let backgroundColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(backgroundColor)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProblemRowView: View {
    let problem: ProblemPin
    let onStatusChange: ((Bool) -> Void)?
    let showImagePreview: (Data) -> Void
    
    @State private var showResolutionConfirmation = false
    @State private var pendingResolutionStatus: Bool?
    
    var severityColor: Color {
        switch problem.severity {
        case 5: return .red
        case 4: return .orange
        case 3: return .yellow
        case 2: return .blue
        default: return .green
        }
    }
    
    var severityText: String {
        switch problem.severity {
        case 5: return "Critic"
        case 4: return "Urgent"
        case 3: return "Mediu"
        case 2: return "Scăzut"
        default: return "Minim"
        }
    }
    
    var timeRemaining: String {
        guard let deadline = problem.deadline, !problem.isResolved else {
            return problem.isResolved ? "Rezolvat" : "Fără termen"
        }
        
        let now = Date()
        if now > deadline {
            return "Depășit"
        }
        
        let components = Calendar.current.dateComponents([.day, .hour], from: now, to: deadline)
        if let days = components.day, days > 0 {
            return "\(days) zile"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours) ore"
        } else {
            return "< 1 oră"
        }
    }
    
    var timeRemainingColor: Color {
        guard let deadline = problem.deadline, !problem.isResolved else {
            return problem.isResolved ? .green : .gray
        }
        
        let now = Date()
        if now > deadline {
            return .red
        }
        
        let components = Calendar.current.dateComponents([.day], from: now, to: deadline)
        if let days = components.day {
            switch days {
            case 0: return .red
            case 1...2: return .orange
            case 3...5: return .yellow
            default: return .green
            }
        }
        return .green
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(problem.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    if problem.icon.count == 1 {
                        Text(problem.icon)
                            .font(.system(size: 18))
                            .foregroundColor(problem.color)
                    } else {
                        Image(systemName: problem.icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(problem.color)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(problem.problemType)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let reporterName = problem.reporterName {
                        Text("Raportat de: \(reporterName)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if onStatusChange != nil {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(timeRemaining)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(timeRemainingColor)
                                .cornerRadius(8)
                            
                            Text(severityText)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(severityColor)
                            
                            Button(problem.isResolved ? "Marcat Rezolvat" : "Marchează Rezolvat") {
                                pendingResolutionStatus = !problem.isResolved
                                showResolutionConfirmation = true
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                        }
                    } else {
                        Text(severityText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(severityColor)
                            .cornerRadius(8)
                        
                        Text(problem.timestamp, style: .relative)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let description = problem.description {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if let imageData = problem.imageData {
                Button(action: {
                    showImagePreview(imageData)
                }) {
                    HStack {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 12))
                        Text("Vezi foto raport")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "photo.slash.fill")
                        .font(.system(size: 12))
                    Text("Fără foto")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 8)
        .opacity(problem.isResolved ? 0.6 : 1.0)
        .alert("Confirmă rezolvarea", isPresented: $showResolutionConfirmation) {
            Button("Anulează", role: .cancel) {
                pendingResolutionStatus = nil
            }
            Button(pendingResolutionStatus == true ? "Marchează ca rezolvat" : "Marchează ca nerezolvat", role: .destructive) {
                if let status = pendingResolutionStatus {
                    onStatusChange?(status)
                }
            }
        } message: {
            if let status = pendingResolutionStatus {
                Text(status ?
                     "Ești sigur că vrei să marchezi această problemă ca rezolvată?" :
                     "Ești sigur că vrei să marchezi această problemă ca nerezolvată?")
            }
        }
    }
}

struct ProblemsListView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var pinManager: ProblemPinManager
    @State private var searchText = ""
    @State private var filterResolved = false
    @State private var selectedImageData: Data?
    @State private var showImagePreview = false
    
    var filteredPins: [ProblemPin] {
        let pins = pinManager.pinsForMunicipality()
            .filter { filterResolved ? $0.isResolved : !$0.isResolved }
        
        if searchText.isEmpty {
            return pins
        } else {
            return pins.filter { pin in
                pin.problemType.localizedCaseInsensitiveContains(searchText) ||
                (pin.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (pin.reporterName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Caută probleme...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.primary)
                    
                    Button(filterResolved ? "Afișează Active" : "Afișează Rezolvate") {
                        filterResolved.toggle()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 10)
                
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Probleme")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(pinManager.problemPins.filter { $0.problemType != "Urgență Medicală" }.count)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Probleme Active")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(pinManager.problemPins.filter { !$0.isResolved && $0.problemType != "Urgență Medicală" }.count)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Rezolvate")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(pinManager.problemPins.filter { $0.isResolved && $0.problemType != "Urgență Medicală" }.count)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                
                List {
                    ForEach(filteredPins) { pin in
                        ProblemRowView(problem: pin) { isResolved in
                            pinManager.updatePinStatus(pin, isResolved: isResolved) { _ in }
                        } showImagePreview: { imageData in
                            selectedImageData = imageData
                            showImagePreview = true
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationBarTitle("Panou Primărie", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Închide") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePreview) {
                if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                    ImagePreviewView(image: uiImage)
                }
            }
        }
    }
}

struct HospitalView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var pinManager: ProblemPinManager
    @State private var searchText = ""
    @State private var filterResolved = false
    @State private var selectedImageData: Data?
    @State private var showImagePreview = false
    
    var filteredPins: [ProblemPin] {
        let pins = pinManager.pinsForHospital()
            .filter { filterResolved ? $0.isResolved : !$0.isResolved }
        
        if searchText.isEmpty {
            return pins
        } else {
            return pins.filter { pin in
                pin.problemType.localizedCaseInsensitiveContains(searchText) ||
                (pin.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (pin.reporterName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Caută urgențe medicale...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.primary)
                    
                    Button(filterResolved ? "Afișează Active" : "Afișează Rezolvate") {
                        filterResolved.toggle()
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.red)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 10)
                
                VStack(spacing: 10) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Urgențe")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(pinManager.problemPins.filter { $0.problemType == "Urgență Medicală" }.count)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Urgențe Active")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(pinManager.problemPins.filter { !$0.isResolved && $0.problemType == "Urgență Medicală" }.count)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("Rezolvate")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(pinManager.problemPins.filter { $0.isResolved && $0.problemType == "Urgență Medicală" }.count)")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 10)
                
                if filteredPins.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red.opacity(0.5))
                        
                        Text("Nu există urgențe medicale")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text("Toate urgențele medicale raportate vor apărea aici")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredPins) { pin in
                            ProblemRowView(problem: pin) { isResolved in
                                pinManager.updatePinStatus(pin, isResolved: isResolved) { _ in }
                            } showImagePreview: { imageData in
                                selectedImageData = imageData
                                showImagePreview = true
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationBarTitle("Panou Spital", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Închide") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePreview) {
                if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                    ImagePreviewView(image: uiImage)
                }
            }
        }
    }
}

struct ImagePreviewView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarTitle("Foto Raport", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Închide") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProblemSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var pinManager: ProblemPinManager
    var currentLocation: CLLocationCoordinate2D
    @Binding var showSuccessScreen: Bool
    @Binding var successScreenProblem: ProblemPin?
    var currentUser: User?
    @State private var searchText = ""
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    
    let navyBlue = Color(red: 0.0, green: 0.1, blue: 0.3)
    let darkBlue = Color(red: 0.1, green: 0.2, blue: 0.4)
    let lightblue = Color(red: 0.1, green: 0.2, blue: 0.2)
    let GGREEN = UIColor(red: 0.141, green: 0.612, blue: 0.267, alpha: 1.0)
    
    var filteredProblemTypes: [ProblemType] {
        if searchText.isEmpty {
            return ProblemType.allCases.filter { problemType in
                ![.accident, .graffiti, .trash, .crime, .infrastructure].contains(problemType)
            }
        } else {
            return ProblemType.allCases.filter { problemType in
                problemType.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Caută probleme...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 10)
                
                List {
                    ForEach(filteredProblemTypes, id: \.self) { problemType in
                        Button(action: {
                            addPin(type: problemType)
                        }) {
                            HStack(spacing: 15) {
                                ZStack {
                                    Circle()
                                        .fill(problemType.color.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: problemType.iconName)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(problemType.color)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(problemType.title)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        Circle()
                                            .fill(severityColor(for: problemType.severity))
                                            .frame(width: 8, height: 8)
                                        Text(severityText(for: problemType.severity))
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationBarTitle("Alte Probleme", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Anulează") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
            }
            .onChange(of: selectedImage) { image in
                if let image = image, let imageData = image.jpegData(compressionQuality: 0.8) {
                    let newPin = ProblemPin(
                        coordinate: currentLocation,
                        problemType: ProblemType.trash.title,
                        color: ProblemType.trash.color,
                        icon: ProblemType.trash.iconName,
                        description: nil,
                        timestamp: Date(),
                        severity: ProblemType.trash.severity,
                        imageData: imageData,
                        reporterName: currentUser?.name,
                        reporterEmail: currentUser?.email,
                        deadline: ProblemType.trash.calculateDeadline()
                    )
                    
                    pinManager.addPin(newPin)
                    successScreenProblem = newPin
                    showSuccessScreen = true
                    dismiss()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation {
                            showSuccessScreen = false
                        }
                    }
                }
            }
        }
    }
    
    private func severityColor(for severity: Int) -> Color {
        switch severity {
        case 5: return .red
        case 4: return .orange
        case 3: return .yellow
        case 2: return .blue
        default: return .green
        }
    }
    
    private func severityText(for severity: Int) -> String {
        switch severity {
        case 5: return "Critic"
        case 4: return "Urgent"
        case 3: return "Mediu"
        case 2: return "Scăzut"
        default: return "Minim"
        }
    }
    
    private func addPin(type: ProblemType) {
        if type == .trash {
            // Pentru gunoi, cere o poză din galerie
            showImagePicker = true
        } else {
            // Pentru alte probleme, adaugă direct pin-ul
            let newPin = ProblemPin(
                coordinate: currentLocation,
                problemType: type.title,
                color: type.color,
                icon: type.iconName,
                description: nil,
                timestamp: Date(),
                severity: type.severity,
                imageData: nil,
                reporterName: currentUser?.name,
                reporterEmail: currentUser?.email,
                deadline: type.calculateDeadline()
            )
            
            pinManager.addPin(newPin)
            successScreenProblem = newPin
            showSuccessScreen = true
            dismiss()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showSuccessScreen = false
                }
            }
        }
    }
}

struct CustomIssueView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var description = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showImageRequiredAlert = false
    let onSave: (String, Data?) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 25) {
                Text("Descrie Problema Ta")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 20)
                
                Text("Furnizează detalii despre problema întâlnită")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Descriere")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    TextEditor(text: $description)
                        .frame(height: 180)
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Adaugă Foto (Obligatoriu)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("*")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    
                    if let image = selectedImage {
                        VStack(spacing: 15) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .cornerRadius(12)
                            
                            Button("Șterge Foto") {
                                selectedImage = nil
                            }
                            .foregroundColor(.red)
                            .font(.system(size: 16, weight: .medium))
                        }
                    } else {
                        Button(action: {
                            showImagePicker = true
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 50))
                                    .foregroundColor(.blue)
                                
                                Text("Apasă pentru a alege foto")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.blue)
                                
                                Text("O poză este obligatorie pentru a raporta problema")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button(action: {
                    if selectedImage == nil {
                        showImageRequiredAlert = true
                    } else {
                        let imageData = selectedImage?.jpegData(compressionQuality: 0.8)
                        onSave(description, imageData)
                        presentationMode.wrappedValue.dismiss()
                        onDismiss()
                    }
                }) {
                    Text("Raportează Problema")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage == nil ? Color.gray : Color.blue)
                        .cornerRadius(15)
                        .padding(.horizontal, 20)
                }
                .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage == nil)
                .padding(.bottom, 30)
            }
            .padding(.horizontal, 10)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Anulează") {
                        presentationMode.wrappedValue.dismiss()
                        onDismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
            }
            .alert("Foto obligatorie", isPresented: $showImageRequiredAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Trebuie să adaugi o fotografie pentru a putea raporta problema.")
            }
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authManager: UserAuth
    @ObservedObject var pinManager: ProblemPinManager
    @State private var showClearConfirmation = false
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                if let currentUser = authManager.currentUser {
                    Section(header: Text("Informații Cont")) {
                        HStack {
                            Image(systemName: currentUser.role.icon)
                                .foregroundColor(.blue)
                            VStack(alignment: .leading) {
                                Text(currentUser.name)
                                    .font(.system(size: 16, weight: .medium))
                                Text(currentUser.email)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.green)
                            Text("Rol")
                            Spacer()
                            Text(currentUser.role.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Statistici")) {
                    HStack {
                        Text("Total Probleme Raportate")
                        Spacer()
                        Text("\(pinManager.problemPins.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    if let currentUser = authManager.currentUser, currentUser.role == .citizen {
                        HStack {
                            Text("Problemele Mele")
                            Spacer()
                            Text("\(pinManager.pinsForCitizen(email: currentUser.email).count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if authManager.currentUser?.role == .municipality {
                        HStack {
                            Text("Probleme Active")
                            Spacer()
                            Text("\(pinManager.problemPins.filter { !$0.isResolved && $0.problemType != "Urgență Medicală" }.count)")
                                .foregroundColor(.orange)
                                .fontWeight(.bold)
                        }
                        
                        HStack {
                            Text("Probleme Rezolvate")
                            Spacer()
                            Text("\(pinManager.problemPins.filter { $0.isResolved && $0.problemType != "Urgență Medicală" }.count)")
                                .foregroundColor(.green)
                                .fontWeight(.bold)
                        }
                    }
                    
                    if authManager.currentUser?.role == .hospital {
                        HStack {
                            Text("Urgențe Medicale Active")
                            Spacer()
                            Text("\(pinManager.problemPins.filter { !$0.isResolved && $0.problemType == "Urgență Medicală" }.count)")
                                .foregroundColor(.red)
                                .fontWeight(.bold)
                        }
                    }
                }
                
                Section(header: Text("Gestionare Date")) {
                    Button("Șterge Toate Rapoartele") {
                        showClearConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                
                Section(header: Text("Aplicație")) {
                    HStack {
                        Text("Versiune")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("Deconectare") {
                        showLogoutConfirmation = true
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                
                Section(header: Text("Despre")) {
                    Text("Această aplicație te ajută să raportezi și să urmărești problemele din comunitatea ta. Toate rapoartele sunt salvate local pe dispozitivul tău.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle("Setări", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Gata") {
                        dismiss()
                    }
                }
            }
            .alert("Ștergi toate rapoartele?", isPresented: $showClearConfirmation) {
                Button("Anulează", role: .cancel) { }
                Button("Șterge Tot", role: .destructive) {
                    pinManager.removeAllPins()
                }
            } message: {
                Text("Această acțiune va șterge toate rapoartele de pe hartă. Nu poți anula această acțiune.")
            }
            .alert("Deconectare", isPresented: $showLogoutConfirmation) {
                Button("Anulează", role: .cancel) { }
                Button("Deconectare", role: .destructive) {
                    authManager.logout()
                    dismiss()
                }
            } message: {
                Text("Ești sigur că vrei să te deconectezi?")
            }
        }
    }
}

struct SuccessScreenView: View {
    @Binding var isVisible: Bool
    let problem: ProblemPin
    
    var body: some View {
        ZStack {
            Color.green
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: problem.icon)
                    .font(.system(size: 80, weight: .bold))
                    .foregroundColor(.white)
                
                VStack(spacing: 15) {
                    Text("Problemă Raportată")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(problem.problemType)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    if let description = problem.description, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    if problem.imageData != nil {
                        HStack {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 16))
                            Text("Foto atașată")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(30)
        }
        .onTapGesture {
            withAnimation {
                isVisible = false
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isVisible = false
                }
            }
        }
    }
}

// MARK: - Main App Content
struct ContentView: View {
    @StateObject private var authManager = UserAuth()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var pinManager = ProblemPinManager()
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var isExpanded = false
    @State private var showProblemSelection = false
    @State private var showSuccessScreen = false
    @State private var successScreenProblem: ProblemPin?
    @State private var showSettings = false
    @State private var showProblemsList = false
    @State private var showHospitalView = false
    @State private var followUserLocation = true
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    
    let navyBlue = Color(red: 0.0, green: 0.1, blue: 0.3)
    let darkBlue = Color(red: 0.1, green: 0.2, blue: 0.4)
    let lightBlue = Color(red: 0.8, green: 0.9, blue: 1.0)
    let municipalityGreen = Color(red: 0.0, green: 0.5, blue: 0.2)
    let hospitalRed = Color(red: 0.8, green: 0.2, blue: 0.2)
    
    var body: some View {
        Group {
            if !authManager.hasSeenWelcome {
                WelcomeView()
                    .environmentObject(authManager)
            } else if authManager.isLoggedIn, let currentUser = authManager.currentUser {
                mainContentView(for: currentUser)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage, sourceType: .photoLibrary)
        }
        .onChange(of: selectedImage) { image in
            if let image = image,
               let imageData = image.jpegData(compressionQuality: 0.8),
               let currentLocation = locationManager.userLocation,
               let currentUser = authManager.currentUser {
                
                let newPin = ProblemPin(
                    coordinate: currentLocation,
                    problemType: ProblemType.trash.title,
                    color: ProblemType.trash.color,
                    icon: ProblemType.trash.iconName,
                    description: nil,
                    timestamp: Date(),
                    severity: ProblemType.trash.severity,
                    imageData: imageData,
                    reporterName: currentUser.name,
                    reporterEmail: currentUser.email,
                    deadline: ProblemType.trash.calculateDeadline()
                )
                
                pinManager.addPin(newPin)
                successScreenProblem = newPin
                
                withAnimation(.spring()) {
                    isExpanded = false
                    showSuccessScreen = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showSuccessScreen = false
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func mainContentView(for user: User) -> some View {
        ZStack(alignment: .top) {
            Map(position: $mapCameraPosition) {
                UserAnnotation()
                
                ForEach(visiblePins(for: user)) { pin in
                    Annotation(pin.problemType, coordinate: pin.coordinate) {
                        ZStack {
                            Circle()
                                .fill(pin.isResolved ? Color.gray : pin.color)
                                .frame(width: user.role == .municipality || user.role == .hospital ? 60 : 50,
                                      height: user.role == .municipality || user.role == .hospital ? 60 : 50)
                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                            
                            if pin.icon.count == 1 {
                                Text(pin.icon)
                                    .font(.system(size: user.role == .municipality || user.role == .hospital ? 28 : 24))
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: pin.icon)
                                    .font(.system(size: user.role == .municipality || user.role == .hospital ? 24 : 22, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            if (user.role == .municipality || user.role == .hospital) && pin.isResolved {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.green).frame(width: 20, height: 20))
                                    .offset(x: 20, y: -20)
                            }
                        }
                    }
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .ignoresSafeArea()
            .onTapGesture {
                withAnimation(.spring()) {
                    isExpanded = false
                }
            }
            .onChange(of: locationManager.userLocation) { oldValue, newValue in
                if followUserLocation, let newLocation = newValue {
                    let camera = MapCamera(
                        centerCoordinate: newLocation,
                        distance: 1000,
                        heading: 0,
                        pitch: 0
                    )
                    mapCameraPosition = .camera(camera)
                }
            }
            
            VStack(spacing: 0) {
                if !isExpanded {
                    HStack(alignment: .top, spacing: 15) {
                        ZStack {
                            Circle()
                                .fill(headerColor(for: user))
                                .frame(width: 70, height: 70)
                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                            
                            Image(systemName: user.role.icon)
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 5)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bună, \(user.name)!")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            HStack {
                                Image(systemName: user.role.icon)
                                    .font(.system(size: 12))
                                Text(user.role.displayName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(lightBlue)
                            }
                            
                            if user.role == .municipality {
                                HStack(spacing: 15) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 8, height: 8)
                                        Text("\(pinManager.problemPins.filter { !$0.isResolved && $0.problemType != "Urgență Medicală" }.count) active")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                            } else if user.role == .hospital {
                                HStack(spacing: 15) {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 8, height: 8)
                                        Text("\(pinManager.problemPins.filter { !$0.isResolved && $0.problemType == "Urgență Medicală" }.count) urgențe")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white)
                                    }
                                }
                            } else {
                                if locationManager.userLocation != nil {
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.green)
                                        Text("Locație activă")
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundColor(.green)
                                    }
                                } else if locationManager.locationError != nil {
                                    HStack {
                                        Image(systemName: "location.slash.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.orange)
                                        Text("Eroare locație")
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundColor(.orange)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .padding(.trailing, 10)
                        
                        Spacer()
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(headerColor(for: user))
                            .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                }
                
                Spacer()
            }
            
            if !isExpanded {
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear,
                                        headerColor(for: user).opacity(0.2),
                                        headerColor(for: user).opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 250)
                        .allowsHitTesting(false)
                }
                .ignoresSafeArea()
            }
            
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        showSettings = true
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(headerColor(for: user))
                                .frame(width: 65, height: 65)
                                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                            
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading, 25)
                    .padding(.bottom, bottomPadding(for: user))
                    
                    Spacer()
                    
                    if user.role == .citizen {
                        Button(action: {
                            withAnimation(.spring()) {
                                isExpanded = true
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.red)
                                    .frame(width: 70, height: 70)
                                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                                
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.trailing, 25)
                        .padding(.bottom, 141.01)
                    } else if user.role == .municipality {
                        Button(action: {
                            showProblemsList = true
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(municipalityGreen)
                                    .frame(width: 65, height: 65)
                                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                                
                                VStack(spacing: 2) {
                                    Image(systemName: "list.bullet")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("Panou")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.trailing, 25)
                        .padding(.bottom, 200)
                    } else if user.role == .hospital {
                        Button(action: {
                            showHospitalView = true
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(hospitalRed)
                                    .frame(width: 65, height: 65)
                                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                                
                                VStack(spacing: 2) {
                                    Image(systemName: "cross.case.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("Urgențe")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.trailing, 25)
                        .padding(.bottom, 200)
                    }
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        followUserLocation.toggle()
                        if followUserLocation, let location = locationManager.userLocation {
                            let camera = MapCamera(
                                centerCoordinate: location,
                                distance: 1000,
                                heading: 0,
                                pitch: 0
                            )
                            mapCameraPosition = .camera(camera)
                            locationManager.requestLocation()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(followUserLocation ? headerColor(for: user) : Color.gray)
                                .frame(width: 50, height: 50)
                                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 3)
                            
                            Image(systemName: followUserLocation ? "location.fill" : "location")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.trailing, 25)
                    .padding(.bottom, locationButtonBottomPadding(for: user))
                }
            }
            
            if authManager.currentUser?.role == .citizen {
                VStack {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        if isExpanded {
                            VStack(spacing: 20) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 40, height: 40)
                                        
                                        Image(systemName: authManager.currentUser?.role.icon ?? "person.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(navyBlue)
                                    }
                                    
                                    Text("Raportează o Problemă")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            isExpanded = false
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                                .padding(.top, 10)
                                
                                Text("Selectează tipul problemei pe care vrei să o raportezi")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(lightBlue)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                    ProblemTypeButtonLarge(
                                        icon: "car.fill",
                                        title: "Accident",
                                        color: .red,
                                        backgroundColor: darkBlue
                                    ) {
                                        addProblemPin(type: .accident)
                                    }
                                    
                                    ProblemTypeButtonLarge(
                                        icon: "pencil.tip",
                                        title: "Graffiti",
                                        color: .pink,
                                        backgroundColor: darkBlue
                                    ) {
                                        addProblemPin(type: .graffiti)
                                    }
                                    
                                    ProblemTypeButtonLarge(
                                        icon: "trash.fill",
                                        title: "Gunoi",
                                        color: .brown,
                                        backgroundColor: darkBlue
                                    ) {
                                        addProblemPin(type: .trash)
                                    }
                                    
                                    ProblemTypeButtonLarge(
                                        icon: "shield.fill",
                                        title: "Infracțiune",
                                        color: .purple,
                                        backgroundColor: darkBlue
                                    ) {
                                        addProblemPin(type: .crime)
                                    }
                                    
                                    ProblemTypeButtonLarge(
                                        icon: "hammer.fill",
                                        title: "Infrastructură",
                                        color: .blue,
                                        backgroundColor: darkBlue
                                    ) {
                                        addProblemPin(type: .infrastructure)
                                    }
                                    
                                    ProblemTypeButtonLarge(
                                        icon: "ellipsis.circle.fill",
                                        title: "Alte Probleme",
                                        color: .yellow,
                                        backgroundColor: darkBlue
                                    ) {
                                        withAnimation(.spring()) {
                                            isExpanded = false
                                        }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            showProblemSelection = true
                                        }
                                    }
                                }
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        isExpanded = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showCustomIssue()
                                    }
                                }) {
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(Color.blue.opacity(0.2))
                                                .frame(width: 44, height: 44)
                                            
                                            Image(systemName: "pencil.circle.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.blue)
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text("Scrie o problemă explicită")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.white)
                                            
                                            Text("Descrie în detaliu cu poze")
                                                .font(.system(size: 14))
                                                .foregroundColor(lightBlue)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding(20)
                                    .background(darkBlue)
                                    .cornerRadius(16)
                                }
                                .padding(.top, 10)
                            }
                            .padding(25)
                        } else {
                            VStack(spacing: 15) {
                                HStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.8))
                                        .frame(width: 120, height: 6)
                                    Spacer()
                                }
                                
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("Raportează Probleme Comunitare")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(.white)
                                        
                                        Text("Apasă pentru a raporta accidente, graffiti, gunoi și multe altele")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(lightBlue)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.up")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .padding(25)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: isExpanded ? 30 : 25)
                            .fill(navyBlue)
                            .shadow(color: .black.opacity(isExpanded ? 0.5 : 0.4),
                                   radius: isExpanded ? 25 : 20,
                                   x: 0, y: isExpanded ? -10 : 0)
                    )
                    .padding(.horizontal, isExpanded ? 0 : 20)
                    .onTapGesture {
                        if !isExpanded {
                            withAnimation(.spring()) {
                                isExpanded = true
                            }
                        }
                    }
                }
            }
            
            if showSuccessScreen, let problem = successScreenProblem {
                SuccessScreenView(isVisible: $showSuccessScreen, problem: problem)
            }
        }
        .sheet(isPresented: $showProblemSelection) {
            ProblemSelectionView(
                pinManager: pinManager,
                currentLocation: locationManager.userLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                showSuccessScreen: $showSuccessScreen,
                successScreenProblem: $successScreenProblem,
                currentUser: authManager.currentUser
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(authManager: authManager, pinManager: pinManager)
        }
        .sheet(isPresented: $showProblemsList) {
            ProblemsListView(pinManager: pinManager)
        }
        .sheet(isPresented: $showHospitalView) {
            HospitalView(pinManager: pinManager)
        }
        .onAppear {
            if let location = locationManager.userLocation {
                let camera = MapCamera(
                    centerCoordinate: location,
                    distance: 1000,
                    heading: 0,
                    pitch: 0
                )
                mapCameraPosition = .camera(camera)
            }
        }
    }
    
    private func headerColor(for user: User) -> Color {
        switch user.role {
        case .citizen:
            return navyBlue
        case .municipality:
            return municipalityGreen
        case .hospital:
            return hospitalRed
        }
    }
    
    private func bottomPadding(for user: User) -> CGFloat {
        switch user.role {
        case .citizen:
            return 141
        case .municipality, .hospital:
            return 200
        }
    }
    
    private func locationButtonBottomPadding(for user: User) -> CGFloat {
        switch user.role {
        case .citizen:
            return 220
        case .municipality, .hospital:
            return 280
        }
    }
    
    private func visiblePins(for user: User) -> [ProblemPin] {
        switch user.role {
        case .citizen:
            return pinManager.pinsForCitizen(email: user.email)
        case .municipality:
            return pinManager.pinsForMunicipality()
        case .hospital:
            return pinManager.pinsForHospital()
        }
    }
    
    private func addProblemPin(type: ProblemType) {
        guard let currentLocation = locationManager.userLocation,
              let currentUser = authManager.currentUser else {
            return
        }
        
        if type == .trash {
            showImagePicker = true
        } else {
            let newPin = ProblemPin(
                coordinate: currentLocation,
                problemType: type.title,
                color: type.color,
                icon: type.iconName,
                description: nil,
                timestamp: Date(),
                severity: type.severity,
                imageData: nil,
                reporterName: currentUser.name,
                reporterEmail: currentUser.email,
                deadline: type.calculateDeadline()
            )
            
            pinManager.addPin(newPin)
            successScreenProblem = newPin
            
            withAnimation(.spring()) {
                isExpanded = false
                showSuccessScreen = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showSuccessScreen = false
                }
            }
        }
    }
    
    private func showCustomIssue() {
        let customIssueView = CustomIssueView(
            onSave: { description, imageData in
                guard let currentLocation = locationManager.userLocation,
                      let currentUser = authManager.currentUser else { return }
                
                let newPin = ProblemPin(
                    coordinate: currentLocation,
                    problemType: "Problemă Personalizată",
                    color: .gray,
                    icon: "exclamationmark.triangle.fill",
                    description: description,
                    timestamp: Date(),
                    severity: 1,
                    imageData: imageData,
                    reporterName: currentUser.name,
                    reporterEmail: currentUser.email,
                    deadline: ProblemType.other.calculateDeadline()
                )
                
                pinManager.addPin(newPin)
                successScreenProblem = newPin
                showSuccessScreen = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showSuccessScreen = false
                    }
                }
            },
            onDismiss: {}
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            let hostingController = UIHostingController(rootView: customIssueView)
            hostingController.modalPresentationStyle = .fullScreen
            rootViewController.present(hostingController, animated: true)
        }
    }
}

#Preview {
    ContentView()
}
