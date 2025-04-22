import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
class UserViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    @Published var recommendations: [String] = []
    @Published var careerRoadmap: CareerRoadmap?
    @Published var selectedCategory: RecommendationsView.Category = .all
    @Published var showProfileSetup = false
    
    let firebaseService = FirebaseService.shared
    private let aiService = AIService()
    
    init() {
        loadUserProfile()
    }
    
    // MARK: - User Profile
    
    func loadUserProfile() {
        guard let basicUser = firebaseService.getCurrentUser() else {
            error = "No authenticated user"
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let user = try await firebaseService.getUserProfile(userId: basicUser.id)
                currentUser = user
                
                // If the user only has basic info, show profile setup
                if user.careerGoal.isEmpty && user.school.isEmpty {
                    showProfileSetup = true
                } else {
                    // Load career roadmap if profile is complete
                    await loadCareerRoadmap()
                }
                
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    func signOut() {
        do {
            try firebaseService.signOut()
            currentUser = nil
            recommendations = []
            careerRoadmap = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func createProfile(name: String, grade: Int, careerGoal: String, school: String, location: String, interests: [String]) async {
        guard let basicUser = firebaseService.getCurrentUser() else {
            error = "No authenticated user"
            return
        }
        
        isLoading = true
        
        do {
            let user = User(
                id: basicUser.id,
                name: name,
                email: basicUser.email,
                grade: grade,
                careerGoal: careerGoal,
                school: school,
                location: location,
                interests: interests
            )
            
            try await firebaseService.createUserProfile(user)
            currentUser = user
            showProfileSetup = false
            await generateRecommendations()
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func updateProfile(_ updatedUser: User) async {
        isLoading = true
        
        do {
            try await firebaseService.createUserProfile(updatedUser)
            currentUser = updatedUser
            await generateRecommendations()
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func loadCareerRoadmap() async {
        guard let user = currentUser else { return }
        
        do {
            if let roadmap = try await firebaseService.getCareerRoadmap(userId: user.id) {
                await MainActor.run {
                    self.careerRoadmap = roadmap
                }
            } else {
                // Create initial roadmap if none exists
                let newRoadmap = CareerRoadmap(
                    id: UUID().uuidString,
                    userId: user.id,
                    careerGoal: user.careerGoal,
                    grade: user.grade
                )
                try await firebaseService.createCareerRoadmap(newRoadmap)
                await MainActor.run {
                    self.careerRoadmap = newRoadmap
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    func generateCareerRoadmap() async {
        guard let user = currentUser else { return }
        
        do {
            // Create a new roadmap with initial milestones
            let newRoadmap = CareerRoadmap(
                id: UUID().uuidString,
                userId: user.id,
                careerGoal: user.careerGoal,
                grade: user.grade
            )
            
            try await firebaseService.createCareerRoadmap(newRoadmap)
            await MainActor.run {
                self.careerRoadmap = newRoadmap
            }
            
            // Generate initial recommendations
            await generateRecommendations()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    func updateCareerRoadmap(_ roadmap: CareerRoadmap) async {
        do {
            try await firebaseService.updateCareerRoadmap(roadmap)
            await MainActor.run {
                self.careerRoadmap = roadmap
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    @MainActor
    func generateRecommendations() async {
        guard let user = currentUser else { return }
        
        isLoading = true
        
        do {
            // Get completed milestones to inform AI recommendations
            let completedMilestones = careerRoadmap?.milestones.filter { $0.isCompleted } ?? []
            
            // Generate new recommendations using AI service
            let recommendations = try await aiService.generateCareerRecommendations(
                for: user,
                completedMilestones: completedMilestones
            )
            
            // Update roadmap with new recommendations
            if var roadmap = careerRoadmap {
                // Add new milestones from recommendations
                for recommendation in recommendations {
                    let milestone = CareerRoadmap.Milestone(
                        id: UUID().uuidString,
                        title: recommendation.title,
                        description: recommendation.description,
                        dueDate: recommendation.dueDate,
                        isCompleted: false,
                        gradeLevel: recommendation.gradeLevel,
                        category: recommendation.category
                    )
                    roadmap.addMilestone(milestone)
                }
                
                // Add any recommended resources
                for resource in recommendations.flatMap({ $0.resources }) {
                    roadmap.addResource(resource)
                }
                
                try await firebaseService.updateCareerRoadmap(roadmap)
                self.careerRoadmap = roadmap
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    var filteredRecommendations: [String] {
        guard selectedCategory != .all else { return recommendations }
        
        return recommendations.filter { recommendation in
            let lowercased = recommendation.lowercased()
            switch selectedCategory {
            case .academic:
                return lowercased.contains("course") || lowercased.contains("grade") || lowercased.contains("academic")
            case .extracurricular:
                return lowercased.contains("club") || lowercased.contains("activity") || lowercased.contains("leadership")
            case .skills:
                return lowercased.contains("skill") || lowercased.contains("learn") || lowercased.contains("develop")
            case .resources:
                return lowercased.contains("resource") || lowercased.contains("tool") || lowercased.contains("material")
            case .all:
                return true
            }
        }
    }
    
    // MARK: - Career Roadmap
    
    func addMilestone(_ milestone: CareerRoadmap.Milestone) async {
        guard var roadmap = careerRoadmap else { return }
        
        roadmap.addMilestone(milestone)
        
        do {
            try await firebaseService.updateCareerRoadmap(roadmap)
            self.careerRoadmap = roadmap
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    func addResource(_ resource: CareerRoadmap.Resource) async {
        guard var roadmap = careerRoadmap else { return }
        
        roadmap.addResource(resource)
        
        do {
            try await firebaseService.updateCareerRoadmap(roadmap)
            self.careerRoadmap = roadmap
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Milestone Management
    
    func updateMilestoneAndGenerateRecommendations(_ milestone: CareerRoadmap.Milestone) async {
        guard var roadmap = careerRoadmap else { return }
        
        // Update the milestone first
        if let index = roadmap.milestones.firstIndex(where: { $0.id == milestone.id }) {
            roadmap.milestones[index] = milestone
            
            do {
                try await firebaseService.updateCareerRoadmap(roadmap)
                self.careerRoadmap = roadmap
                
                // Generate new recommendations based on the completed milestone
                await generateRecommendations()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
    
    func updateMilestone(_ milestone: CareerRoadmap.Milestone) async {
        guard var roadmap = careerRoadmap else { return }
        
        // Find and update the milestone
        if let index = roadmap.milestones.firstIndex(where: { $0.id == milestone.id }) {
            roadmap.milestones[index] = milestone
            
            do {
                try await firebaseService.updateCareerRoadmap(roadmap)
                self.careerRoadmap = roadmap
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
    
    func removeMilestone(id: String) async {
        guard var roadmap = careerRoadmap else { return }
        
        // Remove the milestone
        roadmap.milestones.removeAll { $0.id == id }
        
        do {
            try await firebaseService.updateCareerRoadmap(roadmap)
            self.careerRoadmap = roadmap
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Resource Management
    
    func updateResource(_ resource: CareerRoadmap.Resource) async {
        guard var roadmap = careerRoadmap else { return }
        
        // Find and update the resource
        if let index = roadmap.resources.firstIndex(where: { $0.id == resource.id }) {
            roadmap.resources[index] = resource
            
            do {
                try await firebaseService.updateCareerRoadmap(roadmap)
                self.careerRoadmap = roadmap
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
    
    func removeResource(id: String) async {
        guard var roadmap = careerRoadmap else { return }
        
        // Remove the resource
        roadmap.resources.removeAll { $0.id == id }
        
        do {
            try await firebaseService.updateCareerRoadmap(roadmap)
            self.careerRoadmap = roadmap
        } catch {
            self.error = error.localizedDescription
        }
    }
} 