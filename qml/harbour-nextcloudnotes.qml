import QtQuick 2.2
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import Nemo.Notifications 1.0
import "pages"

ApplicationWindow
{
    id: appWindow

    // All configured accounts
    ConfigurationValue {
        id: accounts
        key: appSettings.path + "/accountIDs"
        defaultValue: [ ]
    }

    // Current account in use
    ConfigurationGroup {
        id: account
        path: "/apps/harbour-nextcloudnotes/accounts/" + appSettings.currentAccount

        property string name: value("name", "", String)
        property url server: value("server", "", String)
        property string version: value("version", "v0.2", String)
        property string username: value("username", "", String)
        property string password: account.value("password", "", String)
        property bool doNotVerifySsl: account.value("doNotVerifySsl", false, Boolean)
        property bool allowUnecrypted: account.value("allowUnecrypted", false, Boolean)
        property date update: value("update", "", Date)
        onServerChanged: notesApi.server = server
        onUsernameChanged: notesApi.username = username
        onPasswordChanged: notesApi.password = password
        onDoNotVerifySslChanged: notesApi.verifySsl = !doNotVerifySsl
        onPathChanged: {
            notesModel.sourceModel.clear()
            notesStore.account = appSettings.currentAccount
            notesApi.account = appSettings.currentAccount
        }
    }

    // General settings of the app
    ConfigurationGroup {
        id: appSettings
        path: "/apps/harbour-nextcloudnotes/settings"

        property bool initialized: false
        property string currentAccount: value("currentAccount", "", String)
        property int autoSyncInterval: value("autoSyncInterval", 0, Number)
        property int previewLineCount: value("previewLineCount", 4, Number)
        property bool favoritesOnTop: value("favoritesOnTop", true, Boolean)
        property string sortBy: value("sortBy", "modifiedString", String)
        property bool showSeparator: value("showSeparator", false, Boolean)
        property bool useMonoFont: value("useMonoFont", false, Boolean)
        property bool useCapitalX: value("useCapitalX", false, Boolean)

        onSortByChanged: {
            if (sortBy == "none")
                notesModel.invalidate()
            else
                notesModel.sortRole = notesModel.roleFromName(sortBy)
        }
        onFavoritesOnTopChanged: {
            notesModel.favoritesOnTop = favoritesOnTop
        }

        function addAccount() {
            var uuid = uuidv4()
            var tmpIDs = accounts.value
            tmpIDs.push(uuid)
            accounts.value = tmpIDs
            accounts.sync()
            return uuid
        }
        ConfigurationGroup {
            id: removeHelperConfGroup
        }
        function removeAccount(uuid) {
            autoSyncTimer.stop()
            var tmpIDs = accounts.value
            removeHelperConfGroup.path = "/apps/harbour-nextcloudnotes/accounts/" + uuid
            for (var i = tmpIDs.length-1; i >= 0; i--) {
                console.log(tmpIDs)
                console.log("Checking:" + tmpIDs[i])
                if (tmpIDs[i] === uuid) {
                    console.log("Found! Removing ...")
                    tmpIDs.splice(i, 1)
                }
                console.log(tmpIDs)
            }
            if (appSettings.currentAccount === uuid) {
               appSettings.currentAccount = ""
                for (var i = tmpIDs.length-1; i >= 0 && appSettings.currentAccount === ""; i--) {
                    if (tmpIDs[i] !== uuid) {
                        appSettings.currentAccount = tmpIDs[i]
                    }
                }
            }
            removeHelperConfGroup.clear()
            if (autoSyncInterval > 0 && appWindow.visible) {
                autoSyncTimer.start()
            }
            accounts.value = tmpIDs
            accounts.sync()
        }
        function uuidv4() {
            return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
                var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
                return v.toString(16);
            });
        }
    }

    Notification {
        id: offlineNotification
        expireTimeout: 0
        appName: "Nextcloud " + qsTr("Notes")
        summary: qsTr("Offline")
        body: qsTr("Synced") + ": " + new Date(account.update).toLocaleString(Qt.locale())
        Component.onDestruction: close()
    }

    Notification {
        id: errorNotification
        appName: offlineNotification.appName
        summary: qsTr("Error")
        Component.onDestruction: close()
    }

    Timer {
        id: autoSyncTimer
        interval: appSettings.autoSyncInterval * 1000
        repeat: true
        running: interval > 0 && notesApi.networkAccessible && appWindow.visible
        triggeredOnStart: true
        onTriggered: {
            notesStore.getAllNotes()
            if (!notesApi.busy) {
                notesApi.getAllNotes();
            }
            else {
                restart()
            }
        }
        onIntervalChanged: {
            if (interval > 0) {
                console.log("Auto-Sync every " + interval / 1000 + " seconds")
            }
        }
    }

    Connections {
        target: notesStore

        onAccountChanged: {
            //console.log(notesStore.account)
            notesStore.getAllNotes()
        }
    }

    Connections {
        target: notesApi

        onAccountChanged: {
            //console.log(notesStore.account)
            notesApi.getAllNotes()
        }
        onNetworkAccessibleChanged: {
            console.log("Device is " + (accessible ? "online" : "offline"))
            accessible ? offlineNotification.close(Notification.Closed) : offlineNotification.publish()
        }
        onError: {
            if (error)
                console.log("Error (" + error + "): " + notesApi.errorMessage(error))
            errorNotification.close()
            if (error && notesApi.networkAccessible) {
                errorNotification.body = notesApi.errorMessage(error)
                errorNotification.publish()
            }
        }
        onLastSyncChanged: account.update = lastSync
    }

    initialPage: Component { NotesPage { } }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: defaultAllowedOrientations
}
