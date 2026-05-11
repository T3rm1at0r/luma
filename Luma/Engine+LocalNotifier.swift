#if os(macOS)
    import Foundation
    import LumaCore

    extension Engine {
        func attachLocalNotifier() {
            let key = ObjectIdentifier(self)
            if enginesWithLocalNotifier[key] != nil { return }
            let notifier = LocalNotifier()
            enginesWithLocalNotifier[key] = notifier

            onNotebookChanged = { [weak self] change in
                guard case let .added(entry) = change else { return }
                guard let self,
                    let authorID = entry.author?.id,
                    !self.collaboration.isSelf(authorID)
                else { return }
                notifier.notifyEntryAdded(entry, labID: self.collaboration.labID)
            }
            collaboration.onMemberAdded = { [weak self] member in
                guard let self,
                    !self.collaboration.isSelf(member.user.id)
                else { return }
                notifier.notifyMemberAdded(member, labID: self.collaboration.labID)
            }
            collaboration.onChatMessageReceived = { [weak self] message in
                guard let self, !message.isLocal else { return }
                notifier.notifyChatMessage(message, labID: self.collaboration.labID)
            }
        }
    }

    @MainActor
    private var enginesWithLocalNotifier: [ObjectIdentifier: LocalNotifier] = [:]
#endif
