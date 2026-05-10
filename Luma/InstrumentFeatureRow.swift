import LumaCore
import SwiftUI

struct InstrumentFeatureRow: View {
    let feature: CustomInstrumentDef.Feature
    @Binding var state: FeatureState

    var body: some View {
        if feature.optional {
            optionalRow
        } else {
            requiredRow
        }
    }

    @ViewBuilder
    private var optionalRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(feature.name, isOn: enabledBinding)
                .platformCheckboxToggleStyle()
            if case .boolean = feature.schema {
                EmptyView()
            } else {
                FeatureValueEditor(schema: feature.schema, value: valueBinding)
                    .disabled(!state.enabled)
                    .opacity(state.enabled ? 1 : 0.4)
                    .padding(.leading, 20)
            }
        }
    }

    @ViewBuilder
    private var requiredRow: some View {
        if case .boolean = feature.schema {
            Toggle(feature.name, isOn: requiredBoolBinding)
                .platformCheckboxToggleStyle()
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(feature.name).font(.subheadline)
                FeatureValueEditor(schema: feature.schema, value: valueBinding)
                    .padding(.leading, 20)
            }
        }
    }

    private var requiredBoolBinding: Binding<Bool> {
        Binding(
            get: {
                if case .boolean(let b) = state.value { return b }
                if case .boolean(let b) = feature.schema.defaultValue { return b }
                return false
            },
            set: { newValue in
                state = FeatureState(enabled: state.enabled, value: .boolean(newValue))
            }
        )
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { state.enabled },
            set: { state = FeatureState(enabled: $0, value: state.value) }
        )
    }

    private var valueBinding: Binding<FeatureValue> {
        Binding(
            get: { state.value },
            set: { state = FeatureState(enabled: state.enabled, value: $0) }
        )
    }
}
