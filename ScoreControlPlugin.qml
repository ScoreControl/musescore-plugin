import MuseScore 3.0
import QtQuick 2.9
import QtQuick.Controls 2.2

MuseScore {
    id: mainWindow

    version: "4.1"
    description: "Local workflow prototype for ScoreControl"
    menuPath: "Plugins.ScoreControl"
    pluginType: "dialog"
    requiresScore: true
    width: 820
    height: 720

    property bool darkMode: false
    property color windowColor: darkMode ? "#151a23" : "#f3f6fb"
    property color surfaceColor: darkMode ? "#202938" : "#ffffff"
    property color fieldColor: darkMode ? "#111821" : "#ffffff"
    property color textColor: darkMode ? "#f4f7fc" : "#172033"
    property color secondaryTextColor: darkMode ? "#c3cddd" : "#44536a"
    property color borderColor: darkMode ? "#64748b" : "#8290a3"
    property color accentColor: darkMode ? "#1d5fae" : "#1459a8"
    property color accentTextColor: "#ffffff"
    property color selectedColor: darkMode ? "#24466b" : "#dcecff"
    property color alternateRowColor: darkMode ? "#273243" : "#f2f5f9"
    property color noticeColor: darkMode ? "#3b2b14" : "#fff4df"
    property color noticeTextColor: darkMode ? "#ffe0a3" : "#684000"

    property bool loggedIn: false
    property bool projectCreated: false
    property string accountEmail: ""
    property string projectName: ""
    property string currentBranch: ""
    property string currentCommitId: ""
    property string currentCommitMessage: ""
    property string selectedCommitId: ""
    property string workingBaseId: ""
    property string statusMessage: "Sign in to begin. This prototype stores data only for this plugin session."
    property int nextLocalId: 1

    ListModel {
        id: branchModel
    }

    ListModel {
        id: commitModel
    }

    function localId() {
        var id = "local-demo-" + ("000000" + nextLocalId).slice(-6)
        nextLocalId += 1
        return id
    }

    function findBranchIndex(name) {
        for (var i = 0; i < branchModel.count; ++i) {
            if (branchModel.get(i).name === name)
                return i
        }
        return -1
    }

    function findCommitIndex(id) {
        for (var i = commitModel.count - 1; i >= 0; --i) {
            if (commitModel.get(i).id === id)
                return i
        }
        return -1
    }

    function setCurrentCommit(id) {
        var index = findCommitIndex(id)
        if (index < 0)
            return false
        var commit = commitModel.get(index)
        currentCommitId = commit.id
        currentCommitMessage = commit.message
        selectedCommitId = commit.id
        return true
    }

    function writeScoreMetadata() {
        if (!curScore)
            return
        curScore.setMetaTag("ScoreControlProject", projectName)
        curScore.setMetaTag("ScoreControlBranch", currentBranch)
        curScore.setMetaTag("ScoreControlCommitId", currentCommitId)
        curScore.setMetaTag("ScoreControlCommitMessage", currentCommitMessage)
    }

    function addCommit(branch, message, parentId) {
        var id = localId()
        commitModel.append({
            "id": id,
            "branch": branch,
            "message": message,
            "parentId": parentId
        })
        var branchIndex = findBranchIndex(branch)
        if (branchIndex < 0)
            branchModel.append({"name": branch, "headId": id})
        else
            branchModel.setProperty(branchIndex, "headId", id)
        branchPicker.currentIndex = findBranchIndex(branch)
        currentBranch = branch
        workingBaseId = id
        setCurrentCommit(id)
        writeScoreMetadata()
        return id
    }

    function createProject() {
        var name = projectNameField.text.trim()
        var message = initialMessageField.text.trim()
        if (name.length === 0 || message.length === 0) {
            statusMessage = "Enter both a project name and an initial commit message."
            return
        }

        projectName = name
        projectCreated = true
        currentBranch = "main"
        branchModel.clear()
        commitModel.clear()
        addCommit("main", message, "")
        statusMessage = "Created a local demo project with its main branch and initial commit."
    }

    function selectBranch(index) {
        if (index < 0 || index >= branchModel.count)
            return
        var branch = branchModel.get(index)
        currentBranch = branch.name
        if (setCurrentCommit(branch.headId)) {
            workingBaseId = branch.headId
            statusMessage = "Selected " + branch.name + " at its HEAD. The score file itself was not changed."
        }
    }

    function selectCommit(id) {
        if (findCommitIndex(id) >= 0) {
            selectedCommitId = id
            workingBaseId = id
            statusMessage = "Selected commit " + id + ". To restore its score, open the corresponding score file in MuseScore."
        }
    }

    function refreshBranches() {
        statusMessage = "Refreshed the local demo branch list (" + branchModel.count + " branch(es)). No server is connected."
    }

    function createBranchFromSelected() {
        var name = branchNameField.text.trim()
        if (name.length === 0) {
            statusMessage = "Enter a name for the new branch."
            return
        }
        if (findBranchIndex(name) >= 0) {
            statusMessage = "A branch with that name already exists."
            return
        }
        if (findCommitIndex(selectedCommitId) < 0) {
            statusMessage = "Select a commit before creating a branch."
            return
        }

        branchModel.append({"name": name, "headId": selectedCommitId})
        branchPicker.currentIndex = findBranchIndex(name)
        currentBranch = name
        workingBaseId = selectedCommitId
        setCurrentCommit(selectedCommitId)
        branchNameField.text = ""
        statusMessage = "Created local branch " + name + " from " + selectedCommitId + "."
    }

    function commitCurrentScore() {
        var message = commitMessageField.text.trim()
        if (message.length === 0) {
            statusMessage = "Enter a commit message."
            return
        }
        var branchIndex = findBranchIndex(currentBranch)
        if (branchIndex < 0) {
            statusMessage = "Select an existing branch before committing."
            return
        }

        var headId = branchModel.get(branchIndex).headId
        if (workingBaseId !== headId) {
            conflictNotice.visible = true
            statusMessage = "This branch advanced beyond your working base. Create a separate branch before committing."
            return
        }

        conflictNotice.visible = false
        addCommit(currentBranch, message, headId)
        commitMessageField.text = ""
        statusMessage = "Created a local demo commit on " + currentBranch + " and updated the open score's metadata."
    }

    function createConflictBranchAndCommit() {
        var name = conflictBranchField.text.trim()
        var message = commitMessageField.text.trim()
        if (name.length === 0 || message.length === 0) {
            statusMessage = "Enter both a new branch name and a commit message."
            return
        }
        if (findBranchIndex(name) >= 0) {
            statusMessage = "A branch with that name already exists."
            return
        }

        branchModel.append({"name": name, "headId": workingBaseId})
        branchPicker.currentIndex = findBranchIndex(name)
        conflictNotice.visible = false
        addCommit(name, message, workingBaseId)
        conflictBranchField.text = ""
        commitMessageField.text = ""
        statusMessage = "Created a separate local branch and commit. A real server-side concurrency guard is not available in this prototype."
    }

    function initializeFromScore() {
        if (!curScore)
            return
        var savedProject = curScore.metaTag("ScoreControlProject")
        var savedBranch = curScore.metaTag("ScoreControlBranch")
        var savedId = curScore.metaTag("ScoreControlCommitId")
        var savedMessage = curScore.metaTag("ScoreControlCommitMessage")
        if (savedProject.length > 0 && savedBranch.length > 0 && savedId.length > 0) {
            projectName = savedProject
            projectCreated = true
            currentBranch = savedBranch
            currentCommitId = savedId
            currentCommitMessage = savedMessage
            selectedCommitId = savedId
            workingBaseId = savedId
            branchModel.append({"name": savedBranch, "headId": savedId})
            commitModel.append({
                "id": savedId,
                "branch": savedBranch,
                "message": savedMessage,
                "parentId": ""
            })
            statusMessage = "Loaded project reference from this score's metadata. Other branches and history are session-only."
        }
    }

    onRun: initializeFromScore()

    Rectangle {
        anchors.fill: parent
        color: windowColor
        z: -1
    }

    Column {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        Label {
            text: "ScoreControl"
            font.pixelSize: 26
            font.bold: true
            color: textColor
        }

        Row {
            width: parent.width
            spacing: 12

            Label {
                text: "Local workflow prototype - no account or server connection"
                color: secondaryTextColor
                wrapMode: Text.WordWrap
                width: parent.width - themeButton.width - 12
                anchors.verticalCenter: parent.verticalCenter
            }

            Button {
                id: themeButton
                text: darkMode ? "Bright mode" : "Dark mode"
                onClicked: darkMode = !darkMode
                contentItem: Text {
                    text: themeButton.text
                    color: accentTextColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font: themeButton.font
                }
                background: Rectangle {
                    color: themeButton.down ? (darkMode ? "#17477f" : "#0e477f") : accentColor
                    border.color: borderColor
                    border.width: 1
                    radius: 4
                }
            }
        }

        Label {
            text: "Open score: " + (curScore ? curScore.title : "No score")
            elide: Text.ElideRight
            width: parent.width
            color: textColor
        }

        Rectangle {
            width: parent.width
            height: 1
            color: borderColor
        }

        ScrollView {
            width: parent.width
            height: parent.height - 260
            clip: true

            Column {
                width: parent.width
                spacing: 14

                Column {
                    width: parent.width
                    spacing: 8
                    visible: !loggedIn

                    Label {
                        text: "1. Log in"
                        font.pixelSize: 19
                        font.bold: true
                        color: textColor
                    }
                    Label {
                        text: "Demo sign-in only checks that both fields are filled. It does not authenticate an account."
                        wrapMode: Text.WordWrap
                        width: parent.width
                        color: secondaryTextColor
                    }
                    TextField {
                        id: emailField
                        width: parent.width
                        placeholderText: "Email"
                        inputMethodHints: Qt.ImhEmailCharactersOnly
                        color: textColor
                        placeholderTextColor: secondaryTextColor
                        selectionColor: accentColor
                        selectedTextColor: accentTextColor
                        background: Rectangle {
                            color: fieldColor
                            border.color: emailField.activeFocus ? accentColor : borderColor
                            border.width: emailField.activeFocus ? 2 : 1
                            radius: 3
                        }
                    }
                    TextField {
                        id: passwordField
                        width: parent.width
                        placeholderText: "Password"
                        echoMode: TextInput.Password
                        color: textColor
                        placeholderTextColor: secondaryTextColor
                        selectionColor: accentColor
                        selectedTextColor: accentTextColor
                        background: Rectangle {
                            color: fieldColor
                            border.color: passwordField.activeFocus ? accentColor : borderColor
                            border.width: passwordField.activeFocus ? 2 : 1
                            radius: 3
                        }
                    }
                    Button {
                        id: loginButton
                        text: "Log in (demo)"
                        onClicked: {
                            if (emailField.text.trim().length === 0 || passwordField.text.length === 0) {
                                statusMessage = "Enter an email and password to continue in demo mode."
                            } else {
                                accountEmail = emailField.text.trim()
                                loggedIn = true
                                statusMessage = "Signed in locally as " + accountEmail + ". No credentials were sent or saved."
                            }
                        }
                        contentItem: Text {
                            text: loginButton.text
                            color: accentTextColor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font: loginButton.font
                        }
                        background: Rectangle {
                            color: loginButton.down ? (darkMode ? "#17477f" : "#0e477f") : accentColor
                            border.color: borderColor
                            border.width: 1
                            radius: 4
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 8
                    visible: loggedIn && !projectCreated

                    Label {
                        text: "2. Create a project"
                        font.pixelSize: 19
                        font.bold: true
                        color: textColor
                    }
                    TextField {
                        id: projectNameField
                        width: parent.width
                        placeholderText: "Project name"
                        color: textColor
                        placeholderTextColor: secondaryTextColor
                        selectionColor: accentColor
                        selectedTextColor: accentTextColor
                        background: Rectangle {
                            color: fieldColor
                            border.color: projectNameField.activeFocus ? accentColor : borderColor
                            border.width: projectNameField.activeFocus ? 2 : 1
                            radius: 3
                        }
                    }
                    TextField {
                        id: initialMessageField
                        width: parent.width
                        placeholderText: "Initial commit message"
                        color: textColor
                        placeholderTextColor: secondaryTextColor
                        selectionColor: accentColor
                        selectedTextColor: accentTextColor
                        background: Rectangle {
                            color: fieldColor
                            border.color: initialMessageField.activeFocus ? accentColor : borderColor
                            border.width: initialMessageField.activeFocus ? 2 : 1
                            radius: 3
                        }
                    }
                    Button {
                        id: createProjectButton
                        text: "Create project with main branch"
                        onClicked: createProject()
                        contentItem: Text {
                            text: createProjectButton.text
                            color: accentTextColor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font: createProjectButton.font
                        }
                        background: Rectangle {
                            color: createProjectButton.down ? (darkMode ? "#17477f" : "#0e477f") : accentColor
                            border.color: borderColor
                            border.width: 1
                            radius: 4
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 10
                    visible: loggedIn && projectCreated

                    Label {
                        text: "3. Project: " + projectName
                        font.pixelSize: 19
                        font.bold: true
                        color: textColor
                    }

                    Row {
                        width: parent.width
                        spacing: 10
                        Label {
                            text: "Branch"
                            anchors.verticalCenter: parent.verticalCenter
                            color: textColor
                        }
                        ComboBox {
                            id: branchPicker
                            width: Math.max(180, parent.width - 160)
                            model: branchModel
                            textRole: "name"
                            onActivated: selectBranch(currentIndex)
                            contentItem: Text {
                                leftPadding: 8
                                rightPadding: branchPicker.indicator.width + 8
                                text: branchPicker.displayText
                                color: textColor
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                            indicator: Text {
                                text: "v"
                                color: textColor
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                width: 24
                                height: branchPicker.height
                                x: branchPicker.width - width
                            }
                            background: Rectangle {
                                color: fieldColor
                                border.color: borderColor
                                border.width: 1
                                radius: 3
                            }
                            delegate: ItemDelegate {
                                width: branchPicker.width
                                contentItem: Text {
                                    text: model.name
                                    color: textColor
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                                highlighted: branchPicker.highlightedIndex === index
                                background: Rectangle {
                                    color: parent.highlighted ? selectedColor : surfaceColor
                                }
                            }
                            popup: Popup {
                                y: branchPicker.height
                                width: branchPicker.width
                                implicitHeight: contentItem.implicitHeight
                                padding: 1
                                contentItem: ListView {
                                    clip: true
                                    implicitHeight: contentHeight
                                    model: branchPicker.popup.visible ? branchPicker.delegateModel : null
                                    currentIndex: branchPicker.highlightedIndex
                                }
                                background: Rectangle {
                                    color: surfaceColor
                                    border.color: borderColor
                                    border.width: 1
                                    radius: 3
                                }
                            }
                        }
                        Button {
                            id: refreshButton
                            text: "Refresh"
                            onClicked: refreshBranches()
                            contentItem: Text {
                                text: refreshButton.text
                                color: accentTextColor
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font: refreshButton.font
                            }
                            background: Rectangle {
                                color: refreshButton.down ? (darkMode ? "#17477f" : "#0e477f") : accentColor
                                border.color: borderColor
                                border.width: 1
                                radius: 4
                            }
                        }
                    }

                    GroupBox {
                        width: parent.width
                        title: "Current branch HEAD"
                        label: Label {
                            text: "Current branch HEAD"
                            color: textColor
                        }
                        background: Rectangle {
                            color: surfaceColor
                            border.color: borderColor
                            border.width: 1
                            radius: 4
                        }
                        Column {
                            anchors.fill: parent
                            spacing: 4
                            Label {
                                width: parent.width
                                text: "Branch: " + (currentBranch.length ? currentBranch : "-")
                                font.bold: true
                                color: textColor
                            }
                            Label {
                                width: parent.width
                                text: "Commit ID (local demo ID): " + (currentCommitId.length ? currentCommitId : "-")
                                wrapMode: Text.WrapAnywhere
                                color: textColor
                            }
                            Label {
                                width: parent.width
                                text: "Message: " + (currentCommitMessage.length ? currentCommitMessage : "-")
                                wrapMode: Text.WordWrap
                                color: textColor
                            }
                        }
                    }

                    Label {
                        text: "Commit history (local demo)"
                        font.pixelSize: 16
                        font.bold: true
                        color: textColor
                    }
                    ListView {
                        width: parent.width
                        height: Math.min(170, Math.max(54, commitModel.count * 54))
                        model: commitModel
                        clip: true
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 52
                            color: model.id === selectedCommitId ? selectedColor : (index % 2 ? alternateRowColor : surfaceColor)
                            border.color: borderColor
                            Column {
                                anchors.fill: parent
                                anchors.margins: 5
                                Label {
                                    width: parent.width
                                    text: model.id + "  [" + model.branch + "]"
                                    font.bold: true
                                    elide: Text.ElideRight
                                    color: textColor
                                }
                                Label {
                                    width: parent.width
                                    text: model.message
                                    elide: Text.ElideRight
                                    color: secondaryTextColor
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: selectCommit(model.id)
                            }
                        }
                    }
                    Label {
                        text: "Select a commit above to inspect it. To restore its musical content, obtain and open that commit's score file in MuseScore; this plugin cannot download or replace score files."
                        wrapMode: Text.WordWrap
                        color: noticeTextColor
                        width: parent.width
                    }

                    GroupBox {
                        width: parent.width
                        title: "Create a branch from the selected commit"
                        label: Label {
                            text: "Create a branch from the selected commit"
                            color: textColor
                        }
                        background: Rectangle {
                            color: surfaceColor
                            border.color: borderColor
                            border.width: 1
                            radius: 4
                        }
                        Row {
                            anchors.fill: parent
                            spacing: 8
                            TextField {
                                id: branchNameField
                                width: parent.width - createBranchButton.width - 8
                                placeholderText: "New branch name"
                                color: textColor
                                placeholderTextColor: secondaryTextColor
                                selectionColor: accentColor
                                selectedTextColor: accentTextColor
                                background: Rectangle {
                                    color: fieldColor
                                    border.color: branchNameField.activeFocus ? accentColor : borderColor
                                    border.width: branchNameField.activeFocus ? 2 : 1
                                    radius: 3
                                }
                            }
                            Button {
                                id: createBranchButton
                                text: "Create branch"
                                onClicked: createBranchFromSelected()
                                contentItem: Text {
                                    text: createBranchButton.text
                                    color: accentTextColor
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font: createBranchButton.font
                                }
                                background: Rectangle {
                                    color: createBranchButton.down ? (darkMode ? "#17477f" : "#0e477f") : accentColor
                                    border.color: borderColor
                                    border.width: 1
                                    radius: 4
                                }
                            }
                        }
                    }

                    GroupBox {
                        width: parent.width
                        title: "Commit the currently open score"
                        label: Label {
                            text: "Commit the currently open score"
                            color: textColor
                        }
                        background: Rectangle {
                            color: surfaceColor
                            border.color: borderColor
                            border.width: 1
                            radius: 4
                        }
                        Column {
                            anchors.fill: parent
                            spacing: 8
                            Label {
                                text: "Add your score edits in MuseScore, then enter a message. This demo does not detect score changes or upload score content."
                                wrapMode: Text.WordWrap
                                width: parent.width
                                color: secondaryTextColor
                            }
                            TextField {
                                id: commitMessageField
                                width: parent.width
                                placeholderText: "Commit message"
                                color: textColor
                                placeholderTextColor: secondaryTextColor
                                selectionColor: accentColor
                                selectedTextColor: accentTextColor
                                background: Rectangle {
                                    color: fieldColor
                                    border.color: commitMessageField.activeFocus ? accentColor : borderColor
                                    border.width: commitMessageField.activeFocus ? 2 : 1
                                    radius: 3
                                }
                            }
                            Button {
                                id: commitButton
                                text: "Commit on " + (currentBranch.length ? currentBranch : "current branch")
                                onClicked: commitCurrentScore()
                                contentItem: Text {
                                    text: commitButton.text
                                    color: accentTextColor
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font: commitButton.font
                                }
                                background: Rectangle {
                                    color: commitButton.down ? (darkMode ? "#17477f" : "#0e477f") : accentColor
                                    border.color: borderColor
                                    border.width: 1
                                    radius: 4
                                }
                            }
                            Rectangle {
                                id: conflictNotice
                                visible: false
                                width: parent.width
                                height: conflictContent.height + 18
                                color: noticeColor
                                border.color: borderColor
                                Column {
                                    id: conflictContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 8
                                    spacing: 6
                                    Label {
                                        width: parent.width
                                        text: "The branch has advanced since this working copy's base. In a real service, a guard request would detect this before commit. Create a separate branch in this demo:"
                                        wrapMode: Text.WordWrap
                                        color: noticeTextColor
                                    }
                                    Row {
                                        width: parent.width
                                        spacing: 8
                                        TextField {
                                            id: conflictBranchField
                                            width: parent.width - conflictBranchCommitButton.width - 8
                                            placeholderText: "New branch name"
                                            color: textColor
                                            placeholderTextColor: secondaryTextColor
                                            selectionColor: accentColor
                                            selectedTextColor: accentTextColor
                                            background: Rectangle {
                                                color: fieldColor
                                                border.color: conflictBranchField.activeFocus ? accentColor : borderColor
                                                border.width: conflictBranchField.activeFocus ? 2 : 1
                                                radius: 3
                                            }
                                        }
                                        Button {
                                            id: conflictBranchCommitButton
                                            text: "Branch + commit"
                                            onClicked: createConflictBranchAndCommit()
                                            contentItem: Text {
                                                text: conflictBranchCommitButton.text
                                                color: accentTextColor
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                font: conflictBranchCommitButton.font
                                            }
                                            background: Rectangle {
                                                color: conflictBranchCommitButton.down ? (darkMode ? "#17477f" : "#0e477f") : accentColor
                                                border.color: borderColor
                                                border.width: 1
                                                radius: 4
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        text: "Score metadata is updated when a local project/commit is created. It records project, branch, local demo commit ID and message; it does not contain musical score snapshots."
                        wrapMode: Text.WordWrap
                        color: secondaryTextColor
                        width: parent.width
                    }
                }
            }
        }

        Label {
            width: parent.width
            text: statusMessage
            wrapMode: Text.WordWrap
            color: textColor
        }

        Button {
            id: closeButton
            text: "Close"
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: quit()
            contentItem: Text {
                text: closeButton.text
                color: accentTextColor
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font: closeButton.font
            }
            background: Rectangle {
                color: closeButton.down ? (darkMode ? "#17477f" : "#0e477f") : accentColor
                border.color: borderColor
                border.width: 1
                radius: 4
            }
        }
    }
}
