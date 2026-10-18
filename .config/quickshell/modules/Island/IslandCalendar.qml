// The island's hover menu, opened by hovering the clock pill (see
// windows/Island.qml): the clock in the middle with the shown day's forecast
// orbiting it every third hour, the month grid on the left and the weather on
// the right, over slowly drifting glows tinted by the time of day and the
// weather. The arrows page through months and forecast days; the pill at the
// top-centre opens the widget grid.
//
// Ported from serpantinum's calendar popup (github.com/ilyamiro/serpantinum,
// src/quickshell/calendar/CalendarPopup.qml, AGPL-3.0) and adapted to this
// shell: colours, font and radii from Theme, weather from WeatherService
// instead of its weather.sh cache, the clock from the island's `now`, English
// strings instead of its i18n table, and no scaling (its Scaler.s() is the
// identity anyway). The island draws the card itself, so this draws only
// what is on it. Its Left/Right shortcuts are gone: the island never takes
// the keyboard while it is only hovered.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services"
import "../../components"

Item {
    id: root

    property date now: new Date()

    signal openMenu()

    implicitWidth: Theme.islandCalendarWidth
    implicitHeight: Theme.islandCalendarHeight

    // ── Time-of-day tints ───────────────────────────────────────────────────
    // Morning peach, afternoon sapphire, evening mauve, night blue; the accent
    // is the brighter partner of each, softened towards the text colour.
    readonly property color timeColor: {
        var h = root.now.getHours();
        if (h >= 5 && h < 12) return Theme.peach;
        if (h >= 12 && h < 17) return Theme.sapphire;
        if (h >= 17 && h < 21) return Theme.mauve;
        return Theme.blue;
    }

    readonly property color timeAccent: {
        var h = root.now.getHours();
        if (h >= 5 && h < 12) return Theme.yellow;
        if (h >= 12 && h < 17) return Theme.teal;
        if (h >= 17 && h < 21) return Theme.pink;
        return Theme.mauve;
    }

    readonly property color textAccent: Qt.tint(root.timeAccent, Qt.alpha(Theme.text, 0.35))

    // ── Intro ───────────────────────────────────────────────────────────────
    // Each part rises in on its own curve: the card, the ambient glows, the
    // clock, then the calendar and the weather from either side.
    property bool startupComplete: false
    property real introMain: 0
    property real introAmbient: 0
    property real introClock: 0
    property real introCalendar: 0
    property real introWeather: 0

    function resetAndPlayIntro() {
        exitAnim.stop();
        root.startupComplete = false;
        root.introMain = 0;
        root.introAmbient = 0;
        root.introClock = 0;
        root.introCalendar = 0;
        root.introWeather = 0;
        root.transitionSpin = 0.0;
        root.transitionScale = 1.0;
        root.weatherContentOpacity = 1.0;
        root.weatherContentOffset = 0.0;
        root.calendarContentOpacity = 1.0;
        root.calendarContentOffset = 0.0;
        introAnim.restart();
    }

    // The island flips `enabled` the moment the face is chosen or dropped and
    // fades the whole face itself; `visible` follows that fade.
    onEnabledChanged: {
        if (root.enabled) {
            root.updateCalendarGrid();
            WeatherService.refreshIfStale();
            root.resetAndPlayIntro();
        } else {
            introAnim.stop();
            exitAnim.start();
        }
    }

    // Faded out: settle any half-done page turn, so the next hover opens on
    // the page the arrows last asked for.
    onVisibleChanged: {
        if (root.visible) return;
        weatherTransitionAnim.stop();
        calendarTransitionAnim.stop();
        root.weatherView = root.targetWeatherView;
        root.monthOffset = root.targetMonthOffset;
        root.transitionSpin = 0.0;
        root.transitionScale = 1.0;
        root.weatherContentOpacity = 1.0;
        root.weatherContentOffset = 0.0;
        root.calendarContentOpacity = 1.0;
        root.calendarContentOffset = 0.0;
    }

    SequentialAnimation {
        id: introAnim

        PauseAnimation { duration: 20 }

        ParallelAnimation {
            NumberAnimation { target: root; property: "introMain"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutQuart }

            SequentialAnimation {
                PauseAnimation { duration: 150 }
                NumberAnimation { target: root; property: "introAmbient"; from: 0; to: 1.0; duration: 1000; easing.type: Easing.OutSine }
            }

            SequentialAnimation {
                PauseAnimation { duration: 250 }
                NumberAnimation { target: root; property: "introClock"; from: 0; to: 1.0; duration: 900; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }

            SequentialAnimation {
                PauseAnimation { duration: 350 }
                NumberAnimation { target: root; property: "introCalendar"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuint }
            }

            SequentialAnimation {
                PauseAnimation { duration: 400 }
                NumberAnimation { target: root; property: "introWeather"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuint }
            }
        }

        ScriptAction { script: root.startupComplete = true }
    }

    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: root; property: "introMain"; to: 0; duration: 400; easing.type: Easing.InQuart }
        NumberAnimation { target: root; property: "introAmbient"; to: 0; duration: 250; easing.type: Easing.InQuart }
        NumberAnimation { target: root; property: "introClock"; to: 0; duration: 300; easing.type: Easing.InQuart }
        NumberAnimation { target: root; property: "introCalendar"; to: 0; duration: 350; easing.type: Easing.InQuart }
        NumberAnimation { target: root; property: "introWeather"; to: 0; duration: 350; easing.type: Easing.InQuart }
    }

    // ── Clock ───────────────────────────────────────────────────────────────
    // The orbit drifts round once a minute for days other than today, today's
    // hours sway in place, and the clock gives a small pulse every second.
    property real globalOrbitOffset: 0
    NumberAnimation on globalOrbitOffset {
        from: 0; to: -360; duration: 60000; loops: Animation.Infinite; running: root.visible
    }

    property real globalOscPhase: 0
    NumberAnimation on globalOscPhase {
        from: 0; to: Math.PI * 2; duration: 9000; loops: Animation.Infinite; running: root.visible
    }

    property real secondPulse: 1.0
    NumberAnimation on secondPulse {
        id: pulseReset
        to: 1.0; duration: 600; easing.type: Easing.OutQuint; running: false
    }

    onNowChanged: {
        // A new day: today's highlight moves (checked on any tick, not just
        // 00:00:00, so a suspend over midnight can't skip it).
        if (root.now.getDate() !== root._gridDay)
            root.updateCalendarGrid();
        if (root.visible) {
            root.secondPulse = 1.02;
            pulseReset.start();
        }
    }

    // ── Weather ─────────────────────────────────────────────────────────────
    // `weatherView` is the forecast day on screen (0 = today); a page turn
    // sets `targetWeatherView` first and swaps the view halfway through.
    readonly property bool weatherReady: WeatherService.ready
    property int weatherView: 0
    property int targetWeatherView: 0

    function dayAt(i) {
        return root.weatherReady && i < WeatherService.daily.length ? WeatherService.daily[i] : null;
    }

    readonly property var shownDay: root.dayAt(root.weatherView)
    readonly property var targetDay: root.dayAt(root.targetWeatherView)

    // Today shows what it is like right now; any other day its own forecast.
    readonly property color activeWeatherHex: {
        if (!root.weatherReady) return Theme.mauve;
        if (root.weatherView === 0)
            return WeatherService.codeColor(WeatherService.current.code, WeatherService.current.isDay);
        return root.shownDay ? WeatherService.codeColor(root.shownDay.code, true) : Theme.mauve;
    }

    readonly property string activeWeatherIcon: {
        if (!root.weatherReady) return "";
        if (root.weatherView === 0)
            return WeatherService.codeInfo(WeatherService.current.code, WeatherService.current.isDay).glyph;
        return root.shownDay ? WeatherService.codeInfo(root.shownDay.code, true).glyph : "";
    }

    property real weatherContentOpacity: 1.0
    property real weatherContentOffset: 0.0
    property int weatherAnimDirection: 1

    property real transitionSpin: 0.0
    property real transitionScale: 1.0

    readonly property real targetTemp: {
        if (!root.weatherReady) return 0;
        if (root.targetWeatherView === 0) return WeatherService.current.temp;
        return root.targetDay ? root.targetDay.tmax : 0;
    }

    // Counts up or down to the new temperature, glowing red or blue on the
    // way.
    property real displayedTemp: targetTemp

    Behavior on displayedTemp {
        NumberAnimation {
            id: tempAnim
            duration: 800
            easing.type: Easing.OutQuart
        }
    }

    readonly property bool isTempAnimating: tempAnim.running
    readonly property color tempGlowColor: {
        if (!root.isTempAnimating || !root.startupComplete) return Theme.text;
        if (root.targetTemp > root.displayedTemp) return Theme.red;
        if (root.targetTemp < root.displayedTemp) return Theme.blue;
        return Theme.text;
    }

    SequentialAnimation {
        id: weatherTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "weatherContentOpacity"; to: 0.0; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: root; property: "weatherContentOffset"; to: -40 * root.weatherAnimDirection; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: root; property: "transitionSpin"; to: 180 * root.weatherAnimDirection; duration: 300; easing.type: Easing.InBack }
            NumberAnimation { target: root; property: "transitionScale"; to: 0.8; duration: 300; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                root.weatherView = root.targetWeatherView;
                root.weatherContentOffset = 40 * root.weatherAnimDirection;
                root.transitionSpin = -180 * root.weatherAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "weatherContentOpacity"; to: 1.0; duration: 450; easing.type: Easing.OutQuart }
            NumberAnimation { target: root; property: "weatherContentOffset"; to: 0.0; duration: 450; easing.type: Easing.OutQuart }
            NumberAnimation { target: root; property: "transitionSpin"; to: 0.0; duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: root; property: "transitionScale"; to: 1.0; duration: 500; easing.type: Easing.OutBack }
        }
    }

    function setWeatherView(idx) {
        if (!root.weatherReady || idx < 0 || idx >= WeatherService.daily.length) return;
        if (idx === root.targetWeatherView) return;

        if (weatherTransitionAnim.running) {
            weatherTransitionAnim.stop();
            root.weatherView = root.targetWeatherView;
            root.transitionSpin = 0.0;
            root.transitionScale = 1.0;
            root.weatherContentOpacity = 1.0;
            root.weatherContentOffset = 0.0;
        }

        root.weatherAnimDirection = idx > root.weatherView ? 1 : -1;
        root.targetWeatherView = idx;
        weatherTransitionAnim.start();
    }

    // Today's slot nearest the current hour: it sits at the front of the
    // orbit, highlighted, with the earlier and later ones either side.
    readonly property int activeHourIndex: {
        if (root.weatherView !== 0 || !root.shownDay) return -1;
        var hours = root.shownDay.hourly;
        var h = root.now.getHours();
        var best = 0;
        for (var i = 1; i < hours.length; i++)
            if (Math.abs(hours[i].hour - h) < Math.abs(hours[best].hour - h)) best = i;
        return best;
    }

    // ── Calendar ────────────────────────────────────────────────────────────
    // Six weeks from the Monday on or before the 1st. `monthOffset` is the
    // month on screen relative to this one; page turns go through
    // `targetMonthOffset` like the weather's.
    property int monthOffset: 0
    property int targetMonthOffset: 0
    property string targetMonthName: ""
    // 42 × { dayNum, isCurrentMonth, isToday }
    property var calendarDays: []
    // The day of the month the grid was built on, to spot midnight.
    property int _gridDay: -1

    property real calendarContentOpacity: 1.0
    property real calendarContentOffset: 0.0
    property int calendarAnimDirection: 1

    SequentialAnimation {
        id: calendarTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "calendarContentOpacity"; to: 0.0; duration: 200; easing.type: Easing.InSine }
            NumberAnimation { target: root; property: "calendarContentOffset"; to: -20 * root.calendarAnimDirection; duration: 200; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                root.monthOffset = root.targetMonthOffset;
                root.calendarContentOffset = 20 * root.calendarAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "calendarContentOpacity"; to: 1.0; duration: 350; easing.type: Easing.OutQuart }
            NumberAnimation { target: root; property: "calendarContentOffset"; to: 0.0; duration: 350; easing.type: Easing.OutQuart }
        }
    }

    function setMonthOffset(newOffset) {
        if (newOffset === root.targetMonthOffset) return;

        if (calendarTransitionAnim.running) {
            calendarTransitionAnim.stop();
            root.monthOffset = root.targetMonthOffset;
            root.calendarContentOpacity = 1.0;
            root.calendarContentOffset = 0.0;
        }

        root.calendarAnimDirection = newOffset > root.targetMonthOffset ? 1 : -1;
        root.targetMonthOffset = newOffset;
        calendarTransitionAnim.start();
    }

    function updateCalendarGrid() {
        var today = new Date();
        var d = new Date(today.getFullYear(), today.getMonth() + root.monthOffset, 1);
        var month = d.getMonth();
        var year = d.getFullYear();
        var isThisMonth = today.getMonth() === month && today.getFullYear() === year;

        root.targetMonthName = Qt.formatDate(d, "MMMM yyyy");

        // Monday first.
        var firstDay = (d.getDay() + 6) % 7;
        var daysInMonth = new Date(year, month + 1, 0).getDate();
        var daysInPrevMonth = new Date(year, month, 0).getDate();

        var out = [];
        for (var i = firstDay - 1; i >= 0; i--)
            out.push({ dayNum: String(daysInPrevMonth - i), isCurrentMonth: false, isToday: false });
        for (var j = 1; j <= daysInMonth; j++)
            out.push({ dayNum: String(j), isCurrentMonth: true, isToday: isThisMonth && j === today.getDate() });
        for (var k = 1; out.length < 42; k++)
            out.push({ dayNum: String(k), isCurrentMonth: false, isToday: false });

        root.calendarDays = out;
        root._gridDay = today.getDate();
    }

    onMonthOffsetChanged: updateCalendarGrid()

    Component.onCompleted: updateCalendarGrid()

    // ── Content ─────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        scale: 0.95 + 0.05 * root.introMain
        opacity: root.introMain

        // Ambient glows: three faint blobs drifting on long loops, tinted by
        // the weather, the time of day and its accent.
        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                width: parent.width * 0.5; height: width; radius: width / 2
                x: parent.width * 0.75 - width / 2
                y: parent.height * 0.3 - height / 2
                opacity: 0.012 * root.introAmbient
                color: root.activeWeatherHex
                Behavior on color { ColorAnimation { duration: 1000 } }

                transform: Translate {
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: root.visible
                        NumberAnimation { from: 350; to: -350; duration: 30000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: -350; to: 350; duration: 30000; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: root.visible
                        NumberAnimation { from: 0; to: 200; duration: 15000; easing.type: Easing.OutSine }
                        NumberAnimation { from: 200; to: -200; duration: 30000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: -200; to: 0; duration: 15000; easing.type: Easing.InSine }
                    }
                }
            }

            Rectangle {
                width: parent.width * 0.6; height: width; radius: width / 2
                x: parent.width * 0.25 - width / 2
                y: parent.height * 0.7 - height / 2
                opacity: 0.01 * root.introAmbient
                color: root.timeColor
                Behavior on color { ColorAnimation { duration: 1000 } }

                transform: Translate {
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: root.visible
                        NumberAnimation { from: 0; to: -300; duration: 18750; easing.type: Easing.OutSine }
                        NumberAnimation { from: -300; to: 300; duration: 37500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 300; to: 0; duration: 18750; easing.type: Easing.InSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: root.visible
                        NumberAnimation { from: -250; to: 250; duration: 37500; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 250; to: -250; duration: 37500; easing.type: Easing.InOutSine }
                    }
                }
            }

            Rectangle {
                width: parent.width * 0.45; height: width; radius: width / 2
                x: parent.width * 0.5 - width / 2
                y: parent.height * 0.5 - height / 2
                opacity: 0.007 * root.introAmbient
                color: root.timeAccent
                Behavior on color { ColorAnimation { duration: 1000 } }

                transform: Translate {
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        running: root.visible
                        NumberAnimation { from: 400; to: -400; duration: 25000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: -400; to: 400; duration: 25000; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: root.visible
                        NumberAnimation { from: 0; to: -350; duration: 12500; easing.type: Easing.OutSine }
                        NumberAnimation { from: -350; to: 350; duration: 25000; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 350; to: 0; duration: 12500; easing.type: Easing.InSine }
                    }
                }
            }

            // The weather's glyph, huge and barely there, behind the clock.
            Text {
                anchors.centerIn: parent
                text: root.activeWeatherIcon
                font.family: Theme.fontFamily
                font.pixelSize: 520
                color: root.activeWeatherHex
                Behavior on color { ColorAnimation { duration: 1500 } }

                opacity: 0.015 * breathe * root.introAmbient * root.weatherContentOpacity
                property real breathe: 1.0
                SequentialAnimation on breathe {
                    loops: Animation.Infinite
                    running: root.visible
                    NumberAnimation { from: 1.0; to: 1.2; duration: 5625; easing.type: Easing.OutSine }
                    NumberAnimation { from: 1.2; to: 0.8; duration: 11250; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.8; to: 1.0; duration: 5625; easing.type: Easing.InSine }
                }

                transform: [
                    Translate {
                        SequentialAnimation on y {
                            loops: Animation.Infinite
                            running: root.visible
                            NumberAnimation { to: -8; duration: 6000; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutSine }
                        }
                    },
                    Translate { x: root.weatherContentOffset * 2 }
                ]
            }
        }

        // ── Menu pill ───────────────────────────────────────────────────────
        // Top-centre: open the widget grid.
        Rectangle {
            id: menuBtn

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 14
            z: 20
            width: row.implicitWidth + 26
            height: 28
            radius: height / 2
            color: menuHover.hovered ? Theme.hover : Theme.surface

            Behavior on color {
                ColorAnimation { duration: Theme.animFast }
            }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 6

                CenteredIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    size: 11
                    color: Theme.subtext0
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Menu"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            HoverHandler {
                id: menuHover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.openMenu()
            }
        }

        // ── Central hub: clock + orbit ──────────────────────────────────────
        // A 1×1 anchor at the centre; everything orbits it. It floats and
        // tilts gently on three axes the whole time it is up.
        Item {
            id: centralHub
            anchors.centerIn: parent
            width: 1
            height: 1
            z: 5

            opacity: root.introClock
            scale: 0.85 + 0.15 * root.introClock

            transform: [
                Translate { y: 25 * (1.0 - root.introClock) },
                Translate {
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: root.visible
                        NumberAnimation { to: -6; duration: 4500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 4500; easing.type: Easing.InOutSine }
                    }
                },
                Rotation {
                    axis { x: 1; y: 0; z: 0 }
                    SequentialAnimation on angle {
                        loops: Animation.Infinite; running: root.visible
                        NumberAnimation { to: 1.5; duration: 4800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: -1.5; duration: 4800; easing.type: Easing.InOutSine }
                    }
                },
                Rotation {
                    axis { x: 0; y: 1; z: 0 }
                    SequentialAnimation on angle {
                        loops: Animation.Infinite; running: root.visible
                        NumberAnimation { to: 1.2; duration: 5500; easing.type: Easing.InOutSine }
                        NumberAnimation { to: -1.2; duration: 5500; easing.type: Easing.InOutSine }
                    }
                },
                Rotation {
                    axis { x: 0; y: 0; z: 1 }
                    SequentialAnimation on angle {
                        loops: Animation.Infinite; running: root.visible
                        NumberAnimation { to: 0.8; duration: 6200; easing.type: Easing.InOutSine }
                        NumberAnimation { to: -0.8; duration: 6200; easing.type: Easing.InOutSine }
                    }
                }
            ]

            // The dashed ellipse the hours ride on.
            Canvas {
                id: orbitCanvas
                z: -10
                anchors.centerIn: parent
                width: 680
                height: 320
                opacity: 0.35

                property color stroke: Qt.alpha(root.textAccent, 0.45)
                onStrokeChanged: requestPaint()

                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: root.visible
                    NumberAnimation { to: 1.012; duration: 4000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 4000; easing.type: Easing.InOutSine }
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.beginPath();
                    for (var i = 0; i <= Math.PI * 2; i += 0.05) {
                        var xx = width / 2 + Math.cos(i) * 268;
                        var yy = height / 2 + Math.sin(i) * 124;
                        if (i === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
                    }
                    ctx.strokeStyle = orbitCanvas.stroke;
                    ctx.lineWidth = 2;
                    ctx.lineCap = "round";
                    ctx.setLineDash([4, 12]);
                    ctx.stroke();
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                scale: 0.98 + 0.02 * root.secondPulse

                Text {
                    id: clockText
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(root.now, "HH:mm:ss")
                    font.family: Theme.fontFamily
                    font.weight: Font.Black
                    // 84px for HH:mm, shrinking as the string grows.
                    font.pixelSize: {
                        var len = clockText.text.length;
                        if (len <= 5) return 84;
                        return Math.round(Math.max(36, 84 * Math.min(1.0, Math.pow(5 / len, 0.7))));
                    }
                    color: Theme.text
                    style: Text.Outline
                    styleColor: Qt.alpha(Theme.crust, 0.4)
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(root.now, "dddd, MMMM dd")
                    font.family: Theme.fontFamily
                    font.weight: Font.Bold
                    font.pixelSize: 16
                    color: Theme.subtext0
                    opacity: 0.9
                }
            }

            // The shown day's hours. Today's are laid out from the current
            // slot, which sits at the front, and sway; another day's spread
            // evenly and drift round the orbit.
            Item {
                anchors.fill: parent
                opacity: root.weatherContentOpacity
                scale: root.transitionScale
                transform: Translate { x: root.weatherContentOffset * 1.5 }

                Repeater {
                    id: hourRepeater
                    model: root.shownDay ? root.shownDay.hourly : []

                    delegate: Item {
                        id: hourCard

                        required property var modelData
                        required property int index

                        readonly property bool isToday: root.weatherView === 0
                        readonly property bool isHighlighted: isToday && index === root.activeHourIndex

                        readonly property real rx: 268 * orbitCanvas.scale
                        readonly property real ry: 124 * orbitCanvas.scale

                        readonly property int relIdx: isToday ? index - root.activeHourIndex : index
                        readonly property real targetAngleDeg: isToday ? 65 + relIdx * 30
                                                                       : index * (360 / Math.max(1, hourRepeater.count))
                        readonly property real orbitOffset: isToday ? 0 : root.globalOrbitOffset
                        readonly property real osc: isToday ? Math.sin(root.globalOscPhase + index) * 2.5 : 0
                        readonly property real rad: (targetAngleDeg + orbitOffset + osc + root.transitionSpin) * (Math.PI / 180)

                        // 0 at the back of the orbit, 1 at the front.
                        readonly property real depthFactor: (Math.sin(rad) + 1.0) / 2.0

                        x: Math.cos(rad) * rx - width / 2
                        y: Math.sin(rad) * ry - height / 2
                        z: Math.sin(rad) * 100 + (isHighlighted ? 10 : 0)

                        readonly property real baseScale: isHighlighted ? 0.80 + 0.55 * depthFactor : 0.68 + 0.42 * depthFactor
                        property real hoverScale: hrMa.containsMouse && !isHighlighted ? 1.04 : 1.0
                        Behavior on hoverScale { NumberAnimation { duration: 150 } }

                        scale: baseScale * hoverScale
                        opacity: isHighlighted ? 0.75 + 0.25 * depthFactor : 0.55 + 0.45 * depthFactor

                        width: 52
                        height: 86

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.min(26, Theme.cornerRadiusSmall * 1.75)
                            color: hourCard.isHighlighted ? root.textAccent
                                 : hrMa.containsMouse ? Qt.lighter(Theme.surface0, 1.12)
                                 : Theme.surface0
                            border.color: hourCard.isHighlighted ? Qt.lighter(root.textAccent, 1.1)
                                        : hrMa.containsMouse ? Qt.alpha(Theme.surface2, 0.9)
                                        : Qt.alpha(Theme.surface1, 0.6)
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 180 } }
                            Behavior on border.color { ColorAnimation { duration: 180 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 3

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: (hourCard.modelData.hour < 10 ? "0" : "") + hourCard.modelData.hour + ":00"
                                    font.family: Theme.fontFamily
                                    font.weight: Font.Bold
                                    font.pixelSize: 11
                                    color: hourCard.isHighlighted ? Theme.base
                                         : hrMa.containsMouse ? Theme.text
                                         : Theme.overlay1
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: WeatherService.codeInfo(hourCard.modelData.code, hourCard.modelData.isDay).glyph
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 16
                                    color: hourCard.isHighlighted ? Theme.base
                                         : WeatherService.codeColor(hourCard.modelData.code, hourCard.modelData.isDay)
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: hourCard.modelData.temp.toFixed(1) + "°"
                                    font.family: Theme.fontFamily
                                    font.weight: Font.Black
                                    font.pixelSize: 12
                                    color: hourCard.isHighlighted ? Theme.base : Theme.text
                                }
                            }
                        }

                        MouseArea {
                            id: hrMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }

        // ── Left: the month grid ────────────────────────────────────────────
        Rectangle {
            id: calendarRect
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 40
            width: 310
            height: 350
            color: Qt.alpha(Theme.surface0, 0.2)
            radius: Theme.cornerRadiusSmall
            border.color: Qt.alpha(Theme.surface1, 0.4)
            border.width: 1
            z: 10

            opacity: root.introCalendar
            transform: Translate { x: -40 * (1.0 - root.introCalendar) }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 14

                    // Back to this month; only there once you've left it.
                    CalendarIconButton {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        size: 28
                        cornerRadius: 8
                        buttonIcon: "\u{f00ed}"
                        iconFontSize: 14
                        accentColor: Theme.surface0
                        textColor: Theme.text
                        opacity: root.targetMonthOffset !== 0 ? 1.0 : 0.0
                        visible: opacity > 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        onClicked: if (root.targetMonthOffset !== 0) root.setMonthOffset(0)
                    }

                    CalendarIconButton {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        size: 28
                        cornerRadius: 8
                        buttonIcon: ""
                        iconFontSize: 14
                        accentColor: Theme.surface0
                        textColor: Theme.text
                        onClicked: root.setMonthOffset(root.targetMonthOffset - 1)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.targetMonthName.toUpperCase()
                        font.family: Theme.fontFamily
                        font.weight: Font.Black
                        font.pixelSize: 14
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 8
                        color: Theme.text
                        horizontalAlignment: Text.AlignHCenter

                        opacity: root.calendarContentOpacity
                        transform: Translate { x: root.calendarContentOffset }
                    }

                    CalendarIconButton {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        size: 28
                        cornerRadius: 8
                        buttonIcon: ""
                        iconFontSize: 14
                        accentColor: Theme.surface0
                        textColor: Theme.text
                        onClicked: root.setMonthOffset(root.targetMonthOffset + 1)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 4

                    Repeater {
                        model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

                        delegate: Text {
                            required property string modelData

                            Layout.fillWidth: true
                            text: modelData
                            font.family: Theme.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: 11
                            color: Theme.overlay0
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rowSpacing: 2
                    columnSpacing: 3

                    opacity: root.calendarContentOpacity
                    transform: Translate { x: root.calendarContentOffset }

                    Repeater {
                        model: root.calendarDays

                        delegate: CalendarButton {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            enabled: false
                            buttonText: modelData.dayNum
                            textFontSize: 11
                            cornerRadius: 5
                            horizontalPadding: 0
                            accentColor: modelData.isToday ? root.textAccent : "transparent"
                            textColor: modelData.isToday ? Theme.base
                                     : modelData.isCurrentMonth ? Theme.text
                                     : Theme.surface0
                        }
                    }
                }
            }
        }

        // ── Right: the weather ──────────────────────────────────────────────
        Item {
            id: weatherContainer
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 40
            width: 320
            height: 430
            z: 10

            opacity: root.introWeather
            transform: Translate { x: 40 * (1.0 - root.introWeather) }

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight | Qt.AlignTop
                    spacing: 14

                    CalendarIconButton {
                        id: prevDay
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        size: 28
                        cornerRadius: 8
                        buttonIcon: ""
                        iconFontSize: 12
                        accentColor: Theme.surface0
                        textColor: prevDay.isHoveredOrHighlighted ? root.textAccent : Theme.overlay1
                        onClicked: root.setWeatherView(root.targetWeatherView - 1)
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.shownDay ? Qt.formatDate(root.shownDay.date, "dddd").toUpperCase() : "Loading..."
                        font.family: Theme.fontFamily
                        font.weight: Font.Black
                        font.pixelSize: 15
                        fontSizeMode: Text.Fit
                        minimumPixelSize: 8
                        color: Theme.text
                    }

                    CalendarIconButton {
                        id: nextDay
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        size: 28
                        cornerRadius: 8
                        buttonIcon: ""
                        iconFontSize: 12
                        accentColor: Theme.surface0
                        textColor: nextDay.isHoveredOrHighlighted ? root.textAccent : Theme.overlay1
                        onClicked: root.setWeatherView(root.targetWeatherView + 1)
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 0

                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: (root.weatherReady ? root.displayedTemp.toFixed(1) : "--") + "°C"
                        font.family: Theme.fontFamily
                        font.weight: Font.Black
                        font.pixelSize: 68
                        color: root.tempGlowColor
                        style: Text.Outline
                        styleColor: root.isTempAnimating ? Qt.alpha(root.tempGlowColor, 0.5) : Qt.alpha(Theme.crust, 0.4)

                        Behavior on color { ColorAnimation { duration: 300 } }
                        Behavior on styleColor { ColorAnimation { duration: 300 } }
                    }

                    Text {
                        Layout.alignment: Qt.AlignRight
                        Layout.maximumWidth: 320
                        horizontalAlignment: Text.AlignRight
                        text: WeatherService.place
                        font.family: Theme.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: 14
                        color: Theme.text
                        elide: Text.ElideRight
                        visible: text !== ""
                    }

                    Text {
                        Layout.alignment: Qt.AlignRight
                        Layout.maximumWidth: 320
                        Layout.topMargin: 4
                        horizontalAlignment: Text.AlignRight
                        text: root.shownDay ? WeatherService.codeInfo(root.shownDay.code, true).label : ""
                        font.family: Theme.fontFamily
                        font.weight: Font.Medium
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                        color: root.textAccent
                        Behavior on color { ColorAnimation { duration: 1000 } }

                        opacity: root.weatherContentOpacity
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }

                Item { Layout.fillHeight: true }

                // Wind, humidity, chance of rain and feels-like for the day
                // being turned to.
                GridLayout {
                    Layout.alignment: Qt.AlignRight | Qt.AlignBottom
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: [
                            { glyph: "", label: "Wind" },
                            { glyph: "", label: "Humid" },
                            { glyph: "", label: "Rain" },
                            { glyph: "", label: "Feels" }
                        ]

                        delegate: CalendarButton {
                            id: chip

                            required property var modelData
                            required property int index

                            readonly property var day: root.targetDay

                            Layout.preferredWidth: 118
                            Layout.preferredHeight: 42
                            cornerRadius: 9
                            horizontalPadding: 8

                            buttonIcon: modelData.glyph
                            buttonText: !chip.day ? "--"
                                      : index === 0 ? chip.day.wind + " km/h"
                                      : index === 1 ? chip.day.humidity + "%"
                                      : index === 2 ? chip.day.precip + "%"
                                      : chip.day.feels.toFixed(1) + "°"
                            subText: modelData.label

                            iconFontSize: 14
                            textFontSize: 11

                            accentColor: Theme.surface0
                            textColor: chip.isHoveredOrHighlighted ? root.textAccent : Theme.overlay0
                        }
                    }
                }
            }
        }
    }
}
