import Quickshell
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens
        Wallpaper {}
    }

    Variants {
        model: Quickshell.screens
        Dashboard {}
    }

    Variants {
        model: Quickshell.screens
        Bar {}
    }

    Variants {
        model: Quickshell.screens
        Dock {}
    }

    OSD {}

    AppGrid {}

    QuickSettings {}

    Switcher {}
    
    Overview {}

    MediaPopup {}

    WindowMenu {}

    WindowRules {}

    NotificationPopups {}
}
