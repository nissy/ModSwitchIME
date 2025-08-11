import SwiftUI

struct PrivacyNoticeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy & Security Notice")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                PrivacyPoint(
                    icon: "🔒",
                    title: "Local Processing Only",
                    description: "All IME switching happens locally. No data sent to external servers."
                )
                
                PrivacyPoint(
                    icon: "⌨️",
                    title: "Key Detection Only",
                    description: """Detects key presses to distinguish shortcuts from single modifier keys. 
No text content captured."""
                )
                
                PrivacyPoint(
                    icon: "🚫",
                    title: "No Data Collection",
                    description: "Your keystrokes, text, or personal data are never stored, logged, or transmitted."
                )
                
                PrivacyPoint(
                    icon: "🔧",
                    title: "Open Source",
                    description: "Source code is publicly available for security review and transparency."
                )
                
                PrivacyPoint(
                    icon: "⚙️",
                    title: "Revocable Access",
                    description: "Accessibility permission can be revoked anytime in System Settings."
                )
            }
            
            Text("Required Permission:")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            Text("Accessibility access detects modifier keys pressed alone to enable IME switching.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct PrivacyPoint: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(icon)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

#Preview {
    PrivacyNoticeView()
        .frame(width: 350)
}
