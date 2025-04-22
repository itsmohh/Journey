import SwiftUI

struct RecommendationsView: View {
    @EnvironmentObject private var viewModel: UserViewModel
    @State private var isExpanded = false
    
    enum Category: String, CaseIterable {
        case all = "All"
        case academic = "Academic"
        case extracurricular = "Extracurricular"
        case skills = "Skills"
        case resources = "Resources"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome, \(viewModel.currentUser?.name ?? "Student")!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("AI-powered recommendations based on your profile")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // Category Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Category.allCases, id: \.self) { category in
                            CategoryButton(
                                title: category.rawValue,
                                isSelected: viewModel.selectedCategory == category,
                                action: { viewModel.selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                
                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.error {
                    ErrorView(message: error)
                } else if viewModel.filteredRecommendations.isEmpty {
                    EmptyStateView(
                        title: "No Recommendations Yet",
                        message: "Complete your profile to get personalized recommendations",
                        actionTitle: "Generate Recommendations",
                        action: {
                            Task {
                                await viewModel.generateRecommendations()
                            }
                        }
                    )
                } else {
                    // Recommendations List
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.filteredRecommendations, id: \.self) { recommendation in
                            RecommendationCard(
                                recommendation: recommendation,
                                onAddToRoadmap: {
                                    Task {
                                        await addRecommendationToRoadmap(recommendation)
                                    }
                                }
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .refreshable {
            await viewModel.generateRecommendations()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.signOut()
                }) {
                    Text("Sign Out")
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private func addRecommendationToRoadmap(_ recommendation: String) async {
        guard let user = viewModel.currentUser,
              let category = determineCategory(from: recommendation) else { return }
        
        let milestone = CareerRoadmap.Milestone(
            id: UUID().uuidString,
            title: recommendation,
            description: "Generated from AI recommendation",
            dueDate: nil,
            isCompleted: false,
            gradeLevel: user.grade,
            category: category
        )
        
        if viewModel.careerRoadmap == nil {
            // Create initial roadmap if none exists
            let newRoadmap = CareerRoadmap(
                id: UUID().uuidString,
                userId: user.id,
                careerGoal: user.careerGoal,
                grade: user.grade,
                milestones: [milestone]
            )
            
            do {
                try await viewModel.firebaseService.createCareerRoadmap(newRoadmap)
                viewModel.careerRoadmap = newRoadmap
            } catch {
                viewModel.error = error.localizedDescription
            }
        } else {
            await viewModel.addMilestone(milestone)
        }
    }
    
    private func determineCategory(from recommendation: String) -> CareerRoadmap.Milestone.Category? {
        let lowercased = recommendation.lowercased()
        
        if lowercased.contains("course") || lowercased.contains("grade") || lowercased.contains("academic") {
            return .academic
        } else if lowercased.contains("club") || lowercased.contains("activity") || lowercased.contains("leadership") {
            return .extracurricular
        } else if lowercased.contains("skill") || lowercased.contains("learn") || lowercased.contains("develop") {
            return .skill
        } else if lowercased.contains("test") || lowercased.contains("sat") || lowercased.contains("act") {
            return .test
        } else if lowercased.contains("application") || lowercased.contains("college") || lowercased.contains("essay") {
            return .application
        }
        
        return nil
    }
}

// MARK: - Supporting Views

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RecommendationCard: View {
    let recommendation: String
    let onAddToRoadmap: () -> Void
    @State private var isExpanded = false
    @State private var showingAddedFeedback = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                
                Text(recommendation)
                    .font(.body)
                    .lineLimit(isExpanded ? nil : 3)
                
                Spacer()
                
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                Divider()
                
                HStack {
                    Button(action: {
                        onAddToRoadmap()
                        withAnimation {
                            showingAddedFeedback = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                showingAddedFeedback = false
                            }
                        }
                    }) {
                        Label("Add to Roadmap", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(showingAddedFeedback)
                    
                    if showingAddedFeedback {
                        Text("Added to roadmap!")
                            .foregroundColor(.green)
                            .font(.caption)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    Button(action: { /* Share */ }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Generating personalized recommendations...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("This may take a few moments")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Oops! Something went wrong")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { /* Retry */ }) {
                Text("Try Again")
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: action) {
                Text(actionTitle)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    RecommendationsView()
} 