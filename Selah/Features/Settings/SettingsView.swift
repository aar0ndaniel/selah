import SwiftUI
import SwiftData
import PhotosUI
import UserNotifications
import UniformTypeIdentifiers

/// Settings and profile, opened from the Today toolbar.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        NavigationStack {
            Group {
                if let profile = profiles.first {
                    SettingsForm(profile: profile)
                } else {
                    // Exactly one UserProfile is created lazily.
                    Color.clear.onAppear {
                        ProfileStore.ensure(profiles, in: modelContext)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Verse text at the user's chosen size; keeps scaling with Dynamic Type.
struct ScaledVerseText: View {
    let text: String
    let points: Double
    @ScaledMetric(relativeTo: .body) private var unit: CGFloat = 1

    var body: some View {
        Text(text)
            .font(.system(size: CGFloat(points) * unit, design: .serif))
    }
}

private struct SettingsForm: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    /// Minutes after midnight. New books and new meeting days start from these (see `ReminderDefaults`).
    @AppStorage(ReminderDefaults.readingKey) private var defaultReadingMinutes = ReminderDefaults.fallbackReadingMinutes
    @AppStorage(ReminderDefaults.serviceKey) private var defaultServiceReminderMinutes = ReminderDefaults.fallbackServiceMinutes

    @AppStorage(StreakKind.storageKey) private var todayStreakKind = StreakKind.study.rawValue

    @State private var photoItem: PhotosPickerItem?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showReset = false
    @State private var isBackingUp = false
    @State private var shareItem: ShareItem?
    @State private var showImporter = false
    @State private var pendingBackup: Backup?
    @State private var showRestoreConfirm = false
    @State private var noticeTitle = ""
    @State private var noticeMessage = ""
    @State private var showNotice = false
    /// Good news (a restore worked) shows inline in Data; only failures use an alert.
    @State private var statusMessage: String?

    private static let reminderOptions = [0, 15, 30, 60, 120]

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, build != "1" { return "\(version) (\(build))" }
        return version
    }

    var body: some View {
        Form {
            profileSection
            meetingSection
            quietTimeSection
            reminderSection
            todaySection
            bibleSection
            appearanceSection
            dataSection
            aboutSection
        }
        .task { notificationStatus = await NotificationAccess.status() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { notificationStatus = await NotificationAccess.status() }
            }
        }
        .task(id: photoItem) {
            guard let item = photoItem else { return }
            if let data = try? await item.loadTransferable(type: Data.self),
               let small = ProfileStore.avatarData(from: data) {
                profile.photoData = small
            }
            photoItem = nil
        }
        .confirmationDialog(
            "Delete all data?",
            isPresented: $showReset,
            titleVisibility: .visible
        ) {
            Button("Delete everything", role: .destructive, action: resetAll)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your books, entries, services, notes and meeting days will be deleted from this iPhone. This cannot be undone.")
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .confirmationDialog(
            "Replace all data with this backup?",
            isPresented: $showRestoreConfirm,
            titleVisibility: .visible
        ) {
            Button("Replace everything", role: .destructive, action: restorePending)
            Button("Cancel", role: .cancel) { pendingBackup = nil }
        } message: {
            Text(restoreMessage)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: item.items)
                .presentationDetents([.medium, .large])
        }
        .sensoryFeedback(.success, trigger: statusMessage) { _, new in new != nil }
        .alert(noticeTitle, isPresented: $showNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(noticeMessage)
        }
    }

    // MARK: Profile

    private var profileSection: some View {
        Section("Profile") {
            HStack(spacing: Theme.Spacing.m) {
                AvatarView(photoData: profile.photoData, size: 64)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text(profile.photoData == nil ? "Add photo" : "Change photo")
                            .frame(minHeight: 44, alignment: .leading)
                    }
                    if profile.photoData != nil {
                        Button("Remove photo", role: .destructive) {
                            profile.photoData = nil
                        }
                        .frame(minHeight: 44, alignment: .leading)
                    }
                }
            }
            TextField("Name", text: $profile.name)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
            TextField("Congregation", text: $profile.congregation)
                .textInputAutocapitalization(.words)
        }
    }

    // MARK: Meeting days

    private var meetingSection: some View {
        Section {
            NavigationLink {
                MeetingDaysView()
            } label: {
                TileRow(title: "Meeting days", icon: .calendarBlank, tone: .brand, showsChevron: true)
            }
            .navigationLinkIndicatorVisibility(.hidden)
        } footer: {
            Text("The days your congregation meets. Today shows the next one.")
        }
    }

    // MARK: Quiet time

    private var quietTimeSection: some View {
        Section {
            NavigationLink {
                QuietTimeSetupView()
            } label: {
                TileRow(title: "Quiet time", icon: .moon, tone: .graphite, showsChevron: true)
            }
            .navigationLinkIndicatorVisibility(.hidden)
        } footer: {
            Text("Silence your phone and hide social apps while you study or at services, using a Focus.")
        }
    }

    // MARK: Reminders

    private var readingTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: defaultReadingMinutes / 60,
                    minute: defaultReadingMinutes % 60,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: { newValue in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                defaultReadingMinutes = (parts.hour ?? 7) * 60 + (parts.minute ?? 0)
                NotificationScheduler.shared.reschedule(context: modelContext)
            }
        )
    }

    private var serviceReminderOptions: [Int] {
        var options = Self.reminderOptions
        if !options.contains(defaultServiceReminderMinutes) {
            options.append(defaultServiceReminderMinutes)
            options.sort()
        }
        return options
    }

    private func minutesText(_ minutes: Int) -> String {
        switch minutes {
        case 0: return "No reminder"
        case 60: return "1 hour before"
        case 120: return "2 hours before"
        default: return "\(minutes) minutes before"
        }
    }

    private var reminderSection: some View {
        Section {
            DatePicker(selection: readingTimeBinding, displayedComponents: .hourAndMinute) {
                TileLabel(title: "Reading time", icon: .clock, tone: .sage)
            }
            .frame(minHeight: 44)
            Picker(selection: $defaultServiceReminderMinutes) {
                ForEach(serviceReminderOptions, id: \.self) { minutes in
                    Text(minutesText(minutes)).tag(minutes)
                }
            } label: {
                TileLabel(title: "Before a service", icon: .bellRinging, tone: .coral)
            }
            .frame(minHeight: 44)
            .onChange(of: defaultServiceReminderMinutes) { _, _ in
                NotificationScheduler.shared.reschedule(context: modelContext)
            }
            TileRow(
                title: "Notifications",
                icon: .bell,
                tone: .coral,
                value: NotificationAccess.statusText(notificationStatus)
            )
            if notificationStatus == .notDetermined {
                Button {
                    Task {
                        _ = await NotificationAccess.request()
                        notificationStatus = await NotificationAccess.status()
                        NotificationScheduler.shared.reschedule(context: modelContext)
                    }
                } label: {
                    TileRow(title: "Turn on reminders", icon: .bellRinging, tone: .brand)
                }
            }
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            } label: {
                TileRow(title: "Open Settings", icon: .arrowSquareOut, tone: .graphite)
            }
        } header: {
            Text("Reminders")
        } footer: {
            Text("These times are used for new books and meeting days. You can change each one separately.")
        }
    }

    // MARK: Today

    private var todaySection: some View {
        Section {
            Picker(selection: $todayStreakKind) {
                ForEach(StreakKind.allCases, id: \.rawValue) { kind in
                    Text(kind.title).tag(kind.rawValue)
                }
            } label: {
                TileLabel(title: "Streak on Today", icon: .flame, tone: .coral)
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
        } header: {
            Text("Today")
        } footer: {
            Text("Choose which streak shows on Today.")
        }
    }

    // MARK: Bible

    private var textSizeBinding: Binding<VerseTextSize> {
        Binding(
            get: { VerseTextSize.nearest(to: profile.textSize) },
            set: { profile.textSize = $0.rawValue }
        )
    }

    private var bibleSection: some View {
        Section {
            Picker(selection: $profile.translation) {
                ForEach(Translation.allCases, id: \.self) { translation in
                    Text("\(translation.fullName) (\(translation.shortName))").tag(translation)
                }
            } label: {
                TileLabel(title: "Translation", icon: .book, tone: .mint)
            }
            .frame(minHeight: 44)
            Picker(selection: textSizeBinding) {
                ForEach(VerseTextSize.allCases, id: \.self) { size in
                    Text(size.title).tag(size)
                }
            } label: {
                TileLabel(title: "Verse text size", icon: .textH, tone: .rose)
            }
            .frame(minHeight: 44)
            ScaledVerseText(text: "The Lord is my shepherd; I shall not want.", points: profile.textSize)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Preview: The Lord is my shepherd; I shall not want.")
        } header: {
            Text("Bible")
        } footer: {
            Text("New verses use this translation. Verses you already saved keep the translation they were added in.")
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker(selection: $profile.appearance) {
                appearanceOptions
            } label: {
                TileLabel(title: "Appearance", icon: .palette, tone: .teal)
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            .sensoryFeedback(.selection, trigger: profile.appearance)
        }
    }

    @ViewBuilder
    private var appearanceOptions: some View {
        ForEach(Appearance.allCases, id: \.self) { appearance in
            Text(appearance.title).tag(appearance)
        }
    }

    // MARK: Data

    private var dataSection: some View {
        Section {
            NavigationLink {
                MonthlySummaryScreen()
            } label: {
                TileRow(title: "Export a month", icon: .export, tone: .brand, showsChevron: true)
            }
            .navigationLinkIndicatorVisibility(.hidden)
            Button(action: backUp) {
                HStack {
                    TileRow(
                        title: isBackingUp ? "Preparing backup…" : "Back up",
                        icon: .cloudArrowUp,
                        tone: .sage
                    )
                    if isBackingUp {
                        ProgressView()
                    }
                }
            }
            .disabled(isBackingUp)
            Button {
                showImporter = true
            } label: {
                TileRow(title: "Restore", icon: .cloudArrowDown, tone: .mint)
            }
            Button(role: .destructive) {
                showReset = true
            } label: {
                TileRow(title: "Delete all data", icon: .trash, destructive: true)
            }
            if let statusMessage {
                TileRow(title: statusMessage, icon: .checkCircle, tone: .sage)
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Everything stays on this iPhone. Selah has no account and no server. Back up before you delete the app or change Apple ID, because deleting the app deletes its data.")
        }
    }

    private var restoreMessage: String {
        guard let backup = pendingBackup else { return "" }
        let counts = RestoreCounts(
            books: backup.plans.count,
            entries: backup.plans.reduce(0) { $0 + $1.entries.count },
            services: backup.services.count,
            notes: backup.personalNotes.count,
            meetingDays: backup.meetingDays.count
        )
        let date = backup.exportedAt.formatted(date: .abbreviated, time: .omitted)
        return "Backup from \(date): \(counts.summary). Everything on this iPhone is replaced. This cannot be undone."
    }

    private func notice(_ title: String, _ message: String) {
        noticeTitle = title
        noticeMessage = message
        showNotice = true
    }

    private func backUp() {
        isBackingUp = true
        Task { @MainActor in
            await Task.yield()
            do {
                let url = try BackupService.writeBackupFile(from: modelContext)
                shareItem = ShareItem(items: [url])
            } catch {
                notice("Couldn't back up", "Selah couldn't make the backup file. Please try again.")
            }
            isBackingUp = false
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure:
            notice("Couldn't restore", BackupError.cannotRead.localizedDescription)
        case .success(let url):
            do {
                pendingBackup = try BackupService.readBackup(from: url)
                showRestoreConfirm = true
            } catch {
                notice("Couldn't restore", error.localizedDescription)
            }
        }
    }

    private func restorePending() {
        guard let backup = pendingBackup else { return }
        pendingBackup = nil
        do {
            let counts = try BackupService.restore(backup, into: modelContext)
            NotificationScheduler.shared.reschedule(context: modelContext)
            let message = "Backup restored: \(counts.summary)."
            statusMessage = message
            AccessibilityNotification.Announcement(message).post()
        } catch {
            notice("Couldn't restore", error.localizedDescription)
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section {
            TileRow(title: "Version", icon: .info, tone: .graphite, value: versionText)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Bible translations")
                    .font(.subheadline.weight(.semibold))
                Text("King James Version (KJV): public domain.")
                Text("American Standard Version (ASV, 1901): public domain.")
                Text("World English Bible (WEB): public domain, from eBible.org. \"World English Bible\" is a trademark of eBible.org.")
                Text("Berean Standard Bible (BSB): public domain, released by Berean Bible.")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.vertical, Theme.Spacing.xxs)
        } header: {
            Text("About")
        }
    }

    // MARK: Reset

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        let items = (try? modelContext.fetch(FetchDescriptor<T>())) ?? []
        for item in items {
            modelContext.delete(item)
        }
    }

    private func resetAll() {
        statusMessage = nil
        deleteAll(ReadingPlan.self)
        deleteAll(StudyEntry.self)
        deleteAll(Service.self)
        deleteAll(PersonalNote.self)
        deleteAll(MeetingDay.self)
        deleteAll(ReadingReminder.self)
        deleteAll(VerseRef.self)
        deleteAll(NoteComment.self)
        deleteAll(Song.self)

        // Keep the profile (and onboarded) so Selah opens straight to a clean Today.
        profile.name = ""
        profile.photoData = nil
        profile.congregation = ""
        profile.translation = .kjv
        profile.textSize = VerseTextSize.standard.rawValue
        profile.appearance = .system
        defaultReadingMinutes = 7 * 60
        defaultServiceReminderMinutes = 60

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        try? modelContext.save()
        NotificationScheduler.shared.reschedule(context: modelContext)
    }
}

/// Opened from Settings > Data > Export a month.
private struct MonthlySummaryScreen: View {
    @Query(sort: \Service.date) private var services: [Service]

    var body: some View {
        ScrollView {
            MonthlySummaryView(services: services)
                .padding(.bottom, Theme.Spacing.l)
        }
        .background { AppBackground() }
        .navigationTitle("Export a month")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}
