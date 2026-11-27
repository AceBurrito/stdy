// WorkoutActivityBundle.swift
// WorkoutActivity (Widget Extension target ONLY)
//
// WidgetBundle containing both the Live Activity widget and the
// Atlas home screen widget. Both run in the same extension process.

import WidgetKit
import SwiftUI

@main
struct WorkoutActivityBundle: WidgetBundle {
    var body: some Widget {
        WorkoutActivityLiveActivity()
        AtlasWidget()
    }
}
