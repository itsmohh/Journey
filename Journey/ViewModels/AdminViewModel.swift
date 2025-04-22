import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AdminViewModel: ObservableObject {
    @Published var currentAdmin: Admin?
    @Published var isLoading = false
    @Published var error: String?
    @Published var districtStudents: [User] = []
    @Published var districtSchools: [String] = []
    @Published var selectedSchool: String?
    
    let firebaseService = FirebaseService.shared
    
    init() {
        loadAdminProfile()
    }
    
    // MARK: - Admin Profile Management
    
    private func loadAdminProfile() {
        guard let basicUser = firebaseService.getCurrentUser() else {
            error = "No authenticated user"
            return
        }
        
        isLoading = true
        
        Task {
            do {
                if let admin = try await firebaseService.getAdminProfile(userId: basicUser.id) {
                    self.currentAdmin = admin
                    await loadDistrictData()
                } else {
                    self.error = "Not authorized as admin"
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
            currentAdmin = nil
            districtStudents = []
            districtSchools = []
            selectedSchool = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - District Data Management
    
    private func loadDistrictData() async {
        guard let admin = currentAdmin else { return }
        
        isLoading = true
        
        do {
            // Load district schools
            self.districtSchools = admin.schools
            
            // Load students from the district
            let students = try await firebaseService.getDistrictStudents(districtId: admin.districtId)
            self.districtStudents = students
            
            if let firstSchool = districtSchools.first {
                self.selectedSchool = firstSchool
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func addSchool(_ schoolName: String) async {
        guard var admin = currentAdmin else { return }
        
        isLoading = true
        
        do {
            admin.schools.append(schoolName)
            try await firebaseService.updateAdminProfile(admin)
            self.currentAdmin = admin
            self.districtSchools = admin.schools
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func removeSchool(_ schoolName: String) async {
        guard var admin = currentAdmin else { return }
        
        isLoading = true
        
        do {
            admin.schools.removeAll { $0 == schoolName }
            try await firebaseService.updateAdminProfile(admin)
            self.currentAdmin = admin
            self.districtSchools = admin.schools
            
            if selectedSchool == schoolName {
                selectedSchool = districtSchools.first
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Student Management
    
    var filteredStudents: [User] {
        guard let selectedSchool = selectedSchool else { return districtStudents }
        return districtStudents.filter { $0.school == selectedSchool }
    }
    
    func getStudentProgress(_ student: User) async -> (completed: Int, total: Int) {
        do {
            if let roadmap = try await firebaseService.getCareerRoadmap(userId: student.id) {
                let completed = roadmap.milestones.filter { $0.isCompleted }.count
                let total = roadmap.milestones.count
                return (completed, total)
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        return (0, 0)
    }
    
    func generateProgressReport(for student: User) async -> String {
        guard let admin = currentAdmin else { return "" }
        
        do {
            if let roadmap = try await firebaseService.getCareerRoadmap(userId: student.id) {
                let completed = roadmap.milestones.filter { $0.isCompleted }
                let incomplete = roadmap.milestones.filter { !$0.isCompleted }
                
                var report = """
                Progress Report for \(student.name)
                School: \(student.school)
                Grade: \(student.grade)
                Career Goal: \(student.careerGoal)
                
                Overall Progress:
                - Completed Tasks: \(completed.count)
                - Remaining Tasks: \(incomplete.count)
                - Completion Rate: \(Int((Double(completed.count) / Double(roadmap.milestones.count)) * 100))%
                
                Completed Milestones:
                """
                
                for milestone in completed {
                    report += "\n- \(milestone.title) (\(milestone.category.rawValue))"
                }
                
                report += "\n\nUpcoming Tasks:"
                for milestone in incomplete.prefix(5) {
                    report += "\n- \(milestone.title) (\(milestone.category.rawValue))"
                }
                
                return report
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        return "Unable to generate progress report"
    }
} 