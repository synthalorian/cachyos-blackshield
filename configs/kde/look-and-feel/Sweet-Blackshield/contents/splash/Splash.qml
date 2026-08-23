/*
 *   Blackshield Mercenary — Plasma splash screen
 *   Dark steel + blood-red cross potent — Caerleon after dark.
 */

import QtQuick

Image {
    id: root
    source: "images/splash.png"
    fillMode: Image.PreserveAspectCrop

    property int stage

    opacity: 0

    Behavior on opacity {
        NumberAnimation { duration: 400; easing.type: Easing.OutQuad }
    }

    onStageChanged: {
        if (stage == 1) {
            root.opacity = 1
        }
    }
}
