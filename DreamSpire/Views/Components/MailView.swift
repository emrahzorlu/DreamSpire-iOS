//
//  MailView.swift
//  DreamSpire
//
//  Created by Emrah Zorlu on 2025
//

import SwiftUI
import MessageUI

struct MailView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    let recipient: String
    let subject: String
    let body: String
    var onResult: ((Result<MFMailComposeResult, Error>) -> Void)? = nil

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var dismiss: DismissAction
        var onResult: ((Result<MFMailComposeResult, Error>) -> Void)?

        init(dismiss: Binding<DismissAction>, onResult: ((Result<MFMailComposeResult, Error>) -> Void)?) {
            _dismiss = dismiss
            self.onResult = onResult
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                onResult?(.failure(error))
            } else {
                onResult?(.success(result))
            }
            dismiss()
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(dismiss: .constant(dismiss), onResult: onResult)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
}
