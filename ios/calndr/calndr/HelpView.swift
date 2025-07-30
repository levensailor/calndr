import SwiftUI

struct HelpView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HelpSectionView(
                        title: "Calendar & Navigation",
                        items: [
                            HelpItem(
                                icon: "calendar.circle.fill",
                                title: "Navigating Views",
                                content: "Calndr provides several calendar layouts to fit your needs. Swipe horizontally (left or right) to fluidly switch between Year, Month, Week, 3-Day, and the focused single Day view.\n\nTo travel through time, just swipe vertically (up or down). This intuitive gesture allows you to advance to the next period or go back to a previous one."
                            ),
                            HelpItem(
                                icon: "chart.pie.fill",
                                title: "Custody Stats",
                                content: "Get at-a-glance insights into your custody arrangement. The footer of the calendar dynamically shows the custody percentage for each parent, calculated based on the current view (Month, Year, etc.).\n\nYou can also see the current 'custody streak,' which is the number of consecutive days the child has been with each parent."
                            )
                        ]
                    )

                    HelpSectionView(
                        title: "Core Features",
                        items: [
                            HelpItem(
                                icon: "person.2.circle.fill",
                                title: "Managing Custody",
                                content: "To propose a change in the custody schedule, simply press and hold on a parent's name on any given day. This action will trigger a request, and the other parent will instantly receive a notification to either approve or deny the proposed change, ensuring both parties are always in sync."
                            ),
                            HelpItem(
                                icon: "arrow.triangle.swap",
                                title: "Handoffs",
                                content: "The Handoffs screen, accessible from the main toolbar, visualizes the transfer points between parents. You can easily adjust the handoff day by sliding the markers left or right on the timeline. For more specific arrangements, tap directly on a handoff circle to edit the exact time and location of the exchange."
                            ),
                            HelpItem(
                                icon: "note.text.badge.plus",
                                title: "Reminders & Notes",
                                content: "Stay organized by adding shared notes and reminders. When in the Week, 3-Day, or Day views, tap the note icon to create an event. You can add a description and set an alert, which will send a timely push notification to both parents. It's perfect for coordinating appointments, school events, or any shared responsibilities."
                            )
                        ]
                    )
                    
                    HelpSectionView(
                        title: "Family & Childcare",
                        items: [
                            HelpItem(
                                icon: "house.fill",
                                title: "Family, Sitters & Daycare",
                                content: "The app helps you manage your entire support network:\n\n• **Family:** Keep contact information for co-parents, children, and other relatives in one place.\n\n• **Sitters:** Manage your babysitters' details, including contact info, pay rates, and a log of past care times. You can even use our service to find new, trusted sitters in your area.\n\n• **Daycare:** Store important information about your daycare facility. For added convenience, you can provide the daycare's online calendar URL, and the app will automatically parse it to show you days the facility is closed."
                            )
                        ]
                    )

                    HelpSectionView(
                        title: "Settings",
                        items: [
                            HelpItem(
                                icon: "gearshape.fill",
                                title: "Defaults & Preferences",
                                content: "Customize the app to work for you:\n\n• **Schedules:** Define default custody schedules and standard handoff times to save you from entering recurring details manually.\n\n• **Preferences:** Tailor your experience by enabling features like editing past custody days, displaying a weather forecast, or showing school events on your calendar.\n\n• **Accounts:** Manage your subscription, linked co-parent accounts, and other profile settings."
                            )
                        ]
                    )
                }
                .padding()
            }
            .scrollTargetBehavior(CustomVerticalPagingBehavior())
            .background(themeManager.currentTheme.mainBackgroundColorSwiftUI.ignoresSafeArea())
            .navigationTitle("Help & Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                }
            }
        }
        .themeNavigationBar(themeManager: themeManager)
        .accentColor(themeManager.currentTheme.iconActiveColor.color)
    }
}


// MARK: - Subviews

private struct HelpItem {
    let id = UUID()
    let icon: String
    let title: String
    let content: String
}

private struct HelpSectionView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let items: [HelpItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.bold())
                .foregroundColor(themeManager.currentTheme.textColorSwiftUI.opacity(0.8))
                .padding(.horizontal)

            ForEach(items, id: \.id) { item in
                DisclosureGroup {
                    Text(item.content)
                        .padding()
                        .font(.body)
                        .foregroundColor(themeManager.currentTheme.textColorSwiftUI)
                } label: {
                    HelpLabel(icon: item.icon, title: item.title, color: themeManager.currentTheme.iconColorSwiftUI)
                }
                .padding()
                .background(themeManager.currentTheme.secondaryBackgroundColorSwiftUI)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

struct HelpLabel: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            Text(title)
                .font(.headline)
        }
    }
}

// MARK: - Previews

struct HelpView_Previews: PreviewProvider {
    static var previews: some View {
        HelpView()
            .environmentObject(ThemeManager())
    }
}