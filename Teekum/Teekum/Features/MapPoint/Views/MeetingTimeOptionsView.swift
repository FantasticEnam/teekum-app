//
//  MeetingTimeOptionsView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct MeetingTimeOptionsView: View {
    @Bindable var viewModel: MapPointViewModel

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Choose a time", isOn: $viewModel.isCustomTime)
                if viewModel.isCustomTime {
                    DatePicker("Meet at", selection: $viewModel.customTime, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                } else {
                    Picker("Meet at", selection: $viewModel.timePreset) {
                        ForEach(MeetingTimePreset.allCases) { preset in Text(preset.title).tag(preset) }
                    }
                    .pickerStyle(.inline)
                }
            }
            .navigationTitle("Meeting time")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: viewModel.cancelSetMeetingPoint) }
                ToolbarItem(placement: .confirmationAction) { Button("Set point", action: viewModel.confirmSetMeetingPoint) }
            }
        }
        .preferredColorScheme(.dark)
    }
}
