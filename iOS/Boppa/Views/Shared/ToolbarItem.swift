import SwiftUI

extension ToolbarItem {
    @ToolbarContentBuilder
    func sharedBackgroundVisibilityIfAvailable(_ visibility: Visibility) -> some ToolbarContent {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            sharedBackgroundVisibility(visibility)
        } else {
            self
        }
        #else
        self
        #endif
    }
}
