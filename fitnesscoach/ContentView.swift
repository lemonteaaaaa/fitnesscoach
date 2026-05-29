//
//  ContentView.swift
//  fitnesscoach
//
//  Created by Faroz Syakir on 08/05/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            FitnessDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.xyaxis.line")
                }

            MovementTrackerView()
                .tabItem {
                    Label("Tracker", systemImage: "camera.viewfinder")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
    ContentView()
    }
}
