import SwiftUI

extension ToolbarItem {
    @ToolbarContentBuilder
    func sharedBackgroundVisibilityIfAvailable(_ visibility: Visibility) -> some ToolbarContent {
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(visibility)
        } else {
            self
        }
    }
}
