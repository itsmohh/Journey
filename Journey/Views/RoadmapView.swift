import SwiftUI

struct RoadmapView: View {
    @EnvironmentObject private var viewModel: UserViewModel
    @State private var selectedGrade: Int?
    @Environment(\.colorScheme) private var colorScheme
    
    private let gradient = LinearGradient(
        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with Progress Overview
                VStack(alignment: .leading, spacing: 12) {
                    if let user = viewModel.currentUser {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Journey to")
                                    .font(.system(size: 24, weight: .medium, design: .rounded))
                                Text(user.careerGoal)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(gradient)
                            }
                            Spacer()
                            ProgressCircle(grade: user.grade)
                        }
                        
                        // Current Status
                        StatusCard(user: user)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(cardColor)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal)
                
                // Grade Timeline
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        if let user = viewModel.currentUser {
                            ForEach(9...12, id: \.self) { grade in
                                GradeButton(
                                    grade: grade,
                                    currentGrade: user.grade,
                                    isSelected: selectedGrade == grade
                                ) {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedGrade = selectedGrade == grade ? nil : grade
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                if let roadmap = viewModel.careerRoadmap {
                    LazyVStack(spacing: 16) {
                        if selectedGrade == nil {
                            // Overview of all grades
                            RoadmapProgressOverview(milestones: roadmap.milestones)
                                .padding(.horizontal)
                        }
                        
                        // Grade-specific roadmap visualization
                        if let grade = selectedGrade {
                            GradeRoadmapView(grade: grade, roadmap: roadmap)
                                .padding(.horizontal)
                        }
                    }
                } else {
                    EmptyStateView(
                        title: "No Roadmap Yet",
                        message: "Add recommendations to your roadmap to start tracking your progress",
                        actionTitle: "Go to Recommendations",
                        action: {
                            // Navigation will be handled by parent view
                        }
                    )
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            if let user = viewModel.currentUser {
                await viewModel.loadCareerRoadmap()
            }
        }
        .background(Color(.systemBackground))
    }
    
    private var cardColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
}

struct StatusCard: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Status")
                .font(.headline)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Grade \(user.grade)", systemImage: "graduationcap.fill")
                    Label(user.school, systemImage: "building.columns.fill")
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    if !user.interests.isEmpty {
                        Label("Interests", systemImage: "star.fill")
                        Text(user.interests.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct ProgressCircle: View {
    let grade: Int
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.2), lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 4) {
                Text("Grade")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(grade)")
                    .font(.title2.bold())
            }
        }
        .frame(width: 80, height: 80)
    }
    
    private var progress: Double {
        switch grade {
        case 9: return 0.25
        case 10: return 0.5
        case 11: return 0.75
        case 12: return 1.0
        default: return 0
        }
    }
}

struct GradeButton: View {
    let grade: Int
    let currentGrade: Int
    let isSelected: Bool
    let action: () -> Void
    
    private var status: GradeStatus {
        if grade < currentGrade { return .completed }
        if grade == currentGrade { return .current }
        return .upcoming
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(status.color.opacity(isSelected ? 1 : 0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Group {
                            if status == .completed {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(grade)")
                                    .foregroundStyle(isSelected ? .white : status.color)
                            }
                        }
                    )
                
                Text(status.label)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? status.color : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private enum GradeStatus {
        case completed, current, upcoming
        
        var color: Color {
            switch self {
            case .completed: return .green
            case .current: return .blue
            case .upcoming: return .orange
            }
        }
        
        var label: String {
            switch self {
            case .completed: return "Completed"
            case .current: return "Current"
            case .upcoming: return "Upcoming"
            }
        }
    }
}

struct RoadmapProgressOverview: View {
    let milestones: [CareerRoadmap.Milestone]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progress Overview")
                .font(.headline)
            
            ForEach(9...12, id: \.self) { grade in
                let gradeProgress = calculateProgress(for: grade)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Grade \(grade)")
                            .font(.subheadline.bold())
                        Spacer()
                        Text("\(Int(gradeProgress.percentage * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    ProgressBar(
                        progress: gradeProgress.percentage,
                        total: gradeProgress.total,
                        completed: gradeProgress.completed
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func calculateProgress(for grade: Int) -> (percentage: Double, total: Int, completed: Int) {
        let gradeMilestones = milestones.filter { $0.gradeLevel == grade }
        let total = gradeMilestones.count
        let completed = gradeMilestones.filter { $0.isCompleted }.count
        let percentage = total > 0 ? Double(completed) / Double(total) : 0
        return (percentage, total, completed)
    }
}

struct ProgressBar: View {
    let progress: Double
    let total: Int
    let completed: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)
            
            Text("\(completed) of \(total) tasks completed")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct GradeRoadmapView: View {
    let grade: Int
    let roadmap: CareerRoadmap
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Grade \(grade) Roadmap")
                .font(.title2.bold())
            
            let gradeMilestones = roadmap.milestones.filter { $0.gradeLevel == grade }
            let gradeResources = roadmap.resources.filter { $0.gradeLevel == grade }
            
            if !gradeMilestones.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Key Milestones")
                        .font(.headline)
                    
                    ForEach(gradeMilestones) { milestone in
                        RoadmapMilestonePreview(milestone: milestone)
                    }
                }
            }
            
            if !gradeResources.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Resources")
                        .font(.headline)
                    
                    ForEach(gradeResources) { resource in
                        RoadmapResourcePreview(resource: resource)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardColor)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

struct RoadmapMilestonePreview: View {
    let milestone: CareerRoadmap.Milestone
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(milestone.isCompleted ? .green : .gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.subheadline)
                
                Text(milestone.category.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RoadmapResourcePreview: View {
    let resource: CareerRoadmap.Resource
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName(for: resource.type))
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(resource.title)
                    .font(.subheadline)
                
                Text(resource.type.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconName(for type: CareerRoadmap.Resource.ResourceType) -> String {
        switch type {
        case .online: return "globe"
        case .book: return "book.fill"
        case .video: return "play.circle.fill"
        case .course: return "graduationcap.fill"
        case .tool: return "hammer.fill"
        }
    }
}

#Preview {
    RoadmapView()
        .environmentObject(UserViewModel())
} 