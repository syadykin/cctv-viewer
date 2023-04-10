import QtQml 2.12
import QtQuick 2.12
import QtQuick.Window 2.12
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.12
import Qt.labs.settings 1.0
import CCTV_Viewer.Core 1.0
import CCTV_Viewer.Models 1.0
import CCTV_Viewer.Utils 1.0

ApplicationWindow {
    id: rootWindow

    title: qsTr("CCTV Viewer")

    visible: true
    visibility: Context.config.fullScreen ? Window.FullScreen : Window.Windowed
    width: rootWindowSettings.width
    height: rootWindowSettings.height

    // Right-to-left User Interfaces support
    LayoutMirroring.enabled: Qt.application.layoutDirection == Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    Binding {
        target: rootWindowSettings
        property: "width"
        value: rootWindow.width
        when: !Context.config.fullScreen
    }

    Binding {
        target: rootWindowSettings
        property: "height"
        value: rootWindow.height
        when: !Context.config.fullScreen
    }

    Settings {
        id: generalSettings

        fileName: Context.config.fileName
        property bool singleApplication: true
    }

    Settings {
        id: rootWindowSettings

        fileName: Context.config.fileName
        category: "RootWindow"
        property int width: 1280 + 48 /*SideBar compact width*/
        property int height: 720
        property bool fullScreen
        property bool sidebarAutoCollapse: true

        Component.onCompleted: {
            // Do not initialize "fullScreen" if option "-f" is set
            if (!Context.config.fullScreen) {
                Context.config.fullScreen = rootWindowSettings.fullScreen;
            }

            rootWindowSettings.fullScreen = Qt.binding(function() { return Context.config.fullScreen; });
        }
    }

    Settings {
        id: layoutsCollectionSettings

        fileName: Context.config.fileName
        category: "ViewportsLayoutsCollection"

        property int currentIndex
        property string models
        // TODO: Move to "View"
        property bool presetIndicator: true
        // TODO: Move to "Viewport"
        property string defaultAVFormatOptions: JSON.stringify({
            "analyzeduration": 0, // 0 µs
            "probesize": 500000 // 500 KB
        })

        function toJSValue(key) {
            var obj = {};

            try {
                obj = JSON.parse(layoutsCollectionSettings[String(key)]);
            } catch(err) {
                Utils.log_error(qsTr("Error reading configuration!"));
            }

            return obj;
        }
    }

    Settings {
        id: viewportSettings

        fileName: Context.config.fileName
        category: "Viewport"

        property bool unmuteWhenFullScreen: false
    }

    Shortcut {
        sequence: "M"
        onActivated: {
            if (Utils.currentLayout().focusIndex >= 0) {
                var item = Utils.currentModel().get(Utils.currentLayout().focusIndex);
                var viewport = Utils.currentLayout().get(Utils.currentLayout().focusIndex);

                if (viewport.hasAudio) {
                    if (item.volume > 0) {
                        item.volume = 0;
                    } else {
                        item.volume = 1;
                    }
                }
            }
        }
    }

    Shortcut {
        sequence: "A"
        onActivated: {
            Utils.currentLayout().get(0).forceActiveFocus();
        }
    }

    // Shortcuts for the first 9 presets (Alt + 1, Alt + 2, ..., Alt + 9)
    Repeater {
        model: Context.config.kioskMode ? 0 : Math.min(stackLayout.count, 9)

        Item {
            Shortcut {
                sequence: "Alt+" + (index + 1)
                onActivated: stackLayout.currentIndex = index
            }
        }
    }
    Shortcut {
        sequence: StandardKey.FullScreen
        onActivated: Context.config.fullScreen = !Context.config.fullScreen
    }
    Shortcut {
        sequence: StandardKey.Quit
        onActivated: Qt.quit()
    }

    ViewportsLayoutsCollectionModel {
        id: layoutsCollectionModel

        // Demo group
        ViewportsLayoutModel {
            size: Qt.size(2, 2)
        }
        ViewportsLayoutModel {
            size: Qt.size(3, 3)
        }
        ViewportsLayoutModel {
            size: Qt.size(1, 1)
        }

        onCountChanged: stackLayout.currentIndex = stackLayout.currentIndex.clamp(0, layoutsCollectionModel.count - 1)
        Component.onCompleted: {
            // Demo streams
            get(0).get(0).url = "rtmp://live.a71.ru/demo/0";
            get(0).get(1).url = "rtmp://live.a71.ru/demo/1";

            layoutsCollectionModel.changed.connect(function () {
                layoutsCollectionSettings.models = JSON.stringify(toJSValue());
            });

            try {
                if (!layoutsCollectionSettings.models.isEmpty()) {
                    fromJSValue(JSON.parse(layoutsCollectionSettings.models));
                }
            } catch(err) {
                Utils.log_error(qsTr("Error reading configuration!"));
            }

            // Force initialize "currentIndex" if option "-p" is set
            var currentIndex = (Context.config.currentIndex >= 0) ? Context.config.currentIndex : layoutsCollectionSettings.currentIndex;
            stackLayout.currentIndex = currentIndex.clamp(0, layoutsCollectionModel.count - 1);
        }
    }

    Item {
        height: parent.height
        anchors.left: parent.left
        anchors.right: sideBar.left

        Rectangle {
            color: "black"
            anchors.fill: parent
        }

        StackLayout {
            id: stackLayout

            visible: false
            currentIndex: -1
            anchors.fill: parent

            onCurrentIndexChanged: layoutsCollectionSettings.currentIndex = currentIndex

            Repeater {
                id: swipeViewRepeater
                model: layoutsCollectionModel

                ViewportsLayout {
                    model: layoutModel
                    focus: true
                }
            }
        }

        PageIndicator {
            interactive: true
            visible: layoutsCollectionSettings.presetIndicator && stackLayout.count > 1
            currentIndex: stackLayout.currentIndex
            count: stackLayout.count
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter

            onCurrentIndexChanged: stackLayout.currentIndex = currentIndex
        }
    }


    Loader {
        id: sideBar

        height: parent.height
        anchors.right: parent.right

        Component.onCompleted: {
            if (!Context.config.kioskMode) {
                source = "SideBar.qml";
            }
        }
    }

    SingleApplicationDialog {
        onVisibleChanged: {
            if (!visible) {
                if (singleApplication) {
                    Qt.quit();
                } else {
                    generalSettings.singleApplication = false;
                    stackLayout.visible = true;
                }
            }
        }

        Component.onCompleted: {
            if (generalSettings.singleApplication && SingleApplication.isRunning()) {
                open();
            } else {
                stackLayout.visible = true;
            }
        }
    }

    SettingsDialog {
        id: settingsDialog
    }
}
