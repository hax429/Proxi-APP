//
//  SideBarMenuView.swift
//  Proxi
//
//  Created by Gabriel Wang on 7/20/25.
//

import Foundation
import SwiftUI

struct SidebarMenuView: View {
    @Binding var selectedTab: Int
    @Binding var isSidebarOpen: Bool
    
    let menuItems = [
        SidebarMenuItem(title: "Home", icon: "house", tag: 0),
        SidebarMenuItem(title: "Compass", icon: "location", tag: 1),
        SidebarMenuItem(title: "Friends", icon: "person.3", tag: 2),
        SidebarMenuItem(title: "Discover", icon: "magnifyingglass", tag: 3),
        SidebarMenuItem(title: "Settings", icon: "gearshape", tag: 4)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image("Logo text")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 30)
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isSidebarOpen = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 40)
            
            // Menu Items
            VStack(alignment: .leading, spacing: 0) {
                ForEach(menuItems, id: \.tag) { item in
                    Button(action: {
                        selectedTab = item.tag
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSidebarOpen = false
                        }
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: item.icon)
                                .foregroundColor(selectedTab == item.tag ? .blue : .white)
                                .font(.title2)
                                .frame(width: 24)
                            
                            Text(item.title)
                                .foregroundColor(selectedTab == item.tag ? .blue : .white)
                                .font(.title3)
                                .fontWeight(selectedTab == item.tag ? .semibold : .regular)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            selectedTab == item.tag ?
                            Color.blue.opacity(0.1) : Color.clear
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.95))
        .ignoresSafeArea()
    }
}


struct SidebarMenuItem {
    let title: String
    let icon: String
    let tag: Int
}


