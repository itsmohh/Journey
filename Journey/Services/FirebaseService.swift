import Foundation
import FirebaseFirestore
import FirebaseAuth

enum FirebaseError: LocalizedError {
    case notAuthenticated
    case documentNotFound
    case invalidData
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .documentNotFound:
            return "Document not found"
        case .invalidData:
            return "Invalid data format"
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}

class FirebaseService {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()
    
    private init() {
        print("FirebaseService initialized")
    }
    
    // MARK: - User Management
    
    func getCurrentUser() -> User? {
        guard let authUser = Auth.auth().currentUser else { return nil }
        return User(id: authUser.uid, name: authUser.displayName ?? "", email: authUser.email ?? "")
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
    
    // MARK: - User Profile
    
    func getUserProfile(userId: String) async throws -> User {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            if document.exists, let data = document.data() {
                guard let name = data["name"] as? String,
                      let email = data["email"] as? String,
                      let grade = data["grade"] as? Int,
                      let careerGoal = data["careerGoal"] as? String,
                      let school = data["school"] as? String,
                      let location = data["location"] as? String,
                      let interests = data["interests"] as? [String],
                      let progress = data["progress"] as? [String: Bool],
                      let aiRecommendations = data["aiRecommendations"] as? [String],
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                    throw FirebaseError.invalidData
                }
                
                var user = User(
                    id: userId,
                    name: name,
                    email: email,
                    grade: grade,
                    careerGoal: careerGoal,
                    school: school,
                    location: location,
                    interests: interests
                )
                user.progress = progress
                user.aiRecommendations = aiRecommendations
                user.createdAt = createdAt
                return user
            } else {
                guard let authUser = Auth.auth().currentUser else {
                    throw FirebaseError.notAuthenticated
                }
                return User(
                    id: authUser.uid,
                    name: authUser.displayName ?? "",
                    email: authUser.email ?? ""
                )
            }
        } catch {
            throw FirebaseError.unknown(error)
        }
    }
    
    func createUserProfile(_ user: User) async throws {
        guard let _ = Auth.auth().currentUser else {
            throw FirebaseError.notAuthenticated
        }
        
        let data: [String: Any] = [
            "name": user.name,
            "email": user.email,
            "grade": user.grade,
            "careerGoal": user.careerGoal,
            "school": user.school,
            "location": user.location,
            "interests": user.interests,
            "progress": user.progress,
            "aiRecommendations": user.aiRecommendations,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        try await db.collection("users").document(user.id).setData(data)
    }
    
    // MARK: - Career Roadmap
    
    func createCareerRoadmap(_ roadmap: CareerRoadmap) async throws {
        print("Creating career roadmap for user ID: \(roadmap.userId)")
        
        guard let currentUser = Auth.auth().currentUser,
              currentUser.uid == roadmap.userId else {
            throw FirebaseError.notAuthenticated
        }
        
        let data = roadmap.toDictionary()
        try await db.collection("careerRoadmaps").document(roadmap.id).setData(data)
    }
    
    func updateCareerRoadmap(_ roadmap: CareerRoadmap) async throws {
        print("Updating career roadmap for user ID: \(roadmap.userId)")
        
        guard let currentUser = Auth.auth().currentUser,
              currentUser.uid == roadmap.userId else {
            throw FirebaseError.notAuthenticated
        }
        
        let data = roadmap.toDictionary()
        try await db.collection("careerRoadmaps").document(roadmap.id).setData(data, merge: true)
    }
    
    func getCareerRoadmap(userId: String) async throws -> CareerRoadmap? {
        guard let currentUser = Auth.auth().currentUser,
              currentUser.uid == userId else {
            throw FirebaseError.notAuthenticated
        }
        
        let querySnapshot = try await db.collection("careerRoadmaps")
            .whereField("userId", isEqualTo: userId)
            .limit(to: 1)
            .getDocuments()
        
        guard let document = querySnapshot.documents.first,
              let data = document.data() as? [String: Any] else {
            return nil
        }
        
        return try await decodeCareerRoadmap(from: data, withId: document.documentID)
    }
    
    private func decodeCareerRoadmap(from data: [String: Any], withId id: String) async throws -> CareerRoadmap {
        guard let userId = data["userId"] as? String,
              let careerGoal = data["careerGoal"] as? String,
              let grade = data["grade"] as? Int else {
            throw FirebaseError.invalidData
        }
        
        let milestones = (data["milestones"] as? [[String: Any]] ?? []).compactMap { milestoneData -> CareerRoadmap.Milestone? in
            guard let id = milestoneData["id"] as? String,
                  let title = milestoneData["title"] as? String,
                  let description = milestoneData["description"] as? String,
                  let isCompleted = milestoneData["isCompleted"] as? Bool,
                  let gradeLevel = milestoneData["gradeLevel"] as? Int,
                  let categoryString = milestoneData["category"] as? String,
                  let category = CareerRoadmap.Milestone.Category(rawValue: categoryString) else {
                return nil
            }
            
            return CareerRoadmap.Milestone(
                id: id,
                title: title,
                description: description,
                dueDate: (milestoneData["dueDate"] as? Timestamp)?.dateValue(),
                isCompleted: isCompleted,
                gradeLevel: gradeLevel,
                category: category
            )
        }
        
        let resources = (data["resources"] as? [[String: Any]] ?? []).compactMap { resourceData -> CareerRoadmap.Resource? in
            guard let id = resourceData["id"] as? String,
                  let title = resourceData["title"] as? String,
                  let description = resourceData["description"] as? String,
                  let url = resourceData["url"] as? String,
                  let typeString = resourceData["type"] as? String,
                  let type = CareerRoadmap.Resource.ResourceType(rawValue: typeString),
                  let gradeLevel = resourceData["gradeLevel"] as? Int,
                  let categoryString = resourceData["category"] as? String,
                  let category = CareerRoadmap.Resource.Category(rawValue: categoryString) else {
                return nil
            }
            
            return CareerRoadmap.Resource(
                id: id,
                title: title,
                description: description,
                url: url,
                type: type,
                gradeLevel: gradeLevel,
                category: category
            )
        }
        
        let lastUpdated = (data["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
        
        return CareerRoadmap(
            id: id,
            userId: userId,
            careerGoal: careerGoal,
            grade: grade,
            milestones: milestones,
            resources: resources,
            lastUpdated: lastUpdated
        )
    }
    
    // MARK: - Admin Management
    
    func getAdminProfile(userId: String) async throws -> Admin? {
        let docRef = db.collection("admins").document(userId)
        let document = try await docRef.getDocument()
        
        return Admin(from: document)
    }
    
    func updateAdminProfile(_ admin: Admin) async throws {
        let docRef = db.collection("admins").document(admin.id)
        try await docRef.setData(admin.toDictionary(), merge: true)
    }
    
    func getDistrictStudents(districtId: String) async throws -> [User] {
        let querySnapshot = try await db.collection("users")
            .whereField("district_id", isEqualTo: districtId)
            .getDocuments()
        
        return try await withThrowingTaskGroup(of: User?.self) { group in
            var students: [User] = []
            
            for document in querySnapshot.documents {
                if let user = User(from: document) {
                    students.append(user)
                }
            }
            
            return students
        }
    }
} 
