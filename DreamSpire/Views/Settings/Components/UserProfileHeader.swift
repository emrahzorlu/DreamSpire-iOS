//
//  UserProfileHeader.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025.
//

import SwiftUI

/// User profile header with inline name editing
struct UserProfileHeader: View {
    @ObservedObject var viewModel: ProfileViewModel
    
    @State private var isEditing = false
    @State private var editName = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                
                if viewModel.displayName.isEmpty {
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                } else {
                    Text(String(viewModel.displayName.prefix(1)).uppercased())
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Name with inline edit
                HStack(spacing: 8) {
                    if isEditing {
                        TextField("profile_name_placeholder".localized, text: $editName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isFocused)
                            .submitLabel(.done)
                            .onSubmit { saveName() }
                            .frame(maxWidth: 200)
                        
                        Button(action: saveName) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }
                    } else {
                        Text(viewModel.displayName.isEmpty ? "profile_user".localized : viewModel.displayName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button(action: {
                            editName = viewModel.displayName
                            isEditing = true
                            isFocused = true
                        }) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                
                Text(viewModel.email)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding()
        .background(
            Color.white.opacity(0.15)
                .overlay(Color.white.opacity(0.05))
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .accessibilityLabel("Profil: \(viewModel.displayName)")
    }
    
    private func saveName() {
        if !editName.isEmpty {
            viewModel.displayName = editName
            Task {
                await viewModel.updateDisplayName()
            }
        }
        isEditing = false
    }
}
