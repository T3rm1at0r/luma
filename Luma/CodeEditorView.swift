import LumaCore
import SwiftUI
import SwiftyMonaco

struct CodeEditorView: View {
    @Binding var text: String
    let profile: EditorProfile
    var introspector: MonacoIntrospector? = nil
    let engine: Engine

    var body: some View {
        let monacoProfile = MonacoEditorProfile(from: profile)
        let snapshot = engine.editorFSSnapshot.map { MonacoFSSnapshot(from: $0) }

        var editor = SwiftyMonaco(text: $text, profile: monacoProfile)
            .fsSnapshot(snapshot)

        if let introspector {
            editor = editor.introspector(introspector)
        }

        return editor.task {
            await engine.rebuildEditorFSSnapshotIfNeeded()
        }
    }
}
