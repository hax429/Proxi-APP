//
//  ContentView.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/16/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    VStack {
                        Spacer().frame(height: 20)
                        Image(systemName: "house")
                            .renderingMode(.template)
                            .foregroundColor(selectedTab == 0 ? Color.white : Color.white.opacity(1))
                        Text("Home")
                            .foregroundColor(selectedTab == 0 ? Color.white : Color.white.opacity(1))
                    }
                }
                .tag(0)
            CompassView()
                .tabItem {
                    VStack {
                        Spacer().frame(height: 20)
                        Image(systemName: "location")
                            .renderingMode(.template)
                            .foregroundColor(selectedTab == 1 ? Color.white : Color.white.opacity(1))
                        Text("Compass")
                            .foregroundColor(selectedTab == 1 ? Color.white : Color.white.opacity(1))
                    }
                }
                .tag(1)
            FriendsView(selectedTab: $selectedTab)
                .tabItem {
                    VStack {
                        Spacer().frame(height: 20)
                        Image(systemName: "person.3")
                            .renderingMode(.template)
                            .foregroundColor(selectedTab == 2 ? Color.white : Color.white.opacity(1))
                        Text("Friends")
                            .foregroundColor(selectedTab == 2 ? Color.white : Color.white.opacity(1))
                    }
                }
                .tag(2)
            DiscoverView()
                .tabItem {
                    VStack {
                        Spacer().frame(height: 20)
                        Image(systemName: "magnifyingglass")
                            .renderingMode(.template)
                            .foregroundColor(selectedTab == 3 ? Color.white : Color.white.opacity(1))
                        Text("Discover")
                            .foregroundColor(selectedTab == 3 ? Color.white : Color.white.opacity(1))
                    }
                }
                .tag(3)
            SettingsView()
                .tabItem {
                    VStack {
                        Spacer().frame(height: 20)
                        Image(systemName: "gearshape")
                            .renderingMode(.template)
                            .foregroundColor(selectedTab == 4 ? Color.white : Color.white.opacity(1))
                        Text("Settings")
                            .foregroundColor(selectedTab == 4 ? Color.white : Color.white.opacity(1))
                    }
                }
                .tag(4)
        }
        .accentColor(.white)
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithOpaqueBackground()
            tabBarAppearance.backgroundColor = UIColor.black
            UITabBar.appearance().standardAppearance = tabBarAppearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}



