/* The MIT License (MIT)
 *
 * Copyright (c) 2019 grumpycat <grumpycat3051@protonmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import grumpycat 1.0
import "."

PullDownMenu {
    property var reloadCallback

    MenuItem {
        //% "About %1"
        text: qsTrId("top-menu-about").arg(App.displayName)
        onClicked: pageStack.push(Qt.resolvedUrl("pages/AboutPage.qml"))
    }

    MenuItem {
        //% "Settings"
        text: qsTrId("top-menu-settings")
        onClicked: pageStack.push(Qt.resolvedUrl("pages/SettingsPage.qml"))
    }

    MenuItem {
        //% "Reload"
        text: qsTrId("top-menu-reload")
        visible: !!reloadCallback
        onClicked: reloadCallback()
    }

    MenuItem {
        text: "Reset disclaimer"
        visible: debugApp.value
        onClicked: disclaimerAccepted.value = false
    }

    MenuItem {
        //% "Logout"
        text: qsTrId("top-menu-logout")
        visible: window.isUserLoggedIn && window.logoutToken
        onClicked: window.logout()
    }

    MenuItem {
        //% "Login"
        text: qsTrId("top-menu-login")
        visible: !window.isUserLoggedIn && window.hasLoginData
        onClicked: window.login()
    }
}
