import SwiftUI
import FirebaseAuth

struct AuthenticationView: View {
    @EnvironmentObject private var viewModel: UserViewModel
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var grade = 9
    @State private var careerGoal = ""
    @State private var school = ""
    @State private var location = ""
    @State private var interests: [String] = []
    @State private var newInterest = ""
    @State private var showProfileSetup = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Welcome to Journey")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Your personalized college guidance companion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                if showProfileSetup {
                    ProfileSetupView(
                        name: $name,
                        grade: $grade,
                        careerGoal: $careerGoal,
                        school: $school,
                        location: $location,
                        interests: $interests,
                        newInterest: $newInterest,
                        onComplete: createProfile
                    )
                } else {
                    // Auth Form
                    VStack(spacing: 16) {
                        if isSignUp {
                            TextField("Name", text: $name)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .textContentType(.name)
                        }
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .textContentType(isSignUp ? .newPassword : .password)
                        
                        Button(action: handleAuth) {
                            Text(isSignUp ? "Sign Up" : "Log In")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(email.isEmpty || password.isEmpty || (isSignUp && name.isEmpty))
                        
                        Button(action: { isSignUp.toggle() }) {
                            Text(isSignUp ? "Already have an account? Log in" : "Don't have an account? Sign up")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }
    
    private func handleAuth() {
        Task {
            do {
                if isSignUp {
                    try await Auth.auth().createUser(withEmail: email, password: password)
                    showProfileSetup = true
                } else {
                    try await Auth.auth().signIn(withEmail: email, password: password)
                    await viewModel.loadUserProfile()
                }
            } catch {
                viewModel.error = error.localizedDescription
            }
        }
    }
    
    private func createProfile() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        Task {
            await viewModel.createProfile(
                name: name,
                grade: grade,
                careerGoal: careerGoal,
                school: school,
                location: location,
                interests: interests
            )
        }
    }
}

struct ProfileSetupView: View {
    @Binding var name: String
    @Binding var grade: Int
    @Binding var careerGoal: String
    @Binding var school: String
    @Binding var location: String
    @Binding var interests: [String]
    @Binding var newInterest: String
    let onComplete: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Complete Your Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Full Name", text: $name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Picker("Grade", selection: $grade) {
                        ForEach(9...12, id: \.self) { grade in
                            Text("Grade \(grade)").tag(grade)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    TextField("Career Goal", text: $careerGoal)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("School", text: $school)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Location", text: $location)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interests")
                            .font(.headline)
                        
                        HStack {
                            TextField("Add interest", text: $newInterest)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button(action: addInterest) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            .disabled(newInterest.isEmpty)
                        }
                        
                        FlowLayout(spacing: 8) {
                            ForEach(interests, id: \.self) { interest in
                                InterestTag(interest: interest) {
                                    interests.removeAll { $0 == interest }
                                }
                            }
                        }
                    }
                }
                
                Button(action: onComplete) {
                    Text("Complete Profile")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(name.isEmpty || careerGoal.isEmpty || school.isEmpty || location.isEmpty)
            }
            .padding()
        }
    }
    
    private func addInterest() {
        let trimmed = newInterest.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !interests.contains(trimmed) {
            interests.append(trimmed)
            newInterest = ""
        }
    }
}

struct InterestTag: View {
    let interest: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(interest)
                .font(.subheadline)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
        .cornerRadius(16)
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: result.positions[index], proposal: .unspecified)
        }
    }
    
    private struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in width: CGFloat, spacing: CGFloat, subviews: Subviews) {
            positions = []
            size = .zero
            
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let viewSize = subview.sizeThatFits(.unspecified)
                
                if currentX + viewSize.width > width {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, viewSize.height)
                currentX += viewSize.width + spacing
                size.width = max(size.width, currentX)
            }
            
            size.height = currentY + lineHeight
        }
    }
}

#Preview {
    AuthenticationView()
} 