import SwiftUI

/// What was sent to the SDK, newest first.
struct ActivitySection: View {

    // MARK: - Properties

    let activity: [ActivityEntry]

    // MARK: - Body

    var body: some View {
        Section("Activity") {
            if activity.isEmpty {
                Text("Nothing yet")
                    .foregroundStyle(.secondary)
            }

            ForEach(activity) { entry in
                LabeledContent(entry.text) {
                    Text(entry.date, format: .dateTime.hour().minute().second())
                }
                .font(.footnote)
            }
        }
    }
}

#Preview("Empty") {
    Form {
        ActivitySection(activity: [])
    }
}

#Preview("With entries") {
    Form {
        ActivitySection(activity: [
            ActivityEntry(date: Date(), text: "Message captured"),
            ActivityEntry(date: Date(), text: "Consent granted: waiting events are sent"),
        ])
    }
}
