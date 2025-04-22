import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var viewModel: UserViewModel
    @State private var showingSignOutAlert = false
    
    var body: some View {
        TabView {
            RecommendationsView()
                .tabItem {
                    Label("Recommendations", systemImage: "star.fill")
                }
            
            RoadmapView()
                .tabItem {
                    Label("Roadmap", systemImage: "map.fill")
                }
            
            TasksView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSignOutAlert = true }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                do {
                    try viewModel.signOut()
                } catch {
                    print("Error signing out: \(error)")
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(UserViewModel())
} 