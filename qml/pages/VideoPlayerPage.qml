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
import QtMultimedia 5.0
import QtGraphicalEffects 1.0
import Sailfish.Silica 1.0
import Nemo.KeepAlive 1.2
import grumpycat 1.0
import ".."

Page {
    id: page
    property string videoUrl
    property string videoId
    property string videoTitle

    backNavigation: controlPanel.open || !_hasSource

    readonly property int playbackOffset: streamPositonS
    readonly property int streamPositonS: Math.floor(mediaplayer.position / 1000)
    readonly property int streamDurationS: Math.ceil(mediaplayer.duration / 1000)
    property bool _forceBusyIndicator: false
    property bool _hasSource: !!("" + mediaplayer.source)
    property bool _paused: false
    property int _pauseCount: 0
    property int _openCount: 0
    property bool _pauseDueToStall: false
    property bool _clickedToOpen: false
    readonly property bool isPlaying: mediaplayer.playbackState === MediaPlayer.PlayingState
    property var _formats: []

    property bool _isFavorite: false
    property int _action: -1
    property string _ratingToken

    readonly property int actionVoteUp: 0
    readonly property int actionVoteDown: 1
    readonly property int actionToggleFavorite: 2

    property string _modelUrl
    property string _modelName
    property int _upVotes: -1
    property int _downVotes: -1
    property var _categories: []
    property var _pornstars: []
    property var _tags: []

    DisplayBlanking {
        id: displayBlanking
    }

    Http {
        id: http

        onStatusChanged: {
            switch (status) {
            case Http.StatusCompleted:
                console.debug("completed error=" + error)
                if (Http.ErrorNone === error) {
                    if (url === videoUrl) {
                        _parseVideoData(data)
                        if (_formats.length) {
                            // update allowed orientations based on video format
                            var f = _formats[0]
                            if (f.height > f.width) {
                                page.allowedOrientations = Orientation.Portrait | Orientation.PortraitInverted
                            } else {
                                page.allowedOrientations = Orientation.Landscape | Orientation.LandscapeInverted
                            }

                            // select format and play
                            var formatId = _getVideoFormatFromBearerMode()
                            var formatIndex = _findBestFormat(formatId)
                            var format = _formats[formatIndex]
                            play(format.format_url)
                        } else {
                            // fix me
                            openControlPanel()
                        }
                    } else {
                        console.debug(data)
                        switch (_action) {
                        case actionVoteUp:
                            break
                        case actionVoteDown:
                            break
                        case actionToggleFavorite:
                            try {
                                // {"action":"add","message":"","url":"\/video\/favourite?id=214353492&amp;toggle=1&amp;token=MTU1NDQ3ODMxOTXQEC3kpv-AUEGZKXXNOK0EAV0Tp8CK310tStFa2rtBnRPufgQsNXVBzVmQ2o7jX8B0WD9ZtUnUH5kNLS5aQmU.","success":"true"}
                                var jsonObject = JSON.parse(data)
                                if (jsonObject.success === "true") {
                                    _isFavorite = jsonObject.action === "remove" // looks wrong, I know
                                } else {
                                    window.notify(jsonObject.message)
                                }
                            } catch (error) {
                                console.debug(error)
                                console.debug(data)
                            }
                            break
                        }
                    }
                } else {
                    window.downloadError(url, error, errorMessage)
                    openControlPanel()
                }
                break
            }
        }
    }

    Timer {
        id: stallTimer
        interval: 10000
        onTriggered: {
            console.debug("stall timer expired")
            _pauseDueToStall = true
            pause()
            openControlPanel()
        }
    }


    MediaPlayer {
        id: mediaplayer
        autoPlay: true

        onStatusChanged: {
            console.debug("media player status=" + status)
            switch (status) {
            case MediaPlayer.Buffering:
                console.debug("buffering")
                stallTimer.start()
                break
            case MediaPlayer.Stalled:
                console.debug("stalled")
                stallTimer.start()
                break
            case MediaPlayer.Buffered:
                console.debug("buffered")
                stallTimer.stop()
                if (_pauseDueToStall) {
                    _pauseDueToStall = false
                    resume()
                    closeControlPanel()
                }
                break
            case MediaPlayer.EndOfMedia:
                console.debug("end of media")
                openControlPanel()
                break
            case MediaPlayer.Loaded:
                console.debug("loaded")
                break
            case MediaPlayer.InvalidMedia:
                console.debug("invalid media")
                openControlPanel()
                break
            }
        }

        onPlaybackStateChanged: {
            console.debug("media player playback state=" + playbackState)

            switch (playbackState) {
            case MediaPlayer.PlayingState:
                console.debug("playing")
                break
            case MediaPlayer.PausedState:
                console.debug("paused")
                break
            case MediaPlayer.StoppedState:
                console.debug("stopped")
                break
            default:
                console.debug("unhandled playback state")
                break
            }

            displayBlanking.preventBlanking = playbackState === MediaPlayer.PlayingState
        }
    }


    Rectangle {
        id: videoOutputRectangle
        anchors.fill: parent
        color: "black"

        VideoOutput {
            id: videoOutput
            anchors.fill: parent
            source: mediaplayer
            fillMode: VideoOutput.PreserveAspectFit
        }

        BusyIndicator {
            anchors.centerIn: parent
            running: _forceBusyIndicator || (mediaplayer.status === MediaPlayer.Stalled) || http.status === Http.StatusRunning
            size: BusyIndicatorSize.Medium
        }


        Rectangle {
            id: seekRectangle
            color: "white"
            width: Theme.horizontalPageMargin * 2 + seekLabel.width
            height: 2*Theme.fontSizeExtraLarge
            visible: false
            anchors.centerIn: parent
            layer.enabled: true
            radius: Theme.itemSizeSmall

            Label {
                id: seekLabel
                color: "black"
                text: ""
                font.bold: true
                font.pixelSize: Theme.fontSizeExtraLarge
                anchors.centerIn: parent
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            property real startx: -1
            property real starty: -1
//            readonly property real dragDistance: Theme.iconSizeLarge / 2
            readonly property real dragDistance: Theme.startDragDistance

            property bool held: false
            property int seekType: -1
            property real initialVolume: 0

            onPositionChanged: function (e) {
//                console.debug("x=" + e.x + " y="+e.y)
                e.accepted = true

                if (startx >= 0 && starty >= 0) {
                    var dx = e.x - startx
                    var dy = e.y - starty

                    if (-1 === seekType) {
                        if (Math.abs(dx) >= dragDistance ||
                            Math.abs(dy) >= dragDistance) {

                            if (Math.abs(dx) >= Math.abs(dy)) {
                                seekType = 0
                            } else {
                                seekType = 1
                            }
                        }
                    }

                    seekRectangle.visible = seekType !== -1
                    switch (seekType) {
                    case 0: { // position
                        var skipSeconds = computePositionSeek(dx)
                        var streamPosition = Math.max(0, Math.min(streamPositonS + skipSeconds, streamDurationS))
                        seekLabel.text = (dx >= 0 ? "+" : "-") + _toTime(Math.abs(skipSeconds)) + " (" + _toTime(streamPosition) + ")"
                    } break
                    case 1: { // volume
                        var volumeChange = -(dy / parent.height)
                        var volume = Math.max(0, Math.min(initialVolume + volumeChange, 1))
                        seekLabel.text = "Volume " + (volume * 100).toFixed(0) + "%"
                        mediaplayer.volume = volume
                    } break
                    }
                }
            }

            onPressed: function (e) {
//                console.debug("pressed")
                if (!controlPanel.open) {
                    startx = e.x;
                    starty = e.y;
                    initialVolume = mediaplayer.volume
                }
            }

            onReleased: function (e) {
//                console.debug("released")

                var dx = e.x - startx
                var dy = e.y - starty

                switch (seekType) {
                case 0: { // position
                        var skipSeconds = computePositionSeek(dx)
                        if (Math.abs(skipSeconds) >= 3) { // prevent small skips
                            var streamPosition = Math.floor(Math.max(0, Math.min(streamPositonS + skipSeconds, streamDurationS)))
                            if (streamPosition !== streamPositonS) {
                                console.debug("skip to=" + streamPosition)
                                _seek(streamPosition * 1000)
                            }
                        }
                } break
                case 1: { // volume
//                    var volumeChange = -dy / dragDistance
//                    var volume = Math.max(0, Math.min(mediaplayer.volume + volumeChange, 1))
//                    mediaplayer.volume = volume
                } break
                default: {
                    if (!held) {
                        if (controlPanel.open) {
                            if (_clickedToOpen) {
                                _clickedToOpen = false
                                closeControlPanel()
                            }
//                            mediaplayer.play()
                        } else {
//                            mediaplayer.pause()
                            if (!_clickedToOpen) {
                                _clickedToOpen = true
                                openControlPanel()
                            }
                        }
                    }
                } break
                }

                seekType = -1
                held = false
                startx = -1
                starty = -1
                seekRectangle.visible = false
                initialVolume = 0
            }

            onPressAndHold: function (e) {
                console.debug("onPressAndHold")
                e.accepted = true
                held = true
            }

            function computePositionSeek(dx) {
                var sign = dx < 0 ? -1 : 1
                var absDx = sign * dx
                return sign * Math.pow(absDx / dragDistance, 1 + absDx / Screen.width)
            }

            DockedPanel {
                id: controlPanel
                width: parent.width
                height: 2*Theme.itemSizeLarge
                dock: Dock.Bottom

                onOpenChanged: {
                    console.debug("control panel open=" + open)
                }

                Column {
                    width: parent.width

                    Slider {
                        id: positionSlider
                        width: parent.width
                        maximumValue: Math.max(1, mediaplayer.duration)

                        Connections {
                            target: mediaplayer
                            onPositionChanged: {
                                if (!positionSlider.down && !seekTimer.running) {
                                    positionSliderConnections.target = null
                                    positionSlider.value = Math.max(0, mediaplayer.position)
                                    positionSliderConnections.target = positionSlider
                                }
                            }
                        }

                        Connections {
                            id: positionSliderConnections
                            target: positionSlider
                            onValueChanged: {
                                console.debug("onValueChanged " + positionSlider.value + " down=" + positionSlider.down)
                                seekTimer.restart()
                            }
                        }

                        Timer {
                            id: seekTimer
                            running: false
                            interval: 500
                            repeat: false
                            onTriggered: {
                                _seek(positionSlider.sliderValue)
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: first.height

                        Item {
                            id: leftMargin
                            width: Theme.horizontalPageMargin
                            height: parent.height
                            anchors.left: parent.left
                        }

                        Item {
                            id: rightMargin
                            width: Theme.horizontalPageMargin
                            height: parent.height
                            anchors.right: parent.right
                        }

                        Label {
                            id: first
                            anchors.left: leftMargin.right
                            text: _toTime(streamPositonS)
                            font.pixelSize: Theme.fontSizeExtraSmall
                        }

                        Label {
                            anchors.right: rightMargin.left
                            text: _toTime(streamDurationS)
                            font.pixelSize: Theme.fontSizeExtraSmall
                            color: Theme.highlightColor
                        }
                    }

                    Item {
                        width: parent.width
                        height: functionalButtonRow.height

                        Item {
                            id: leftMargin2
                            width: Theme.horizontalPageMargin
                            height: parent.height
                            anchors.left: parent.left
                        }

                        Item {
                            id: rightMargin2
                            width: Theme.horizontalPageMargin
                            height: parent.height
                            anchors.right: parent.right
                        }

                        Row {
                            id: functionalButtonRow
                            anchors.centerIn: parent
                            spacing: Theme.paddingLarge

                            IconButton {
                                icon.source: isPlaying
                                             ? "image://theme/icon-m-pause"
                                             : (mediaplayer.status === MediaPlayer.EndOfMedia
                                                ? "image://theme/icon-m-reload"
                                                : "image://theme/icon-m-play")
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    console.debug("play/pause")
                                    switch (mediaplayer.playbackState) {
                                    case MediaPlayer.PlayingState:
                                        page.pause()
                                        break
                                    case MediaPlayer.PausedState:
                                    case MediaPlayer.StoppedState:
                                        switch (mediaplayer.status) {
                                        case MediaPlayer.Buffered:
                                            page.resume()
                                            break
                                        case MediaPlayer.EndOfMedia:
                                            closeControlPanel()
                                            _seek(0)
                                            mediaplayer.play()
                                            break
                                        }
                                        break
                                    }
                                }
                            }


                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: leftMargin2.right
                            spacing: Theme.paddingMedium


                            Label {
                                visible: videoOutput.sourceRect.width > 0 && videoOutput.sourceRect.height > 0
                                text: videoOutput.sourceRect.width + "x" + videoOutput.sourceRect.height
                                font.pixelSize: Theme.fontSizeExtraSmall
                                color: Theme.highlightColor
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.paddingSmall
                                visible: _upVotes >= 0 && _downVotes >= 0

                                Icon {
                                    width: Theme.iconSizeExtraSmall
                                    height: Theme.iconSizeExtraSmall
                                    source: "file://" + App.appDir + "/media/thumbs-up-filled-white.png"

//                                    ColorOverlay {
//                                        anchors.fill: parent
//                                        source: parent
//                                        color: Theme.primaryColor
//                                    }
                                }

                                Label {
                                    text: _upVotes.toFixed(0)
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.highlightColor
                                }

                                Icon {
                                    width: Theme.iconSizeExtraSmall
                                    height: Theme.iconSizeExtraSmall
                                    source: "file://" + App.appDir + "/media/thumbs-down-filled-white.png"

//                                    ColorOverlay {
//                                        anchors.fill: parent
//                                        source: parent
//                                        color: Theme.primaryColor
//                                    }
                                }

                                Label {
                                    text: _downVotes.toFixed(0)
                                    font.pixelSize: Theme.fontSizeExtraSmall
                                    color: Theme.highlightColor
                                }
                            }
                        }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: rightMargin2.left
                            spacing: Theme.paddingLarge



                            IconButton {
                                visible: _categories.length > 0
                                icon.width: Theme.iconSizeSmallPlus
                                icon.height: Theme.iconSizeSmallPlus
                                icon.source: "image://theme/icon-m-about"
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    pageStack.replace(
                                                Qt.resolvedUrl("VideosPage.qml"),
                                                {
                                                    //% "%1's Videos"
                                                    videosUrl: Constants.baseUrl + _modelUrl + "/videos",
                                                    title: qsTrId("ph-model-videos-page-title").arg(_modelName)
                                                })
                                }
                            }

                            IconButton {
                                visible: _modelName && _modelUrl
                                icon.width: Theme.iconSizeSmallPlus
                                icon.height: Theme.iconSizeSmallPlus
                                //icon.source: "image://theme/icon-m-person"
                                icon.source: "image://theme/icon-m-media-artists"
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    pageStack.replace(
                                                Qt.resolvedUrl("VideosPage.qml"),
                                                {
                                                    //% "%1's Videos"
                                                    videosUrl: Constants.baseUrl + _modelUrl + "/videos",
                                                    title: qsTrId("ph-model-videos-page-title").arg(_modelName)
                                                })
                                }
                            }

                            IconButton {
                                visible: false && window.isUserLoggedIn && _ratingToken
                                icon.width: Theme.iconSizeSmallPlus
                                icon.height: Theme.iconSizeSmallPlus
                                icon.source: "file://" + App.appDir + "/media/thumbs-up-outlined.png"
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    _action = actionVoteUp
                                    var postArgs = App.urlEncode({
                                                                     token: _ratingToken,
                                                                     id: videoId,
                                                                     value: 1,
                                                                 })
//                                    http.post(Constants.baseUrl + "/video/rate", postArgs)
                                    http.post(Constants.baseUrl + "/video/rate?" + postArgs)
                                }
                            }

                            IconButton {
                                visible: false && window.isUserLoggedIn && _ratingToken
                                icon.width: Theme.iconSizeSmallPlus
                                icon.height: Theme.iconSizeSmallPlus
                                icon.source: "file://" + App.appDir + "/media/thumbs-down-outlined.png"
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    _action = actionVoteDown
                                    var postArgs = App.urlEncode({
                                                                     token: _ratingToken,
                                                                     id: videoId,
                                                                     value: 0,
                                                                 })
                                    http.post(Constants.baseUrl + "/video/rate?" + postArgs)
                                }
                            }

                            IconButton {
                                visible: window.isUserLoggedIn && _ratingToken
                                icon.width: Theme.iconSizeSmallPlus
                                icon.height: Theme.iconSizeSmallPlus
                                icon.source: _isFavorite
                                             ? "file://" + App.appDir + "/media/heart-filled-white.png"
                                             : "file://" + App.appDir + "/media/heart-outlined.png"
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    _action = actionToggleFavorite
                                    var postArgs = App.urlEncode({
                                                                     token: _ratingToken,
                                                                     id: videoId,
                                                                     toggle: (_isFavorite ? 0 : 1),
                                                                 })
                                    http.post(Constants.baseUrl + "/video/favourite", postArgs)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        window.videoPlayerPage = page
        http.get(videoUrl)
    }

    Component.onDestruction: {
        console.debug("destruction")
        displayBlanking.preventBlanking = false
        mediaplayer.pause()
        window.videoPlayerPage = null
    }


    Timer {
        id: busyTimer
        interval: 1000
        onTriggered: {
            console.debug("_forceBusyIndicator = false")
            _forceBusyIndicator = false
        }
    }

    onStatusChanged: {
        console.debug("page status=" + status)
        switch (status) {
        case PageStatus.Deactivating:
            console.debug("page status=deactivating")
            break
        case PageStatus.Activating:
            console.debug("page status=activating")
            break
        }
    }

    function play(url) {
        console.debug("play url=" + url)
        mediaplayer.source = url
        mediaplayer.play()
        controlPanel.open = false
        _clickedToOpen = false
        _openCount = 0
        _pauseCount = 0;
        _paused = false
    }

    function pause() {
        _pauseCount += 1
        console.debug("pause count="+ _pauseCount)
        if (isPlaying) {
            console.debug("video player page pause playback")
//            mediaplayer.pause()

            _paused = true
            mediaplayer.pause()
        }
    }

    function resume() {
        _pauseCount -= 1
        console.debug("pause count="+ _pauseCount)
        if (_pauseCount === 0 && _paused) {
            console.debug("video player page resume playback")
            _paused = false
            mediaplayer.play()
            // toggle item visibility to to unfreeze video
            // after coming out of device lock
            videoOutputRectangle.visible = false
            videoOutputRectangle.visible = true
        }
    }

    function openControlPanel() {
        _openCount += 1
        console.debug("open count="+ _openCount)
        if (!controlPanel.open) {
            console.debug("opening control pannel")
            controlPanel.open = true
        }
    }

    function closeControlPanel() {
        _openCount -= 1
        console.debug("open count="+ _openCount)
        if (_openCount === 0 && controlPanel.open) {
            console.debug("closing control panel")
            controlPanel.open = false
        }
    }

    function _stopPlayback() {
        pause()
    }

    function _toTime(n) {
        return _secondsToTimeString(n)
    }

    function _seek(position) {
        _forceBusyIndicator = true
        console.debug("_forceBusyIndicator=true")
        busyTimer.restart()
        mediaplayer.seek(position)
    }

    function _parseVideoData(data) {
        var formats = []
        var videoFormatsRegex = new RegExp("^\\s*var\\s+flashvars_\\d+\\s*=\\s*(\\{(.+?)\\})\\s*;?\\s*$")
        var ratingRegex = new RegExp("^\\s*var\\s+WIDGET_RATINGS_LIKE_FAV\\s*=\\s*(\\{(.+?)\\})\\s*;?\\s*$")
        var ratingTokenRegex = new RegExp("^\\s*WIDGET_RATINGS_LIKE_FAV.token\\s*=\\s*\"(.+?)\"")
        var modelRegex = new RegExp("<a\\s+.*?href=[\"']([^\"']+)[\"']\\s+class=[\"']bolded[\"'][^>]*>([^<]+)</a>")
        /*class="bolded"
                <div class="usernameWrap clearfix" data-type="user" data-userid="313532711" data-liu-user="0" data-json-url="/user/box?id=313532711&amp;token=MTU1OTQ5NzExMi0HQ8Bu2IQ-Df8mIbhL2eVzXWjtLcwn66zG4l5w1MOT7zo7-UuNfgcmdIgPrInEUHMYGsk-SQZ-WxR0KWR_KI4." data-disable-popover="0">
                    <a rel="" href="/model/yummy-couple"  class="bolded">Yummy Couple</a>
                <div class="avatarPosition"></div>

                <a rel="" href="/pornstar/leolulu"  class="bolded">Leolulu</a>
        */



        var categoriesRegex = new RegExp("<div\\s+id=\"category-box\"\\s+class=\"suggest-mini-box\">(.+?)</ul>")
        var categoryRegex = new RegExp("<li>\\s*<button\\s+.*?data-categoryid=\"(\\d+)\".*?>\\s*</button>\\s*<button\\s+.*?>\\s*</button>([^<]+)</li>", "g")

//                <div class="pornstarsWrapper">
//                    Pornstars:&nbsp;
//                                                        <a class="pstar-list-btn js-mxp" data-mxptype="Pornstar" data-mxptext="Ada Sanchez" data-id="64801" data-login="1" href="/pornstar/ada-sanchez">Ada Sanchez				<span class="psbox-link-container display-none"></span>
//                            </a>
//                                        , 					<a class="pstar-list-btn js-mxp" data-mxptype="Pornstar" data-mxptext="Ralph Long" data-id="3401" data-login="1" href="/pornstar/ralph-long">Ralph Long				<span class="psbox-link-container display-none"></span>
//                            </a>
//                                                                <div class="tooltipTrig suggestBtn" data-title="Add a pornstar">
//                            <a class="add-btn-small add-pornstar-btn-2" >+ <span>Suggest</span></a>
//                        </div>

        var pornstarsRegex = new RegExp("<div\\s+class=\"pornstarsWrapper\">(.*?)</div>")
        var pornstarRegex = new RegExp("<a\\s+.*?data-mxptext=\"(.+?)\".+?href=\"(.+?)\".*?>.+?</a>", "g")


//                <div class="tagsWrapper">
//                               Tags:&nbsp;
//                               <a href="/video?c=7">big dick</a>, <a href="/video?c=26">latina</a>, <a href="/video/search?search=teengonzo">teengonzo</a>, <a href="/categories/teen">teen</a>, <a href="/video/search?search=hispanic">hispanic</a>, <a href="/video/search?search=thick">thick</a>, <a href="/video/search?search=chubby">chubby</a>, <a href="/video?c=8">big tits</a>, <a href="/video/search?search=cumshot">cumshot</a>, <a href="/video/search?search=facial">facial</a>, <a href="/categories/teen">teenager</a>, <a href="/video/search?search=young">young</a>, <a href="/video/search?search=latin">latin</a>, <a href="/video/search?search=big+boobs">big boobs</a>, <a href="/video/search?search=busty">busty</a>, <a href="/video/search?search=shaved">shaved</a>                <div class="tooltipTrig suggestBtn" data-title="Suggest Tags" >
//                                   <a id="tagLink" class="add-btn-small">+ <span>Suggest</span></a>
//                               </div>
//                           </div>

        var tagsRegex = new RegExp("<div\\s+class=\"tagsWrapper\">(.*?)</div>")
        var tagRegex = new RegExp("<a\\s+href=\"(.+?)\">([^<]+)</a>", "g")
        /*
          <li>                                         <button type="button" class="upVote" data-categoryid="7" data-suggestcategory-url="/video/rate_category?current=7&id=206039581&value=1&token=MTU1OTU5MDIzMIy2CCnncc2t9i9ewj0WDwtEEPYZdXWI7XWtzkSc7dPVbJ1_3cxidde9lAPjk7WVwvrP4KHt2iIRwcjlVC8Hy-o."></button>                                         <button type="button" class="downVote" data-categoryid="7" data-suggestcategory-url="/video/rate_category?current=7&id=206039581&value=0&token=MTU1OTU5MDIzMIy2CCnncc2t9i9ewj0WDwtEEPYZdXWI7XWtzkSc7dPVbJ1_3cxidde9lAPjk7WVwvrP4KHt2iIRwcjlVC8Hy-o."></button>                                         Big Dick                                    </li>
          */
        var hasFoundSessionInfo = false
        // WIDGET_RATINGS_LIKE_FAV.token = "MTU1NDM4MTkwNB_j3wXL9yAhG4cE4CAfoYXshRU63e1Q14DWT8QqCmcgcRjqdwcmutv0HXoEuUowLgHVkxptmjxQ3Ep60i8qbYc." </script>
        _ratingToken = ""
        _isFavorite = false
        _modelUrl = ""
        _modelName = ""
        _upVotes = -1
        _downVotes = -1
        _categories = []
        _pornstars = []
        _tags = []

        var oneline = data.replace(new RegExp("\r|\n", "g"), " ") // Qt doesn't have 's' flag to match newlines with .

        var categoriesMatch = categoriesRegex.exec(oneline)
        if (categoriesMatch) {
            var categoriesData = categoriesMatch[1]
//            console.debug(categoriesData)
            for (var categoryMatch; (categoryMatch = categoryRegex.exec(categoriesData)) !== null; ) {
                var categoryId = parseInt(categoryMatch[1])
                var category = {
                    category_id: categoryId,
                    category_title: categoryMatch[2].trim(),
                    category_url: Constants.baseUrl + "/video?c=" + categoryId,
                }

                _categories.push(category)
                console.debug("adding category id=" + category.category_id)
            }
        }

        var pornstarsMatch = pornstarsRegex.exec(oneline)
        if (pornstarsMatch) {
            var pornstarsData = pornstarsMatch[1]
            for (var pornstarMatch; (pornstarMatch = pornstarRegex.exec(pornstarsData)) !== null; ) {
                var pornstar = {
                    pornstar_name: pornstarMatch[1],
                    pornstar_url: Constants.baseUrl + pornstarMatch[2],
                }

                _pornstars.push(pornstar)
                console.debug("adding pornstar name=" + pornstar.pornstar_name)
            }
        }

        var tagsMatch = tagsRegex.exec(oneline)
        if (tagsMatch) {
            var tagsData = tagsMatch[1]
            for (var tagMatch; (tagMatch = tagRegex.exec(tagsData)) !== null; ) {
                var tag = {
                    tag_name: tagMatch[2].trim(),
                    tag_url: Constants.baseUrl + tagMatch[1],
                }

                _tags.push(tag)
                console.debug("adding tag name=" + tag.tag_name)
            }
        }


        var want = 5
        var lines = data.split('\n');
        for (var i = 0; i < lines.length && want > 0; ++i) {
            var videoFormatsMatch = videoFormatsRegex.exec(lines[i])
            if (videoFormatsMatch) {
                --want
                try {
                    //console.debug("JSON: " + jsonMatch[1])
                    var jsonObject = JSON.parse(videoFormatsMatch[1])
                    //console.debug(jsonMatch[1])
                    //console.debug(j)
                    var mediaDefinitions = jsonObject.mediaDefinitions
                    for (var j = 0; j < mediaDefinitions.length; ++j) {
                        var def = mediaDefinitions[j]
                        if (def.videoUrl) {
                            var format = {
                                format_quality: parseInt(def.quality),
                                format_url: def.videoUrl,
                                format_extension: def.format
                            }

                            formats.push(format)
                            console.debug("added quality=" + format.format_quality + " ext=" + format.format_extension + " url=" + format.format_url)
                        }
                    }

                    _formats = formats
                } catch (error) {
                    console.debug(error)
                }
            } else {
                var ratingsMatch = ratingRegex.exec(lines[i])
                if (ratingsMatch) {
                    --want
                    try {
                        console.debug("JSON: " + ratingsMatch[1])
                        var jsonObject = JSON.parse(ratingsMatch[1])

                        // jsonObject.canVote seems to always be set to 1
//                        if (jsonObject.canVote) {
//                            _canVote = true
//                        } else {
//                            _canVote = false
//                        }

                        //console.debug("canVote=" + _canVote)

                        // jsonObject.loggedIn appears to have login status

                        if (jsonObject.isFavourite === 1) {
                            _isFavorite = true
                        } else {
                            _isFavorite = false
                        }

                        console.debug("isFavorite=" + _isFavorite)

                        _upVotes = jsonObject.currentUp
                        _downVotes = jsonObject.currentDown
                        console.debug("upVotes=" + _upVotes + " downVotes=" + _downVotes)

                    } catch (error) {
                        console.debug(error)
                    }
                } else {
                    var tokenMatch = ratingTokenRegex.exec(lines[i])
                    if (tokenMatch) {
                        --want
                        _ratingToken = tokenMatch[1]
                        console.debug("rating token=" + _ratingToken)
                    } else {
                        if (!hasFoundSessionInfo && window.updateSessionLine(lines[i])) {
                            --want
                            hasFoundSessionInfo = true
                        }

                        var modelMatch = modelRegex.exec(lines[i])
                        if (modelMatch) {
                            --want
                            _modelUrl = modelMatch[1]
                            _modelName = modelMatch[2]
                            console.debug("model name=" + _modelName + " model url=" + _modelUrl)
                        }
                    }
                }
            }
        }

        if (window.isUserLoggedIn && !_ratingToken){
            console.debug(data)
        }
    }

    function _secondsToTimeString(n) {
        n = Math.round(n)
        var h = Math.floor(n / 3600)
        n = n - 3600 * h
        var m = Math.floor(n / 60)
        n = n - 60 * m
        var s = Math.floor(n)

        var result = ""
        if (h > 0) {
            result = (h < 10 ? ("0" + h.toString()) : h.toString()) + ":"
        }

        result = result + (m < 10 ? ("0" + m.toString()) : m.toString()) + ":"
        result = result + (s < 10 ? ("0" + s.toString()) : s.toString())
        return result
    }

    function _getVideoFormatFromBearerMode() {
        var formatId
        switch (settingBearerMode.value) {
        case Constants.bearerModeBroadband:
            console.debug("force broadband format selection")
            formatId = settingBroadbandDefaultFormat.value
            break
        case Constants.bearerModeMobile:
            console.debug("force mobile format selection")
            formatId = settingMobileDefaultFormat.value
            break
        default:
            if (App.isOnBroadband) {
                console.debug("use broadband format selection")
                formatId = settingBroadbandDefaultFormat.value
            } else if (App.isOnMobile) {
                console.debug("use mobile format selection")
                formatId = settingMobileDefaultFormat.value
            } else {
                console.debug("unknown bearer using mobile default format")
                formatId = settingMobileDefaultFormat.value
            }
            break
        }

        console.debug("format=" + formatId)

        return formatId
    }

    function _selectFormatIdFromHeight(height) {
        if (height <= 240) {
            return Constants.format240
        }

        if (height <= 480) {
            return Constants.format480
        }

        if (height <= 720) {
            return Constants.format720
        }

        if (height <= 1080) {
            return Constants.format1080
        }

        return Constants.formatUnknown
    }

    function _getAreaFromFormatQuality(q) {
        var targetArea = 1080*1920
        switch (q) {
        case 720:
            targetArea = 720*1280
            break
        case 480:
            targetArea = 480*640
            break
        case 240:
            targetArea = 240*320
            break
        }

        return targetArea
    }

    function _findBestFormat(formatId) {
        var formatIndex = -1
        if (Constants.formatWorst === formatId) {
            var best = _formats[0]
            formatIndex = 0
            for (var i = 1; i < _formats.length; ++i) {
                var f = _formats[i]
                if (f.format_quality < best.format_quality) {
                    best = f;
                    formatIndex = i;
                }
            }
        } else if (Constants.formatBest === formatId) {
            var best = _formats[0]
            formatIndex = 0
            for (var i = 1; i < _formats.length; ++i) {
                var f = _formats[i]
                if (f.format_quality > best.format_quality) {
                    best = f;
                    formatIndex = i;
                }
            }
        } else {
            // try to find exact match
            for (var i = 0; i < _formats.length; ++i) {
                var f = _formats[i]
                if (f.format_quality === formatId) {
                    formatIndex = i
                    break
                }
            }

            if (formatIndex === -1) {
                var targetArea = _getAreaFromFormatQuality(formatId)

                formatIndex = 0
                var f = _formats[0]
                var bestdelta = Math.abs(_getAreaFromFormatQuality(f.format_quality) - targetArea)
                for (var i = 1; i < _formats.length; ++i) {
                    f = _formats[i]
                    var delta = Math.abs(_getAreaFromFormatQuality(f.format_quality) - targetArea)
                    if (delta < bestdelta) {
                        bestdelta = delta;
                        formatIndex = i;
                    }
                }
            }
        }

        return formatIndex
    }
}

