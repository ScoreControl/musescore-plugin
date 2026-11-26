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

    // ------------------------------------------------------------------
    // SUPABASE CONFIG
    // Only the project URL and the PUBLISHABLE key belong here.
    // NEVER put the secret key, database URL or direct URL in this file:
    // anyone who installs the plugin can read it.
    // ------------------------------------------------------------------
    property string supabaseUrl: "https://hlvcdocdmfpdpoigjetx.supabase.co"
    property string supabaseKey: "sb_publishable_xBs_9larGHI3HrkvuRS_Jg_25kMH8M2"

    // ------------------------------------------------------------------
    // SCORECONTROL BACKEND
    // Projects are created through our backend's /api routes, which write
    // to Supabase for us. The plugin never writes to the database directly.
    // ------------------------------------------------------------------
    property string apiBase: "http://localhost:3000/api"
    // TEMPORARY, local testing only: the backend only accepts requests from the
    // website's own origin and doesn't support plugin (token) logins yet.
    // Remove this once the backend supports "client": "plugin" logins.
    property string testOrigin: "http://localhost:3000"

    // ------------------------------------------------------------------
    // PROJECT STATE
    // ------------------------------------------------------------------
    property bool backendLoggedIn: false
    property bool projectBusy: false
    property string projectError: ""
    property string currentProjectId: ""
    property string currentProjectName: ""
    property string currentProjectSlug: ""
    property string currentBranch: "main"
    // Message typed on Create Project. Kept until the first commit is made,
    // then sent as that commit's "message" (see buildCommitMetadata).
    property string firstCommitMessage: ""

    // ------------------------------------------------------------------
    // CURRENT COMMIT (head of currentBranch, loaded from the backend)
    // ------------------------------------------------------------------
    property bool commitLoading: false
    property string commitError: ""
    property bool hasCommit: false
    property string commitHash: ""
    property string commitShortHash: ""
    property string commitMessage: ""
    property string commitDate: ""
    property string commitAuthor: ""

    // ------------------------------------------------------------------
    // AUTH STATE (kept in memory only; lost when the plugin closes)
    // ------------------------------------------------------------------
    property bool authBusy: false
    property string authError: ""
    property string authInfo: ""
    property string accessToken: ""
    property string refreshToken: ""
    property string userEmail: ""

    // Generic POST to the Supabase Auth REST API.
    // callback(httpStatus, parsedJsonBody). httpStatus 0 = network failure.
    function authRequest(path, payload, token, callback) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            var body = {}
            try {
                body = JSON.parse(xhr.responseText)
            } catch (e) {
                // empty or non-JSON body (e.g. 204 on logout)
            }
            callback(xhr.status, body)
        }
        xhr.open("POST", supabaseUrl + path)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.setRequestHeader("apikey", supabaseKey)
        if (token !== "")
            xhr.setRequestHeader("Authorization", "Bearer " + token)
        xhr.send(JSON.stringify(payload))
    }

    // Supabase returns errors under different keys depending on the endpoint.
    function errorText(status, body) {
        if (status === 0)
            return "Could not reach the server. Check your connection and the Supabase URL."
        if (body.msg) return body.msg
        if (body.error_description) return body.error_description
        if (body.message) return body.message
        if (body.error) return body.error
        return "Something went wrong (HTTP " + status + ")."
    }

    // Request to our backend. Sends JSON, keeps the backend's login cookie
    // (MuseScore holds it between requests). callback(httpStatus, parsedJsonBody).
    function apiRequest(method, path, payload, callback) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return
            var body = {}
            try {
                body = JSON.parse(xhr.responseText)
            } catch (e) {
                // empty or non-JSON body
            }
            callback(xhr.status, body)
        }
        xhr.open(method, apiBase + path)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.setRequestHeader("X-Client", "scorecontrol-plugin/0.1.0")
        if (testOrigin !== "")
            xhr.setRequestHeader("Origin", testOrigin)
        xhr.send(payload ? JSON.stringify(payload) : null)
    }

    // Backend errors look like { error: { code, message, fields? } }.
    function apiErrorText(status, body) {
        if (status === 0)
            return "Could not reach the ScoreControl server. Is the backend running?"
        var e = body.error
        if (e) {
            if (e.code === "UNAUTHENTICATED" || e.code === "TOKEN_EXPIRED")
                return "Your session with the ScoreControl server ended. Log out and log in again."
            if (e.code === "INTERNAL_ERROR")
                return "The server had a problem (request " + (e.requestId || "?") + "). Try again, or check the backend terminal."
            var text = e.message || e.code
            if (e.fields)
                text += " " + JSON.stringify(e.fields)
            return text
        }
        return "Something went wrong (HTTP " + status + ")."
    }

    // Logs in to our backend with the same email and password, so later
    // /api requests are signed in. callback(ok, errorMessage)
    function backendLogIn(email, password, callback) {
        apiRequest("POST", "/auth/login", { identifier: email, password: password },
            function(status, body) {
                backendLoggedIn = (status === 200)
                callback(backendLoggedIn, backendLoggedIn ? "" : apiErrorText(status, body))
            })
    }

    function connectBackend(email, password) {
        projectError = ""
        backendLogIn(email, password, function(ok, message) {
            if (!ok)
                projectError = "Signed in, but couldn't connect to the ScoreControl server: " + message
        })
    }

    // POST /api/projects creates the project and its empty main branch.
    function createProject(name, description) {
        projectError = ""
        name = name.trim()
        description = (description || "").trim()
        if (name === "") {
            projectError = "Enter a project name."
            return
        }
        if (!backendLoggedIn) {
            projectError = "Not connected to the ScoreControl server. Log out and log in again."
            return
        }
        projectBusy = true
        var payload = { name: name }
        if (description !== "")
            payload.description = description   // optional; saved to projects.description
        apiRequest("POST", "/projects", payload, function(status, body) {
            projectBusy = false
            if (status !== 201 && status !== 200) {
                if (status === 401)
                    backendLoggedIn = false
                projectError = apiErrorText(status, body)
                return
            }
            var data = body.data || {}
            var p = data.project || data
            currentProjectId = p.id || ""
            currentProjectName = p.name || name
            currentProjectSlug = p.slug || ""
            currentBranch = (data.branch && data.branch.name) ? data.branch.name
                          : (p.defaultBranch || "main")
            // Save the commit message for the project's first commit.
            firstCommitMessage = commitMessageField.text.trim()
            clearCommit()
            currentScreen = "home"   // the Home screen loads the commit when it opens
        })
    }

    // The "metadata" JSON part for POST /api/projects/:id/commits (API contract, section 7).
    // The request also needs the score file itself as a multipart part named by "field".
    // TODO when the backend commit route exists: export the score to MusicXML, send it
    // with this metadata, then clear firstCommitMessage and call loadCurrentCommit().
    function buildCommitMetadata(message, parentHash, scorePath) {
        return {
            branch: currentBranch,
            parentHash: parentHash !== "" ? parentHash : null,   // null for the first commit
            message: message,
            newBranch: null,
            files: [ { field: "f0", path: scorePath, format: "MUSICXML", role: "primary" } ]
        }
    }

    // Message for the next commit: the one typed on Create Project if this
    // branch has no commits yet, otherwise whatever the user types.
    function nextCommitMessage(typed) {
        typed = (typed || "").trim()
        if (typed !== "")
            return typed
        return hasCommit ? "" : firstCommitMessage
    }

    function clearCommit() {
        hasCommit = false
        commitError = ""
        commitHash = ""
        commitShortHash = ""
        commitMessage = ""
        commitDate = ""
        commitAuthor = ""
    }

    // "2026-11-03T18:22:10.000Z" -> "Nov 3, 2026, 10:22 AM" (in the user's time zone)
    function formatDate(iso) {
        if (!iso) return ""
        var d = new Date(iso)
        if (isNaN(d.getTime())) return iso
        return Qt.formatDateTime(d, "MMM d, yyyy, h:mm AP")
    }

    // Loads the newest commit on the current branch:
    // GET /api/projects/:id/branches/:name/commits?limit=1 (API contract, section 8)
    function loadCurrentCommit() {
        if (currentProjectId === "" || !backendLoggedIn)
            return
        commitLoading = true
        commitError = ""
        var path = "/projects/" + currentProjectId + "/branches/"
                 + encodeURIComponent(currentBranch) + "/commits?limit=1"
        apiRequest("GET", path, null, function(status, body) {
            commitLoading = false
            if (status !== 200) {
                clearCommit()
                if (status === 401)
                    backendLoggedIn = false
                if (status === 404 && !(body.error && body.error.code))
                    commitError = "The server doesn't have commit history yet."
                else
                    commitError = apiErrorText(status, body)
                return
            }
            var data = body.data || {}
            var list = data.commits || data
            if (!list || !list.length) {
                // New project: main exists but has no commits yet.
                clearCommit()
                return
            }
            var c = list[0]
            hasCommit = true
            commitHash = c.hash || ""
            commitShortHash = c.shortHash || (c.hash ? c.hash.substring(0, 7) : "")
            commitMessage = c.message || ""
            commitDate = formatDate(c.createdAt)
            commitAuthor = (c.author && c.author.username) ? c.author.username : ""
        })
    }

    function startSession(body) {
        accessToken = body.access_token
        refreshToken = body.refresh_token
        userEmail = (body.user && body.user.email) ? body.user.email : ""
    }

    function clearForms() {
        loginPasswordField.text = ""
        signupPasswordField.text = ""
        signupConfirmField.text = ""
    }

    // Mirrors scorecontrol_auth.normalize_username and the website's usernameSchema.
    // The database is still the final authority; this only gives faster feedback.
    property var reservedUsernames: ["admin", "api", "auth", "login", "logout",
        "signup", "settings", "support", "help", "www", "scorecontrol"]

    // Returns "" when valid, otherwise a message for the user.
    function usernameProblem(name) {
        if (name.length < 1 || name.length > 39)
            return "Username must be 1 to 39 characters."
        if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(name))
            return "Use letters, numbers, and single hyphens; start and end with a letter or number."
        if (reservedUsernames.indexOf(name) !== -1)
            return "This username is reserved."
        return ""
    }

    function signUp(username, email, password, confirm) {
        authError = ""
        authInfo = ""
        // Same normalization as the database: trim + lowercase.
        var name = username.trim().toLowerCase()
        var problem = usernameProblem(name)
        if (problem !== "") {
            authError = problem
            return
        }
        if (email === "" || password === "") {
            authError = "Enter an email and a password."
            return
        }
        if (password.length < 8) {
            authError = "Password must be at least 8 characters."
            return
        }
        if (password !== confirm) {
            authError = "Passwords do not match."
            return
        }
        authBusy = true
        // The database trigger reads the username from user metadata under
        // the key "scorecontrol_username" and rejects sign-ups without it.
        authRequest("/auth/v1/signup",
            { email: email, password: password,
              data: { scorecontrol_username: name } }, "",
            function(status, body) {
                authBusy = false
                if (status < 200 || status >= 300) {
                    if (status === 500) {
                        // Supabase hides errors raised inside the sign-up trigger
                        // behind a generic 500. Since the format is already checked
                        // above, a taken username is the most likely cause.
                        authError = "Could not create the account. That username may already be taken."
                    } else {
                        authError = errorText(status, body)
                    }
                    return
                }
                clearForms()
                if (body.access_token) {
                    // Email confirmation is OFF: Supabase signed us in directly.
                    startSession(body)
                    connectBackend(email, password)
                    currentScreen = "createProject"
                } else {
                    // Email confirmation is ON: no session until the link is clicked.
                    authInfo = "Account created. Check your email to confirm it, then log in."
                    currentScreen = "login"
                }
            })
    }

    function logIn(email, password) {
        authError = ""
        authInfo = ""
        if (email === "" || password === "") {
            authError = "Enter your email and password."
            return
        }
        authBusy = true
        authRequest("/auth/v1/token?grant_type=password",
            { email: email, password: password }, "",
            function(status, body) {
                authBusy = false
                if (status !== 200 || !body.access_token) {
                    authError = errorText(status, body)
                    return
                }
                clearForms()
                startSession(body)
                connectBackend(email, password)
                // Same destination as the original mockup; real routing
                // (project exists or not) comes later.
                currentScreen = "createProject"
            })
    }

    function requestPasswordReset(email) {
        authError = ""
        authInfo = ""
        if (email === "") {
            authError = "Enter your email address first."
            return
        }
        authBusy = true
        authRequest("/auth/v1/recover", { email: email }, "",
            function(status, body) {
                authBusy = false
                if (status < 200 || status >= 300) {
                    authError = errorText(status, body)
                    return
                }
                authInfo = "If an account exists for that email, a password reset link has been sent."
            })
    }

    function logOut() {
        var token = accessToken
        accessToken = ""
        refreshToken = ""
        userEmail = ""
        authError = ""
        authInfo = ""
        if (backendLoggedIn)
            apiRequest("POST", "/auth/logout", {}, function(status, body) {})
        backendLoggedIn = false
        projectError = ""
        currentProjectId = ""
        currentProjectName = ""
        currentProjectSlug = ""
        currentBranch = "main"
        firstCommitMessage = ""
        clearCommit()
        currentScreen = "login"
        if (token !== "")
            authRequest("/auth/v1/logout", {}, token, function(status, body) {})
    }

    Rectangle {
        anchors.fill: parent
        color: "#f6f8fa"

        // HEADER
        Rectangle {
            id: header
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
        // CONTENT AREA: everything below the header. Screens fill this,
        // so they can never draw over the header bar.
        Item {
            id: content
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true


            // LOGIN SCREEN
            Column {
                visible: currentScreen === "login"

                anchors.centerIn: parent
                width: parent.width - 60
                spacing: 14

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
                    text: "Log in to save and manage\n"
                          + "your scores with MuseScore."
                    horizontalAlignment: Text.AlignHCenter
                    color: "#57606a"
                    font.pixelSize: 13
                    width: parent.width
                }

                TextField {
                    id: loginEmailField
                    width: parent.width
                    height: 42
                    placeholderText: "Email"
                    inputMethodHints: Qt.ImhEmailCharactersOnly
                    enabled: !authBusy
                }

                TextField {
                    id: loginPasswordField
                    width: parent.width
                    height: 42
                    placeholderText: "Password"
                    echoMode: TextInput.Password
                    enabled: !authBusy
                    onAccepted: logIn(loginEmailField.text.trim(), text)
                }

                Text {
                    visible: authError !== ""
                    text: authError
                    color: "#cf222e"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    width: parent.width
                }
                Text {
                    visible: authInfo !== ""
                    text: authInfo
                    color: "#1a7f37"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Button {
                    text: "Forgot password?"
                    flat: true
                    width: parent.width
                    enabled: !authBusy

                    onClicked: requestPasswordReset(loginEmailField.text.trim())
                }

                Button {
                    text: authBusy ? "Logging in..." : "Log in"

                    width: parent.width
                    height: 45
                    enabled: !authBusy

                    onClicked: logIn(loginEmailField.text.trim(), loginPasswordField.text)
                }

                Button {
                    text: "Create an account"
                    flat: true
                    width: parent.width
                    enabled: !authBusy

                    onClicked: {
                        authError = ""
                        authInfo = ""
                        currentScreen = "signup"
                    }
                }

                Text {
                    text: "Why do I need to log in?"
                    color: "#0969da"
                    font.pixelSize: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // SIGN UP SCREEN
            Column {
                visible: currentScreen === "signup"

                anchors.centerIn: parent
                width: parent.width - 60
                spacing: 14

                Text {
                    text: "Create an Account"
                    font.pixelSize: 22
                    font.bold: true
                    color: "#24292f"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Sign up to start saving versions of\n"
                          + "your scores."
                    horizontalAlignment: Text.AlignHCenter
                    color: "#57606a"
                    font.pixelSize: 13
                    width: parent.width
                }

                TextField {
                    id: signupUsernameField
                    width: parent.width
                    height: 42
                    placeholderText: "Username"
                    enabled: !authBusy
                }

                TextField {
                    id: signupEmailField
                    width: parent.width
                    height: 42
                    placeholderText: "Email"
                    inputMethodHints: Qt.ImhEmailCharactersOnly
                    enabled: !authBusy
                }

                TextField {
                    id: signupPasswordField
                    width: parent.width
                    height: 42
                    placeholderText: "Password"
                    echoMode: TextInput.Password
                    enabled: !authBusy
                }

                TextField {
                    id: signupConfirmField
                    width: parent.width
                    height: 42
                    placeholderText: "Confirm password"
                    echoMode: TextInput.Password
                    enabled: !authBusy
                    onAccepted: signUp(signupUsernameField.text.trim(),
                                       signupEmailField.text.trim(),
                                       signupPasswordField.text, text)
                }

                Text {
                    visible: authError !== ""
                    text: authError
                    color: "#cf222e"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Button {
                    text: authBusy ? "Creating account..." : "Create account"

                    width: parent.width
                    height: 45
                    enabled: !authBusy

                    onClicked: signUp(signupUsernameField.text.trim(),
                                      signupEmailField.text.trim(),
                                      signupPasswordField.text,
                                      signupConfirmField.text)
                }

                Button {
                    text: "‹  Back to log in"
                    flat: true
                    width: parent.width
                    enabled: !authBusy

                    onClicked: {
                        authError = ""
                        authInfo = ""
                        currentScreen = "login"
                    }
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
                    enabled: !projectBusy
                    onAccepted: createProject(text, projectDescriptionField.text)
                }

                Text {
                    text: "Description (optional)"
                    font.bold: true
                    color: "#24292f"
                }

                TextField {
                    id: projectDescriptionField

                    width: parent.width
                    height: 42

                    placeholderText: "What is this score?"
                    enabled: !projectBusy
                    onAccepted: createProject(projectNameField.text, text)
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
                    enabled: !projectBusy
                }

                Text {
                    text: "Used for your score's first commit."
                    color: "#57606a"
                    font.pixelSize: 11
                }

                Item {
                    width: 1
                    height: 5
                }

                Text {
                    visible: projectError !== ""
                    text: projectError
                    color: "#cf222e"
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    width: parent.width
                }

                Button {
                    text: projectBusy ? "Creating project..." : "Create Project"

                    width: parent.width
                    height: 45
                    enabled: !projectBusy

                    onClicked: createProject(projectNameField.text, projectDescriptionField.text)
                }

                Text {
                    text: "This creates the project with a main branch.\n"
                          + "Your commit message is kept for the first commit."

                    color: "#57606a"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    width: parent.width
                }
            }

            // HOME SCREEN
            Column {
                visible: currentScreen === "home"
                // Fetch the real commit every time Home opens.
                onVisibleChanged: if (visible) loadCurrentCommit()

                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text {
                    text: currentProjectName !== "" ? currentProjectName : "My First Score"
                    font.pixelSize: 21
                    font.bold: true
                    color: "#24292f"
                }

                Text {
                    text: "⑂  " + currentBranch
                    color: "#0969da"
                    font.pixelSize: 13
                }

                Rectangle {
                    width: parent.width
                    height: commitInfo.implicitHeight + 30   // grows with long messages

                    color: "white"
                    border.color: "#d0d7de"
                    radius: 7

                    Column {
                        id: commitInfo
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 15
                        spacing: 7

                        Row {
                            width: parent.width

                            Text {
                                text: "CURRENT COMMIT"
                                font.pixelSize: 10
                                font.bold: true
                                color: "#57606a"
                                width: parent.width - refreshCommit.width
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                id: refreshCommit
                                text: commitLoading ? "Loading..." : "↻ Refresh"
                                color: "#0969da"
                                font.pixelSize: 11
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: !commitLoading
                                    onClicked: loadCurrentCommit()
                                }
                            }
                        }

                        // Error
                        Text {
                            visible: commitError !== ""
                            text: commitError
                            color: "#cf222e"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        // Empty branch (new project)
                        Text {
                            visible: commitError === "" && !hasCommit && !commitLoading
                            text: "No commits yet on " + currentBranch + ".\n"
                                  + "Commit your score to save its first version."
                            color: "#57606a"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        // Real commit
                        Text {
                            visible: hasCommit
                            text: commitShortHash
                            font.bold: true
                            font.family: "Courier"
                            color: "#24292f"
                        }

                        Text {
                            visible: hasCommit
                            text: "\"" + commitMessage + "\""
                            color: "#57606a"
                            font.pixelSize: 12
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }

                        Text {
                            visible: hasCommit
                            text: commitDate + (commitAuthor !== "" ? "  ·  " + commitAuthor : "")
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
                        // First commit: start with the message typed on Create Project.
                        newCommitMessage.text = nextCommitMessage(newCommitMessage.text)
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

                Button {
                    text: "Log out" + (userEmail !== "" ? " (" + userEmail + ")" : "")
                    flat: true

                    width: parent.width
                    height: 40

                    onClicked: logOut()
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
                        text: "Project       " + (currentProjectName !== "" ? currentProjectName : "My First Score")
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
                        text: "Branch        " + currentBranch
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
                        text: "Commit        " + (hasCommit ? commitShortHash : "none yet")
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
                        text: "Message       " + (hasCommit ? commitMessage : "-")
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
