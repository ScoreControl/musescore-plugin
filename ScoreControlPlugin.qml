import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.GitHub"
    description: "GitHub-style version control for MuseScore"
    version: "0.1"
    pluginType: "dock"

    width: 430
    height: 650

    property string currentScreen: "login"

    Rectangle {
        anchors.fill: parent
        color: "#f6f8fa"

        // HEADER
        Rectangle {
            width: parent.width
            height: 55
            color: "#24292f"

            Row {
                anchors.fill: parent
                anchors.leftMargin: 15
                spacing: 10

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "●"
                    color: "white"
                    font.pixelSize: 18
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "MuseScore GitHub"
                    color: "white"
                    font.pixelSize: 15
                    font.bold: true
                }
            }
        }

        // LOGIN SCREEN
        Column {
            visible: currentScreen === "login"

            anchors.centerIn: parent
            width: parent.width - 60
            spacing: 18

            Text {
                text: "◉"
                font.pixelSize: 60
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Connect Your Account"
                font.pixelSize: 22
                font.bold: true
                color: "#24292f"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Log in to GitHub to save and manage\n"
                      + "your scores with MuseScore."
                horizontalAlignment: Text.AlignHCenter
                color: "#57606a"
                font.pixelSize: 13
                width: parent.width
            }

            Button {
                text: "Log in with GitHub"

                width: parent.width
                height: 45

                onClicked: {
                    currentScreen = "createProject"
                }
            }

            Text {
                text: "Why do I need to log in?"
                color: "#0969da"
                font.pixelSize: 12
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // CREATE PROJECT SCREEN
        Column {
            visible: currentScreen === "createProject"

            anchors.fill: parent
            anchors.margins: 25
            spacing: 15

            Button {
                text: "‹  Back"
                flat: true

                onClicked: {
                    currentScreen = "login"
                }
            }

            Text {
                text: "Create a New Project"
                font.pixelSize: 22
                font.bold: true
                color: "#24292f"
            }

            Text {
                text: "You don't have a project yet.\n"
                      + "Would you like to create one for this score?"
                color: "#57606a"
                font.pixelSize: 13
            }

            Text {
                text: "Project name"
                font.bold: true
                color: "#24292f"
            }

            TextField {
                id: projectNameField

                width: parent.width
                height: 42

                text: "My First Score"
                placeholderText: "Project name"
            }

            Text {
                text: "Commit message"
                font.bold: true
                color: "#24292f"
            }

            TextField {
                id: commitMessageField

                width: parent.width
                height: 42

                text: "Initial commit from MuseScore"
                placeholderText: "Commit message"
            }

            Item {
                width: 1
                height: 20
            }

            Button {
                text: "Create Project"

                width: parent.width
                height: 45

                onClicked: {
                    currentScreen = "home"
                }
            }

            Text {
                text: "This will create a main branch and save your\n"
                      + "current score with the provided metadata."

                color: "#57606a"
                font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
            }
        }

        // HOME SCREEN
        Column {
            visible: currentScreen === "home"

            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Text {
                text: "My First Score"
                font.pixelSize: 21
                font.bold: true
                color: "#24292f"
            }

            Text {
                text: "⑂  main"
                color: "#0969da"
                font.pixelSize: 13
            }

            Rectangle {
                width: parent.width
                height: 120

                color: "white"
                border.color: "#d0d7de"
                radius: 7

                Column {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 7

                    Text {
                        text: "CURRENT COMMIT"
                        font.pixelSize: 10
                        font.bold: true
                        color: "#57606a"
                    }

                    Text {
                        text: "a1b2c3d4"
                        font.bold: true
                        color: "#24292f"
                    }

                    Text {
                        text: "\"Initial commit from MuseScore\""
                        color: "#57606a"
                        font.pixelSize: 12
                    }

                    Text {
                        text: "Today, 4:12 PM"
                        color: "#57606a"
                        font.pixelSize: 10
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 45

                color: "#dafbe1"
                radius: 6

                Text {
                    anchors.centerIn: parent
                    text: "✓  Your score is up to date."
                    color: "#1a7f37"
                    font.pixelSize: 12
                }
            }

            Button {
                text: "Create New Commit  →"

                width: parent.width
                height: 43

                onClicked: {
                    currentScreen = "commit"
                }
            }

            Button {
                text: "Switch to Older Commit  →"

                width: parent.width
                height: 43

                onClicked: {
                    currentScreen = "history"
                }
            }

            Button {
                text: "Switch to a Branch  →"

                width: parent.width
                height: 43

                onClicked: {
                    currentScreen = "branches"
                }
            }

            Button {
                text: "View Score Metadata"

                width: parent.width
                height: 40

                onClicked: {
                    currentScreen = "metadata"
                }
            }
        }

        // COMMIT SCREEN
        Column {
            visible: currentScreen === "commit"

            anchors.fill: parent
            anchors.margins: 25
            spacing: 15

            Button {
                text: "‹  Back"
                flat: true

                onClicked: {
                    currentScreen = "home"
                }
            }

            Text {
                text: "Commit Changes"
                font.pixelSize: 22
                font.bold: true
            }

            Text {
                text: "Branch: main"
                color: "#57606a"
            }

            Text {
                text: "Commit message"
                font.bold: true
            }

            TextArea {
                id: newCommitMessage

                width: parent.width
                height: 110

                placeholderText: "Describe your changes..."
            }

            Item {
                width: 1
                height: 20
            }

            Button {
                text: "Commit"

                width: parent.width
                height: 45

                onClicked: {
                    currentScreen = "home"
                }
            }
        }

        // HISTORY SCREEN
        Column {
            visible: currentScreen === "history"

            anchors.fill: parent
            anchors.margins: 20
            spacing: 10

            Button {
                text: "‹  Back"
                flat: true

                onClicked: {
                    currentScreen = "home"
                }
            }

            Text {
                text: "Select Commit"
                font.pixelSize: 22
                font.bold: true
            }

            Text {
                text: "Choose a previous version of this score."
                color: "#57606a"
                font.pixelSize: 12
            }

            Rectangle {
                width: parent.width
                height: 75

                color: "white"
                border.color: "#0969da"
                border.width: 2
                radius: 6

                Text {
                    anchors.fill: parent
                    anchors.margins: 12

                    text: "●  a1b2c3d4\n\n"
                          + "    Initial commit"
                    color: "#24292f"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                width: parent.width
                height: 75

                color: "white"
                border.color: "#d0d7de"
                radius: 6

                Text {
                    anchors.fill: parent
                    anchors.margins: 12

                    text: "○  9f8e7d6c\n\n"
                          + "    Added melody"
                    color: "#24292f"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                width: parent.width
                height: 75

                color: "white"
                border.color: "#d0d7de"
                radius: 6

                Text {
                    anchors.fill: parent
                    anchors.margins: 12

                    text: "○  3c2b1a0f\n\n"
                          + "    Fixed layout"
                    color: "#24292f"
                    font.pixelSize: 12
                }
            }

            Item {
                width: 1
                height: 20
            }

            Button {
                text: "Use This Commit"

                width: parent.width
                height: 45

                onClicked: {
                    currentScreen = "home"
                }
            }
        }

        // BRANCH SCREEN
        Column {
            visible: currentScreen === "branches"

            anchors.fill: parent
            anchors.margins: 20
            spacing: 10

            Button {
                text: "‹  Back"
                flat: true

                onClicked: {
                    currentScreen = "home"
                }
            }

            Text {
                text: "Switch Branch"
                font.pixelSize: 22
                font.bold: true
            }

            Button {
                text: "↻ Refresh"

                width: parent.width
                height: 38
            }

            Rectangle {
                width: parent.width
                height: 65

                color: "white"
                border.color: "#d0d7de"
                radius: 6

                Text {
                    anchors.fill: parent
                    anchors.margins: 12

                    text: "⑂  main\n\n"
                          + "    Latest: a1b2c3d4"
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        currentScreen = "home"
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 65

                color: "white"
                border.color: "#d0d7de"
                radius: 6

                Text {
                    anchors.fill: parent
                    anchors.margins: 12

                    text: "⑂  modified\n\n"
                          + "    Latest: 7e6d5c4b"
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        currentScreen = "home"
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 65

                color: "white"
                border.color: "#d0d7de"
                radius: 6

                Text {
                    anchors.fill: parent
                    anchors.margins: 12

                    text: "⑂  DONTUSETHISBRANCH\n\n"
                          + "    Latest: 9a8b7c6d"
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        currentScreen = "limitedAccess"
                    }
                }
            }
        }

        // LIMITED ACCESS
        Column {
            visible: currentScreen === "limitedAccess"

            anchors.fill: parent
            anchors.margins: 25
            spacing: 18

            Button {
                text: "‹  Back"
                flat: true

                onClicked: {
                    currentScreen = "branches"
                }
            }

            Rectangle {
                width: parent.width
                height: 145

                color: "#fff8c5"
                border.color: "#d4a72c"
                radius: 7

                Column {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

                    Text {
                        text: "🔒  Limited Access"
                        font.bold: true
                        font.pixelSize: 16
                    }

                    Text {
                        text: "You don't have direct access to this branch."
                        color: "#24292f"
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    Text {
                        text: "This branch requires additional\n"
                              + "historical information."
                        color: "#57606a"
                        font.pixelSize: 11
                    }
                }
            }

            Button {
                text: "Request Commit Hashes"

                width: parent.width
                height: 45

                onClicked: {
                    currentScreen = "restrictedCommits"
                }
            }
        }

        // RESTRICTED COMMITS
        Column {
            visible: currentScreen === "restrictedCommits"

            anchors.fill: parent
            anchors.margins: 20
            spacing: 10

            Button {
                text: "‹  Back"
                flat: true

                onClicked: {
                    currentScreen = "limitedAccess"
                }
            }

            Text {
                text: "Commit Hashes"
                font.pixelSize: 22
                font.bold: true
            }

            Text {
                text: "DONTUSETHISBRANCH"
                color: "#57606a"
            }

            Rectangle {
                width: parent.width
                height: 65

                color: "white"
                border.color: "#d0d7de"
                radius: 6

                Text {
                    anchors.centerIn: parent
                    text: "○  9a8b7c6d     Update"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                width: parent.width
                height: 65

                color: "white"
                border.color: "#d0d7de"
                radius: 6

                Text {
                    anchors.centerIn: parent
                    text: "○  6e5d4c3b     WIP changes"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                width: parent.width
                height: 65

                color: "white"
                border.color: "#d0d7de"
                radius: 6

                Text {
                    anchors.centerIn: parent
                    text: "○  2d1c0b9a     Experimental"
                    font.pixelSize: 12
                }
            }
        }

        // METADATA
        Column {
            visible: currentScreen === "metadata"

            anchors.fill: parent
            anchors.margins: 25
            spacing: 12

            Button {
                text: "‹  Back"
                flat: true

                onClicked: {
                    currentScreen = "home"
                }
            }

            Text {
                text: "Score Metadata"
                font.pixelSize: 22
                font.bold: true
            }

            Text {
                text: "Information stored with this score."
                color: "#57606a"
                font.pixelSize: 12
            }

            Rectangle {
                width: parent.width
                height: 55
                color: "white"
                border.color: "#d0d7de"
                radius: 5

                Text {
                    anchors.fill: parent
                    anchors.margins: 12
                    text: "Project       My First Score"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                width: parent.width
                height: 55
                color: "white"
                border.color: "#d0d7de"
                radius: 5

                Text {
                    anchors.fill: parent
                    anchors.margins: 12
                    text: "Branch        main"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                width: parent.width
                height: 55
                color: "white"
                border.color: "#d0d7de"
                radius: 5

                Text {
                    anchors.fill: parent
                    anchors.margins: 12
                    text: "Commit        a1b2c3d4"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                width: parent.width
                height: 55
                color: "white"
                border.color: "#d0d7de"
                radius: 5

                Text {
                    anchors.fill: parent
                    anchors.margins: 12
                    text: "Message       Initial commit"
                    font.pixelSize: 12
                }
            }
        }
    }
}