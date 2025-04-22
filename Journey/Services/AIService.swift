import Foundation

enum AIError: Error {
    case invalidResponse
    case networkError
    case unknown
    
    var message: String {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service"
        case .networkError:
            return "Network error occurred"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

struct AIRecommendation {
    let title: String
    let description: String
    let gradeLevel: Int
    let category: CareerRoadmap.Milestone.Category
    let dueDate: Date?
    let resources: [CareerRoadmap.Resource]
}

class AIService {
    static let shared = AIService()
    private let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    init() {}
    
    // MARK: - Career Recommendations
    
    func generateCareerRecommendations(for user: User, completedMilestones: [CareerRoadmap.Milestone]) async throws -> [AIRecommendation] {
        let completedMilestonesText = completedMilestones.isEmpty ? "No milestones completed yet." :
            completedMilestones.map { "- \($0.title) (Grade \($0.gradeLevel), \($0.category.rawValue))" }.joined(separator: "\n")
        
        let prompt = """
        As a college guidance counselor, generate personalized recommendations for a student with the following profile:
        
        Student Profile:
        - Current Grade: \(user.grade)
        - Career Goal: \(user.careerGoal)
        - School: \(user.school)
        - Interests: \(user.interests.joined(separator: ", "))
        
        Completed Milestones:
        \(completedMilestonesText)
        
        Based on their progress and career goal, provide 3-5 specific recommendations. For each recommendation:
        1. Provide a clear title and detailed description
        2. Specify the appropriate grade level (9-12)
        3. Assign a category (academic, extracurricular, skill, test, or application)
        4. Include relevant resources (online resources, books, courses, or tools)
        5. Consider timing and prerequisites
        
        Format each recommendation in JSON:
        {
            "recommendations": [
                {
                    "title": "string",
                    "description": "string",
                    "gradeLevel": number,
                    "category": "academic|extracurricular|skill|test|application",
                    "dueDate": "YYYY-MM-DD" (optional),
                    "resources": [
                        {
                            "title": "string",
                            "description": "string",
                            "url": "string",
                            "type": "online|book|video|course|tool"
                        }
                    ]
                }
            ]
        }
        
        Ensure recommendations:
        1. Build upon completed milestones
        2. Are appropriate for current grade level
        3. Align with career goal
        4. Include specific action items
        5. Provide relevant resources
        """
        
        let response = try await generateResponse(prompt: prompt)
        return try parseRecommendations(from: response)
    }
    
    private func parseRecommendations(from jsonString: String) throws -> [AIRecommendation] {
        // Extract JSON from the response (it might be wrapped in markdown code blocks)
        let jsonPattern = #"\{[\s\S]*\}"#
        guard let jsonMatch = jsonString.range(of: jsonPattern, options: .regularExpression) else {
            throw AIError.invalidResponse
        }
        
        let jsonData = String(jsonString[jsonMatch]).data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct Response: Codable {
            let recommendations: [Recommendation]
            
            struct Recommendation: Codable {
                let title: String
                let description: String
                let gradeLevel: Int
                let category: String
                let dueDate: String?
                let resources: [Resource]
                
                struct Resource: Codable {
                    let title: String
                    let description: String
                    let url: String
                    let type: String
                }
            }
        }
        
        let response = try decoder.decode(Response.self, from: jsonData)
        
        return response.recommendations.compactMap { rec in
            guard let category = CareerRoadmap.Milestone.Category(rawValue: rec.category.lowercased()) else {
                return nil
            }
            
            let dueDate: Date?
            if let dueDateString = rec.dueDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                dueDate = formatter.date(from: dueDateString)
            } else {
                dueDate = nil
            }
            
            let resources = rec.resources.compactMap { res -> CareerRoadmap.Resource? in
                guard let type = CareerRoadmap.Resource.ResourceType(rawValue: res.type.lowercased()) else {
                    return nil
                }
                
                return CareerRoadmap.Resource(
                    id: UUID().uuidString,
                    title: res.title,
                    description: res.description,
                    url: res.url,
                    type: type,
                    gradeLevel: rec.gradeLevel,
                    category: .skill
                )
            }
            
            return AIRecommendation(
                title: rec.title,
                description: rec.description,
                gradeLevel: rec.gradeLevel,
                category: category,
                dueDate: dueDate,
                resources: resources
            )
        }
    }
    
    // MARK: - Roadmap Generation
    
    func generateCareerRoadmap(for user: User) async throws -> CareerRoadmap {
        let prompt = """
        As a college guidance counselor, create a detailed career roadmap for a grade \(user.grade) student interested in becoming a \(user.careerGoal).
        
        Include specific milestones and resources organized by category. For each item, specify:
        1. The appropriate grade level (9-12)
        2. The category (academic, extracurricular, skill, test, or application)
        3. A clear title and description
        4. For resources, specify if it's online, book, or program
        
        Format the response as follows:
        
        ACADEMIC
        - [Grade X] Course Name: Description of why this course is important
        
        EXTRACURRICULAR
        - [Grade X] Activity Name: Description of the activity and its benefits
        
        SKILLS
        - [Grade X] Skill Name: Description of how to develop this skill
        
        TESTS
        - [Grade X] Test Name: Description of test preparation and importance
        
        APPLICATIONS
        - [Grade X] Application Task: Description of the task and timeline
        
        RESOURCES
        - [Type] Resource Name: Description and URL (if applicable)
        
        Make sure to include items appropriate for the student's current grade and future grades.
        """
        
        let response = try await generateResponse(prompt: prompt)
        return try parseRoadmapResponse(response, for: user)
    }
    
    // MARK: - Private Methods
    
    private func generateResponse(prompt: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "system", "content": "You are an expert college guidance counselor AI assistant with deep knowledge of academic planning, career development, and college admissions. Provide specific, actionable advice tailored to each student's unique situation."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 700
        ]
        
        guard let url = URL(string: baseURL) else {
            throw AIError.unknown
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AIError.networkError
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.invalidResponse
        }
        
        return content
    }
    
    private func parseRoadmapResponse(_ response: String, for user: User) throws -> CareerRoadmap {
        var roadmap = CareerRoadmap(
            id: UUID().uuidString,
            userId: user.id,
            careerGoal: user.careerGoal,
            grade: user.grade
        )
        
        let lines = response.components(separatedBy: "\n")
        var currentCategory: CareerRoadmap.Milestone.Category?
        var currentSection: String?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            // Check for category headers
            if trimmedLine.lowercased().contains("academic") {
                currentCategory = .academic
                currentSection = trimmedLine
            } else if trimmedLine.lowercased().contains("extracurricular") {
                currentCategory = .extracurricular
                currentSection = trimmedLine
            } else if trimmedLine.lowercased().contains("skill") {
                currentCategory = .skill
                currentSection = trimmedLine
            } else if trimmedLine.lowercased().contains("test") {
                currentCategory = .test
                currentSection = trimmedLine
            } else if trimmedLine.lowercased().contains("application") {
                currentCategory = .application
                currentSection = trimmedLine
            } else if trimmedLine.lowercased().contains("resource") {
                // Parse resource line
                if let resource = parseResourceLine(trimmedLine, grade: user.grade) {
                    roadmap.addResource(resource)
                }
            } else if let category = currentCategory {
                // Parse milestone line
                if let milestone = parseMilestoneLine(trimmedLine, category: category, grade: user.grade) {
                    roadmap.addMilestone(milestone)
                }
            }
        }
        
        return roadmap
    }
    
    private func parseMilestoneLine(_ line: String, category: CareerRoadmap.Milestone.Category, grade: Int) -> CareerRoadmap.Milestone? {
        // Extract grade level if specified [Grade X]
        let gradePattern = #"\[Grade\s+(\d+)\]"#
        let gradeMatch = line.range(of: gradePattern, options: .regularExpression)
        let milestoneGrade = gradeMatch.map { Int(line[$0].replacingOccurrences(of: "[Grade ", with: "").replacingOccurrences(of: "]", with: "")) ?? grade } ?? grade
        
        // Remove grade specification from title
        let title = line.replacingOccurrences(of: gradePattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Split title and description if colon exists
        let components = title.split(separator: ":", maxSplits: 1)
        let milestoneTitle = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let description = components.count > 1 ? String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        
        return CareerRoadmap.Milestone(
            id: UUID().uuidString,
            title: milestoneTitle,
            description: description,
            dueDate: nil,
            isCompleted: false,
            gradeLevel: milestoneGrade,
            category: category
        )
    }
    
    private func parseResourceLine(_ line: String, grade: Int) -> CareerRoadmap.Resource? {
        // Extract resource type [Type]
        let typePattern = #"\[(\w+)\]"#
        let typeMatch = line.range(of: typePattern, options: .regularExpression)
        guard let typeMatch = typeMatch,
              let resourceType = CareerRoadmap.Resource.ResourceType(rawValue: String(line[typeMatch].replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: ""))) else {
            return nil
        }
        
        // Remove type specification from title
        let title = line.replacingOccurrences(of: typePattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Split title and description if colon exists
        let components = title.split(separator: ":", maxSplits: 1)
        let resourceTitle = String(components[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let description = components.count > 1 ? String(components[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        
        // Extract URL if present
        let urlPattern = #"https?://[^\s]+"#
        let urlMatch = description.range(of: urlPattern, options: .regularExpression)
        let urlString = urlMatch.map { String(description[$0]) } ?? ""
        let cleanDescription = description.replacingOccurrences(of: urlPattern, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return CareerRoadmap.Resource(
            id: UUID().uuidString,
            title: resourceTitle,
            description: cleanDescription,
            url: urlString,
            type: resourceType,
            gradeLevel: grade,
            category: .skill
        )
    }
} 
