import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    let id: String
    var name: String
    var email: String
    var grade: Int
    var careerGoal: String
    var school: String
    var location: String
    var interests: [String]
    var progress: [String: Bool]
    var aiRecommendations: [String]
    var createdAt: Date
    var districtId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case grade
        case careerGoal
        case school
        case location
        case interests
        case progress
        case aiRecommendations
        case createdAt
        case districtId
    }
    
    init(id: String, name: String, email: String, grade: Int = 9, careerGoal: String = "", school: String = "", location: String = "", interests: [String] = [], districtId: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.grade = grade
        self.careerGoal = careerGoal
        self.school = school
        self.location = location
        self.interests = interests
        self.progress = [:]
        self.aiRecommendations = []
        self.createdAt = Date()
        self.districtId = districtId
    }
    
    init?(from document: DocumentSnapshot) {
        guard 
            let data = document.data(),
            let name = data["name"] as? String,
            let email = data["email"] as? String,
            let grade = data["grade"] as? Int,
            let careerGoal = data["careerGoal"] as? String,
            let school = data["school"] as? String,
            let location = data["location"] as? String,
            let interests = data["interests"] as? [String],
            let progress = data["progress"] as? [String: Bool],
            let aiRecommendations = data["aiRecommendations"] as? [String],
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        else {
            return nil
        }
        
        self.id = document.documentID
        self.name = name
        self.email = email
        self.grade = grade
        self.careerGoal = careerGoal
        self.school = school
        self.location = location
        self.interests = interests
        self.progress = progress
        self.aiRecommendations = aiRecommendations
        self.createdAt = createdAt
        self.districtId = data["district_id"] as? String
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "email": email,
            "grade": grade,
            "careerGoal": careerGoal,
            "school": school,
            "location": location,
            "interests": interests,
            "progress": progress,
            "aiRecommendations": aiRecommendations,
            "createdAt": Timestamp(date: createdAt)
        ]
        
        if let districtId = districtId {
            dict["district_id"] = districtId
        }
        
        return dict
    }
} 