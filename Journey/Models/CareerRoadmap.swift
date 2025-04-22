import Foundation
import FirebaseFirestore

struct CareerRoadmap: Codable, Identifiable {
    let id: String
    let userId: String
    let careerGoal: String
    let grade: Int
    var milestones: [Milestone]
    var resources: [Resource]
    var lastUpdated: Date
    
    init(id: String, userId: String, careerGoal: String, grade: Int, milestones: [Milestone] = [], resources: [Resource] = [], lastUpdated: Date = Date()) {
        self.id = id
        self.userId = userId
        self.careerGoal = careerGoal
        self.grade = grade
        self.milestones = milestones
        self.resources = resources
        self.lastUpdated = lastUpdated
    }
    
    struct Milestone: Codable, Identifiable {
        let id: String
        var title: String
        var description: String
        var dueDate: Date?
        var isCompleted: Bool
        var gradeLevel: Int
        var category: Category
        
        enum Category: String, Codable {
            case academic
            case extracurricular
            case skill
            case test
            case application
        }
    }
    
    struct Resource: Codable, Identifiable {
        let id: String
        var title: String
        var description: String
        var url: String
        var type: ResourceType
        var gradeLevel: Int
        var category: Category
        
        enum ResourceType: String, Codable {
            case online
            case book
            case video
            case course
            case tool
        }
        
        enum Category: String, Codable {
            case academic
            case skill
            case test
            case application
            case career
        }
    }
    
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.userId = data["userId"] as? String ?? ""
        self.careerGoal = data["careerGoal"] as? String ?? ""
        self.grade = data["grade"] as? Int ?? 9
        self.lastUpdated = (data["lastUpdated"] as? Timestamp)?.dateValue() ?? Date()
        
        // Decode milestones
        if let milestonesData = data["milestones"] as? [[String: Any]] {
            self.milestones = milestonesData.compactMap { milestoneData in
                guard let id = milestoneData["id"] as? String,
                      let title = milestoneData["title"] as? String,
                      let description = milestoneData["description"] as? String,
                      let gradeLevel = milestoneData["gradeLevel"] as? Int,
                      let categoryString = milestoneData["category"] as? String,
                      let category = Milestone.Category(rawValue: categoryString) else {
                    return nil
                }
                
                return Milestone(
                    id: id,
                    title: title,
                    description: description,
                    dueDate: (milestoneData["dueDate"] as? Timestamp)?.dateValue(),
                    isCompleted: milestoneData["isCompleted"] as? Bool ?? false,
                    gradeLevel: gradeLevel,
                    category: category
                )
            }
        } else {
            self.milestones = []
        }
        
        // Decode resources
        if let resourcesData = data["resources"] as? [[String: Any]] {
            self.resources = resourcesData.compactMap { resourceData in
                guard let id = resourceData["id"] as? String,
                      let title = resourceData["title"] as? String,
                      let description = resourceData["description"] as? String,
                      let url = resourceData["url"] as? String,
                      let typeString = resourceData["type"] as? String,
                      let type = Resource.ResourceType(rawValue: typeString),
                      let gradeLevel = resourceData["gradeLevel"] as? Int,
                      let categoryString = resourceData["category"] as? String,
                      let category = Resource.Category(rawValue: categoryString) else {
                    return nil
                }
                
                return Resource(
                    id: id,
                    title: title,
                    description: description,
                    url: url,
                    type: type,
                    gradeLevel: gradeLevel,
                    category: category
                )
            }
        } else {
            self.resources = []
        }
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "userId": userId,
            "careerGoal": careerGoal,
            "grade": grade,
            "milestones": milestones.map { milestone in
                [
                    "id": milestone.id,
                    "title": milestone.title,
                    "description": milestone.description,
                    "dueDate": milestone.dueDate.map { Timestamp(date: $0) } as Any,
                    "isCompleted": milestone.isCompleted,
                    "gradeLevel": milestone.gradeLevel,
                    "category": milestone.category.rawValue
                ]
            },
            "resources": resources.map { resource in
                [
                    "id": resource.id,
                    "title": resource.title,
                    "description": resource.description,
                    "url": resource.url,
                    "type": resource.type.rawValue,
                    "gradeLevel": resource.gradeLevel,
                    "category": resource.category.rawValue
                ]
            },
            "lastUpdated": Timestamp(date: lastUpdated)
        ]
    }
    
    // MARK: - Mutating Methods
    
    mutating func addMilestone(_ milestone: Milestone) {
        milestones.append(milestone)
        lastUpdated = Date()
    }
    
    mutating func addResource(_ resource: Resource) {
        resources.append(resource)
        lastUpdated = Date()
    }
    
    mutating func updateMilestone(_ milestone: Milestone) {
        if let index = milestones.firstIndex(where: { $0.id == milestone.id }) {
            milestones[index] = milestone
            lastUpdated = Date()
        }
    }
    
    mutating func updateResource(_ resource: Resource) {
        if let index = resources.firstIndex(where: { $0.id == resource.id }) {
            resources[index] = resource
            lastUpdated = Date()
        }
    }
    
    mutating func removeMilestone(id: String) {
        milestones.removeAll { $0.id == id }
        lastUpdated = Date()
    }
    
    mutating func removeResource(id: String) {
        resources.removeAll { $0.id == id }
        lastUpdated = Date()
    }
} 