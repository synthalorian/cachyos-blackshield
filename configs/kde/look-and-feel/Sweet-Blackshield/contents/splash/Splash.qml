/*
 *   Blackshield Mercenary — Plasma splash screen
 *   Dark steel + blood-red cross potent — Caerleon after dark.
 */

import QtQuick

Image {
    id: root
    source: "images/splash.png"

    property int stage

    onStageChanged: {
        if (stage == 1) {
            opacity = 0
            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
            opacity = 1
        }
    }

    fillMode: Image.PreserveAspectCrop
}
