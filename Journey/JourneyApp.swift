//
//  JourneyApp.swift
//  Journey
//
//  Created by Yinka  Facus  on 3/20/25.
//

import SwiftUI
import FirebaseCore

@main
struct JourneyApp: App {
    @StateObject private var viewModel = UserViewModel()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            if viewModel.currentUser != nil {
                NavigationView {
                    MainTabView()
                }
                .environmentObject(viewModel)
            } else {
                AuthenticationView()
                    .environmentObject(viewModel)
            }
        }
    }
}
