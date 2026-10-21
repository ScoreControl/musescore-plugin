import MuseScore 3.0
// For layout
import QtQuick 2.9
// For interface
import QtQuick.Controls 2.2

MuseScore {
    id: mainWindow

    // version of plugin NOT version of MuseScore
    version: "4.0"
    // This is what users see as the description
    description: "A starter plugin for MuseScore 4"
    // Where plugins will appear
    // Plugin --> myPlug
    menuPath: "Plugins.myPlug"
    // dialog means it is a window with controls you cann interact with
    pluginType: "dialog"
    // requires an open score to be running
    requiresScore: true

    //Window width and height
    width: 350
    height: 200

    // Layout component --> stacks children vertically 
    Column {
        anchors.centerIn: parent
        // gap between al of Column's children
        spacing: 15

        Label {
            text: "Plugin executed successfully!"
        }

        Label {
            // condition ? valueIfTrue : valueIfFalse
            text: "Score: " + (curScore ? curScore.title : "No score")
        }

        Button {
            text: "Close"
            onClicked: quit()
        }
    }

    onRun: {
        console.log("Plugin executed successfully!")
        console.log("Score Title:", curScore.title)
    }
}
