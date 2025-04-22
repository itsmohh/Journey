import Foundation
import FirebaseFirestore

struct Admin: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let districtName: String
    let districtId: String
    let role: Role
    var schools: [String]
    let createdAt: Date
    
    enum Role: String, Codable {
        case districtAdmin = "district_admin"
        case schoolAdmin = "school_admin"
        case superAdmin = "super_admin"
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case districtName = "district_name"
        case districtId = "district_id"
        case role
        case schools
        case createdAt = "created_at"
    }
    
    init(id: String, email: String, name: String, districtName: String, districtId: String, role: Role, schools: [String] = [], createdAt: Date = Date()) {
        self.id = id
        self.email = email
        self.name = name
        self.districtName = districtName
        self.districtId = districtId
        self.role = role
        self.schools = schools
        self.createdAt = createdAt
    }
    
    init?(from document: DocumentSnapshot) {
        guard 
            let data = document.data(),
            let email = data["email"] as? String,
            let name = data["name"] as? String,
            let districtName = data["district_name"] as? String,
            let districtId = data["district_id"] as? String,
            let roleString = data["role"] as? String,
            let role = Role(rawValue: roleString),
            let schools = data["schools"] as? [String],
            let createdAt = (data["created_at"] as? Timestamp)?.dateValue()
        else {
            return nil
        }
        
        self.id = document.documentID
        self.email = email
        self.name = name
        self.districtName = districtName
        self.districtId = districtId
        self.role = role
        self.schools = schools
        self.createdAt = createdAt
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "email": email,
            "name": name,
            "district_name": districtName,
            "district_id": districtId,
            "role": role.rawValue,
            "schools": schools,
            "created_at": Timestamp(date: createdAt)
        ]
    }
} 