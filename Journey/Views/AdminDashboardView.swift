import SwiftUI
import Charts

struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminViewModel()
    @State private var selectedTab = 0
    @State private var showingAddSchool = false
    @State private var newSchoolName = ""
    @State private var selectedStudent: User?
    @State private var showingProgressReport = false
    @State private var progressReport = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if let admin = viewModel.currentAdmin {
                    // District Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(admin.districtName)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("District Administrator")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    
                    // Stats Overview
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        StatCard(
                            title: "Schools",
                            value: "\(viewModel.districtSchools.count)",
                            icon: "building.2.fill",
                            color: .blue
                        )
                        
                        StatCard(
                            title: "Students",
                            value: "\(viewModel.districtStudents.count)",
                            icon: "person.3.fill",
                            color: .green
                        )
                        
                        StatCard(
                            title: "Active",
                            value: "\(viewModel.filteredStudents.filter { !$0.careerGoal.isEmpty }.count)",
                            icon: "chart.line.uptrend.xyaxis",
                            color: .purple
                        )
                    }
                    .padding(.horizontal)
                    
                    // Main Content Tabs
                    Picker("View", selection: $selectedTab) {
                        Text("Schools").tag(0)
                        Text("Students").tag(1)
                        Text("Analytics").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    TabView(selection: $selectedTab) {
                        SchoolsListView(
                            schools: viewModel.districtSchools,
                            selectedSchool: $viewModel.selectedSchool,
                            onAddSchool: { showingAddSchool = true },
                            onRemoveSchool: { school in
                                Task {
                                    await viewModel.removeSchool(school)
                                }
                            }
                        )
                        .tag(0)
                        
                        StudentListView(
                            students: viewModel.filteredStudents,
                            onSelectStudent: { student in
                                selectedStudent = student
                                Task {
                                    progressReport = await viewModel.generateProgressReport(for: student)
                                    showingProgressReport = true
                                }
                            }
                        )
                        .tag(1)
                        
                        AnalyticsView(viewModel: viewModel)
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                } else {
                    ProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign Out") {
                        viewModel.signOut()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSchool) {
            AddSchoolSheet(
                isPresented: $showingAddSchool,
                schoolName: $newSchoolName,
                onAdd: {
                    guard !newSchoolName.isEmpty else { return }
                    Task {
                        await viewModel.addSchool(newSchoolName)
                        newSchoolName = ""
                        showingAddSchool = false
                    }
                }
            )
        }
        .sheet(isPresented: $showingProgressReport) {
            if let student = selectedStudent {
                ProgressReportView(
                    student: student,
                    report: progressReport,
                    isPresented: $showingProgressReport
                )
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2.bold())
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct SchoolsListView: View {
    let schools: [String]
    @Binding var selectedSchool: String?
    let onAddSchool: () -> Void
    let onRemoveSchool: (String) -> Void
    
    var body: some View {
        List {
            ForEach(schools, id: \.self) { school in
                HStack {
                    Button(action: { selectedSchool = school }) {
                        HStack {
                            Text(school)
                                .foregroundStyle(selectedSchool == school ? .blue : .primary)
                            Spacer()
                            if selectedSchool == school {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        onRemoveSchool(school)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if schools.isEmpty {
                ContentUnavailableView {
                    Label("No Schools", systemImage: "building.2")
                } description: {
                    Text("Add schools to your district")
                } actions: {
                    Button(action: onAddSchool) {
                        Text("Add School")
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onAddSchool) {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

struct StudentListView: View {
    let students: [User]
    let onSelectStudent: (User) -> Void
    
    var body: some View {
        List {
            ForEach(students) { student in
                Button(action: { onSelectStudent(student) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(student.name)
                            .font(.headline)
                        
                        HStack {
                            Text("Grade \(student.grade)")
                            Text("•")
                            Text(student.school)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        if !student.careerGoal.isEmpty {
                            Text(student.careerGoal)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if students.isEmpty {
                ContentUnavailableView {
                    Label("No Students", systemImage: "person.3")
                } description: {
                    Text("No students found in the selected school")
                }
            }
        }
    }
}

struct AnalyticsView: View {
    @ObservedObject var viewModel: AdminViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Career Goals Distribution
                ChartCard(title: "Career Goals Distribution") {
                    let goals = Dictionary(grouping: viewModel.districtStudents, by: { $0.careerGoal })
                        .filter { !$0.key.isEmpty }
                        .map { ($0.key, $0.value.count) }
                        .sorted { $0.1 > $1.1 }
                    
                    Chart(goals.prefix(5), id: \.0) { goal in
                        BarMark(
                            x: .value("Count", goal.1),
                            y: .value("Career", goal.0)
                        )
                        .foregroundStyle(Color.blue.gradient)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 150)
                }
                
                // Grade Level Distribution
                ChartCard(title: "Grade Level Distribution") {
                    let grades = Dictionary(grouping: viewModel.districtStudents, by: { $0.grade })
                        .map { ($0.key, $0.value.count) }
                        .sorted { $0.0 < $1.0 }
                    
                    Chart(grades, id: \.0) { grade in
                        BarMark(
                            x: .value("Grade", "Grade \(grade.0)"),
                            y: .value("Count", grade.1)
                        )
                        .foregroundStyle(Color.purple.gradient)
                    }
                    .frame(height: 150)
                }
                
                // School Distribution
                ChartCard(title: "Students per School") {
                    let schools = Dictionary(grouping: viewModel.districtStudents, by: { $0.school })
                        .filter { !$0.key.isEmpty }
                        .map { ($0.key, $0.value.count) }
                        .sorted { $0.1 > $1.1 }
                    
                    Chart(schools, id: \.0) { school in
                        SectorMark(
                            angle: .value("Students", school.1)
                        )
                        .foregroundStyle(by: .value("School", school.0))
                    }
                    .frame(height: 200)
                }
            }
            .padding()
        }
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

struct AddSchoolSheet: View {
    @Binding var isPresented: Bool
    @Binding var schoolName: String
    let onAdd: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("School Name", text: $schoolName)
                }
            }
            .navigationTitle("Add School")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd()
                    }
                    .disabled(schoolName.isEmpty)
                }
            }
        }
    }
}

struct ProgressReportView: View {
    let student: User
    let report: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(report)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("\(student.name)'s Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    AdminDashboardView()
} 