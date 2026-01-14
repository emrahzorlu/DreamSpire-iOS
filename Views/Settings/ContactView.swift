//
//  ContactView.swift
//  DreamSpire
//
//  Contact support form
//

import SwiftUI
import MessageUI

struct ContactView: View {
    @Environment(\.dismiss) var dismiss
    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var selectedCategory: ContactCategory = .general
    @State private var showingMailComposer = false
    @State private var canSendMail = MFMailComposeViewController.canSendMail()

    enum ContactCategory: String, CaseIterable {
        case general
        case technical
        case billing
        case feedback
        case other

        var displayName: String {
            switch self {
            case .general: return "contact_category_general".localized
            case .technical: return "contact_category_technical".localized
            case .billing: return "contact_category_billing".localized
            case .feedback: return "contact_category_feedback".localized
            case .other: return "contact_category_other".localized
            }
        }

        var icon: String {
            switch self {
            case .general: return "questionmark.circle.fill"
            case .technical: return "wrench.and.screwdriver.fill"
            case .billing: return "creditcard.fill"
            case .feedback: return "star.bubble.fill"
            case .other: return "ellipsis.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient.dwBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Info Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("contact_title".localized)
                                        .font(.headline)
                                        .foregroundColor(.white)

                                    Text("contact_subtitle".localized)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }

                            Divider()
                                .background(Color.white.opacity(0.3))

                            VStack(alignment: .leading, spacing: 8) {
                                ContactInfoRow(icon: "envelope", text: Constants.App.supportEmail)
                                ContactInfoRow(icon: "clock", text: "contact_response_time".localized)
                            }
                        }
                        .padding()
                        .background(
                            Color.white.opacity(0.15)
                                .overlay(Color.white.opacity(0.05))
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .padding(.horizontal)

                        // Category Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("contact_select_topic".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(ContactCategory.allCases, id: \.self) { category in
                                        CategoryChip(
                                            category: category,
                                            isSelected: selectedCategory == category,
                                            onTap: { selectedCategory = category }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Form
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("contact_subject".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white)

                                TextField("contact_subject_placeholder".localized, text: $subject)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .submitLabel(.next)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("contact_message".localized)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.white)

                                TextEditor(text: $message)
                                    .frame(height: 150)
                                    .padding(8)
                                    .background(Color.white)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            }

                            Button(action: sendEmail) {
                                HStack {
                                    Image(systemName: "paperplane.fill")
                                    Text("contact_send".localized)
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(canFormSubmit ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(!canFormSubmit)
                        }
                        .padding()
                        .background(
                            Color.white.opacity(0.15)
                                .overlay(Color.white.opacity(0.05))
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("contact_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.9))
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .sheet(isPresented: $showingMailComposer) {
                MailView(
                    recipient: Constants.App.supportEmail,
                    subject: "[\(selectedCategory.displayName)] \(subject)",
                    body: buildEmailBody(),
                    onResult: { result in
                        if case .success(let mailResult) = result {
                            if mailResult == .sent {
                                // Email sent successfully, dismiss the contact view
                                dismiss()
                            }
                        }
                    }
                )
            }
        }
    }

    private func buildEmailBody() -> String {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.5.1"
        return """
        \(message)

        ---
        Cihaz: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        \(String(format: "contact_app_version".localized, appVersion))
        """
    }

    private var canFormSubmit: Bool {
        !subject.isEmpty && !message.isEmpty && message.count >= 10
    }

    private func sendEmail() {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.5.1"
        let emailBody = """
        Kategori: \(selectedCategory.displayName)

        \(message)

        ---
        Cihaz: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        \(String(format: "contact_app_version".localized, appVersion))
        """

        if canSendMail {
            // Use Mail Composer
            showingMailComposer = true
        } else {
            // Fallback to mailto URL
            let recipient = Constants.App.supportEmail
            let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let encodedBody = emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

            if let url = URL(string: "mailto:\(recipient)?subject=\(encodedSubject)&body=\(encodedBody)") {
                UIApplication.shared.open(url)
                dismiss()
            }
        }
    }
}

struct ContactInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct CategoryChip: View {
    let category: ContactView.ContactCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.caption)

                Text(category.displayName)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue : Color.white.opacity(0.15))
            .foregroundColor(.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(isSelected ? 0.5 : 0.2), lineWidth: 1)
            )
        }
    }
}
