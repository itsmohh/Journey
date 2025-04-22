import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var viewModel: UserViewModel
    @State private var selectedCategory: CareerRoadmap.Milestone.Category?
    @State private var showRecommendationAlert = false
    @State private var pendingMilestone: CareerRoadmap.Milestone?
    @Environment(\.colorScheme) private var colorScheme
    
    private let categories: [CareerRoadmap.Milestone.Category] = [
        .academic, .extracurricular, .skill, .test, .application
    ]
    
    private let gradient = LinearGradient(
        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    if let user = viewModel.currentUser {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Your Tasks")
                                    .font(.system(size: 24, weight: .medium, design: .rounded))
                                Text("Track your progress")
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            TaskProgressCircle(completed: completedTasksCount, total: totalTasksCount)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(cardColor)
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal)
                
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        TaskCategoryButton(title: "All", isSelected: selectedCategory == nil) {
                            withAnimation {
                                selectedCategory = nil
                            }
                        }
                        
                        ForEach(categories, id: \.rawValue) { category in
                            TaskCategoryButton(
                                title: category.rawValue.capitalized,
                                isSelected: selectedCategory == category
                            ) {
                                withAnimation {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                if let roadmap = viewModel.careerRoadmap {
                    LazyVStack(spacing: 16) {
                        let filteredMilestones = filterMilestones(roadmap.milestones)
                        let filteredResources = filterResources(roadmap.resources)
                        
                        if !filteredMilestones.isEmpty {
                            SectionHeader(title: "Action Items", icon: "flag.fill")
                            
                            ForEach(filteredMilestones) { milestone in
                                TaskMilestoneCard(milestone: milestone) { updatedMilestone in
                                    if !milestone.isCompleted && updatedMilestone.isCompleted {
                                        pendingMilestone = updatedMilestone
                                        showRecommendationAlert = true
                                    } else {
                                        Task {
                                            await viewModel.updateMilestone(updatedMilestone)
                                            await viewModel.loadCareerRoadmap()
                                        }
                                    }
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        
                        if !filteredResources.isEmpty {
                            SectionHeader(title: "Helpful Resources", icon: "book.fill")
                                .padding(.top, 8)
                            
                            ForEach(filteredResources) { resource in
                                TaskResourceCard(resource: resource)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal)
                } else {
                    EmptyStateView(
                        title: "No Tasks Yet",
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
        .alert("Generate New Recommendations?", isPresented: $showRecommendationAlert) {
            Button("Cancel") {
                if let milestone = pendingMilestone {
                    var uncompleted = milestone
                    uncompleted.isCompleted = false
                    Task {
                        await viewModel.updateMilestone(uncompleted)
                        await viewModel.loadCareerRoadmap()
                    }
                }
                pendingMilestone = nil
            }
            
            Button("Generate") {
                if let milestone = pendingMilestone {
                    Task {
                        await viewModel.updateMilestoneAndGenerateRecommendations(milestone)
                        await viewModel.loadCareerRoadmap()
                    }
                }
                pendingMilestone = nil
            }
        } message: {
            Text("Would you like to generate new recommendations based on your completed milestone?")
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
    
    private var completedTasksCount: Int {
        viewModel.careerRoadmap?.milestones.filter { $0.isCompleted }.count ?? 0
    }
    
    private var totalTasksCount: Int {
        viewModel.careerRoadmap?.milestones.count ?? 0
    }
    
    private func filterMilestones(_ milestones: [CareerRoadmap.Milestone]) -> [CareerRoadmap.Milestone] {
        var filtered = milestones
        
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        return filtered.sorted { a, b in
            if a.isCompleted == b.isCompleted {
                return a.gradeLevel < b.gradeLevel
            }
            return !a.isCompleted && b.isCompleted
        }
    }
    
    private func filterResources(_ resources: [CareerRoadmap.Resource]) -> [CareerRoadmap.Resource] {
        var filtered = resources
        
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == .skill }
        }
        
        return filtered
    }
}

struct TaskProgressCircle: View {
    let completed: Int
    let total: Int
    
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
    
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
                Text("\(completed)/\(total)")
                    .font(.title2.bold())
                Text("Tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 80, height: 80)
    }
}

struct TaskCategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: .rounded).weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue.opacity(0.8) : Color(.systemGray6))
                )
                .foregroundStyle(isSelected ? .white : .primary)
                .shadow(color: isSelected ? .blue.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct TaskMilestoneCard: View {
    let milestone: CareerRoadmap.Milestone
    let onUpdate: (CareerRoadmap.Milestone) -> Void
    @State private var isExpanded = false
    @State private var isTemporarilyCompleted = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
    
    private var isCompleted: Bool {
        milestone.isCompleted || isTemporarilyCompleted
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        var updatedMilestone = milestone
                        updatedMilestone.isCompleted.toggle()
                        isTemporarilyCompleted = updatedMilestone.isCompleted
                        onUpdate(updatedMilestone)
                    }
                }) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isCompleted ? .green : .gray)
                        .font(.title2)
                        .symbolEffect(.bounce, options: .repeat(1), value: isCompleted)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(milestone.title)
                        .font(.headline)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    HStack(spacing: 4) {
                        Text("Grade \(milestone.gradeLevel)")
                        Text("•")
                        Text(milestone.category.rawValue.capitalized)
                            .foregroundStyle(categoryColor(for: milestone.category))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundStyle(.gray)
                        .imageScale(.large)
                }
            }
            
            if isExpanded {
                Text(milestone.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                
                if let dueDate = milestone.dueDate {
                    Label {
                        Text(dueDate, style: .date)
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardColor)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
    
    private func categoryColor(for category: CareerRoadmap.Milestone.Category) -> Color {
        switch category {
        case .academic: return .blue
        case .extracurricular: return .green
        case .skill: return .purple
        case .test: return .orange
        case .application: return .red
        }
    }
}

struct TaskResourceCard: View {
    let resource: CareerRoadmap.Resource
    @State private var isExpanded = false
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : .white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.title)
                        .font(.headline)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    HStack(spacing: 4) {
                        Label(resource.type.rawValue.capitalized, systemImage: iconName(for: resource.type))
                        Text("•")
                        Text("Grade \(resource.gradeLevel)")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundStyle(.gray)
                        .imageScale(.large)
                }
            }
            
            if isExpanded {
                Text(resource.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                
                if !resource.url.isEmpty {
                    Link(destination: URL(string: resource.url)!) {
                        HStack {
                            Image(systemName: "link")
                            Text("Open Resource")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                    }
                    .padding(.leading, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardColor)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.gray.opacity(0.1), lineWidth: 1)
        )
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

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

#Preview {
    TasksView()
        .environmentObject(UserViewModel())
} 