import Foundation

extension Engine {
    public func setEventStreamCollapsed(_ collapsed: Bool) {
        guard projectUIState.isEventStreamCollapsed != collapsed else { return }
        Task { @MainActor [weak self] in
            guard let self, self.projectUIState.isEventStreamCollapsed != collapsed else { return }
            self.projectUIState.isEventStreamCollapsed = collapsed
            try? self.store.save(self.projectUIState)
        }
    }

    public func setEventStreamBottomHeight(_ height: Double) {
        guard projectUIState.eventStreamBottomHeight != height else { return }
        Task { @MainActor [weak self] in
            guard let self, self.projectUIState.eventStreamBottomHeight != height else { return }
            self.projectUIState.eventStreamBottomHeight = height
            try? self.store.save(self.projectUIState)
        }
    }

    public func setCollaborationPanelVisible(_ visible: Bool) {
        guard projectUIState.isCollaborationPanelVisible != visible else { return }
        Task { @MainActor [weak self] in
            guard let self, self.projectUIState.isCollaborationPanelVisible != visible else { return }
            self.projectUIState.isCollaborationPanelVisible = visible
            try? self.store.save(self.projectUIState)
        }
    }

    public func setSelectedItemJSON(_ json: String?) {
        guard projectUIState.selectedItemJSON != json else { return }
        Task { @MainActor [weak self] in
            guard let self, self.projectUIState.selectedItemJSON != json else { return }
            self.projectUIState.selectedItemJSON = json
            try? self.store.save(self.projectUIState)
        }
    }

    public func setSessionDetailSection(sessionID: UUID, section: String?) {
        mutateSessionUIState(sessionID: sessionID) { $0.detailSection = section }
    }

    public func setLastSelectedModuleID(sessionID: UUID, moduleID: String?) {
        mutateSessionUIState(sessionID: sessionID) { $0.lastSelectedModuleID = moduleID }
    }

    public func setLastSelectedThreadID(sessionID: UUID, threadID: UInt?) {
        mutateSessionUIState(sessionID: sessionID) { $0.lastSelectedThreadID = threadID }
    }

    private func mutateSessionUIState(sessionID: UUID, _ mutate: @escaping (inout SessionUIState) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            var state = self.sessionUIStates[sessionID] ?? SessionUIState(sessionID: sessionID)
            mutate(&state)
            guard state != self.sessionUIStates[sessionID] else { return }
            self.sessionUIStates[sessionID] = state
            try? self.store.save(state)
        }
    }

    public func sessionDetailSectionRaw(forSessionID sessionID: UUID) -> String? {
        sessionUIStates[sessionID]?.detailSection
    }

    public func lastSelectedModuleID(forSessionID sessionID: UUID) -> String? {
        sessionUIStates[sessionID]?.lastSelectedModuleID
    }

    public func lastSelectedThreadID(forSessionID sessionID: UUID) -> UInt? {
        sessionUIStates[sessionID]?.lastSelectedThreadID
    }
}
