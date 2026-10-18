// Weather: current conditions and a 7-day forecast, every third hour of it
// included, from open-meteo (free, no API key, no account). The location is resolved once from the machine's
// public IP — ipwho.is, falling back to ipapi.co — and reused for every
// refresh, so there is nothing to configure.
//
// The payloads are one small JSON document each, so they come straight over
// curl in a Process like the other services — no script, no cache files.
pragma Singleton
import QtQuick
import Quickshell.Io
import "../theme"

QtObject {
    id: root

    // ── State ────────────────────────────────────────────────────────────────
    property bool   located: false
    property real   latitude: 0
    property real   longitude: 0
    property string place: ""

    // { temp, feels, humidity, wind, code, isDay } for right now, or null.
    property var current: null
    // 7 × { date, code, tmax, tmin, feels, precip, wind, humidity, hourly },
    // today first. Temperatures are rounded to a tenth and the rest to whole
    // numbers — nothing downstream should have to do arithmetic. `feels` and
    // `wind` are the day's highs, `humidity` its mean; wind is in km/h.
    // `hourly` is every third hour of that day: 8 × { hour, temp, code, isDay }.
    property var daily: []

    readonly property bool ready: current !== null && daily.length > 0

    // When the last forecast landed (ms since the epoch), 0 before then.
    property real fetchedAt: 0

    // ── Fetching ─────────────────────────────────────────────────────────────
    function refresh() {
        if (!root.located || _fetch.running) return;
        _fetch.running = true;
    }

    // For views that want fresh numbers when they open: the 20-minute timer
    // can lag behind, e.g. after a suspend.
    function refreshIfStale() {
        if (Date.now() - root.fetchedAt > 900000) root.refresh();
    }

    function _locate() {
        if (!_geo.running) _geo.running = true;
    }

    Component.onCompleted: _locate()

    // ipwho.is answers { success, latitude, longitude, city }; ipapi.co
    // (the fallback) { latitude, longitude, city }. `last` marks the fallback,
    // so a failure there just waits for the retry timer.
    function _parseGeo(raw, last) {
        try {
            var o = JSON.parse(raw);
            var lat = o.latitude !== undefined ? o.latitude : o.lat;
            var lon = o.longitude !== undefined ? o.longitude : o.lon;
            if (typeof lat !== "number" || typeof lon !== "number") throw "no coords";
            if (o.success === false) throw "lookup failed";
            root.latitude = lat;
            root.longitude = lon;
            root.place = o.city || o.region || "";
            root.located = true;
            root.refresh();
        } catch (e) {
            if (!last) _geoFallback.running = true;
        }
    }

    function _parseWeather(raw) {
        try {
            var o = JSON.parse(raw);
            var c = o.current;
            root.current = {
                temp:  root._tenth(c.temperature_2m),
                feels: c.apparent_temperature,
                humidity: c.relative_humidity_2m,
                wind:  c.wind_speed_10m,
                code:  c.weather_code,
                isDay: c.is_day === 1
            };

            var d = o.daily, h = o.hourly, out = [];
            for (var i = 0; i < d.time.length; i++) {
                // "2026-10-07" split by hand: Date() would parse it as UTC.
                var p = d.time[i].split("-");

                // The hourly arrays are local time, 24 entries per day.
                var hourly = [];
                for (var k = 0; k < 24; k += 3) {
                    var j = i * 24 + k;
                    if (j >= h.time.length) break;
                    hourly.push({
                        hour:  k,
                        temp:  root._tenth(h.temperature_2m[j]),
                        code:  h.weather_code[j],
                        isDay: h.is_day[j] === 1
                    });
                }

                out.push({
                    date:  new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2])),
                    code:  d.weather_code[i],
                    tmax:  root._tenth(d.temperature_2m_max[i]),
                    tmin:  root._tenth(d.temperature_2m_min[i]),
                    feels: root._tenth(d.apparent_temperature_max[i]),
                    precip: d.precipitation_probability_max[i],
                    wind:  Math.round(d.wind_speed_10m_max[i]),
                    humidity: Math.round(d.relative_humidity_2m_mean[i]),
                    hourly: hourly
                });
            }
            root.daily = out;
            root.fetchedAt = Date.now();
        } catch (e) {
            // Leave the previous data in place; the refresh timer retries.
        }
    }

    function _tenth(v) {
        return Math.round(v * 10) / 10;
    }

    // ── Presentation ─────────────────────────────────────────────────────────
    // WMO weather interpretation codes → label + a Nerd Font glyph. Escapes,
    // not literal glyphs: every codepoint below was checked against the
    // installed JetBrainsMono Nerd Font (f185/f186/eeef/eef0/f0c2/ef1c/
    // ef1d/f2dc/ef2c).
    function codeInfo(code, isDay) {
        var night = !isDay;
        if (code === 0) return { label: "Clear", glyph: night ? "\uf186" : "\uf185" };
        if (code === 1) return { label: "Mostly clear", glyph: night ? "\uf186" : "\uf185" };
        if (code === 2) return { label: "Partly cloudy", glyph: night ? "\ueeef" : "\ueef0" };
        if (code === 3) return { label: "Overcast", glyph: "\uf0c2" };
        if (code === 45 || code === 48) return { label: "Fog", glyph: "\uf0c2" };
        if (code >= 51 && code <= 57) return { label: "Drizzle", glyph: "\uef1c" };
        if (code === 61) return { label: "Light rain", glyph: "\uef1c" };
        if (code === 63) return { label: "Rain", glyph: "\uef1c" };
        if (code === 65) return { label: "Heavy rain", glyph: "\uef1d" };
        if (code === 66 || code === 67) return { label: "Freezing rain", glyph: "\uef1c" };
        if (code >= 71 && code <= 77) return { label: "Snow", glyph: "\uf2dc" };
        if (code === 80 || code === 81) return { label: "Showers", glyph: "\uef1c" };
        if (code === 82) return { label: "Heavy showers", glyph: "\uef1d" };
        if (code === 85 || code === 86) return { label: "Snow showers", glyph: "\uf2dc" };
        if (code === 95) return { label: "Thunderstorm", glyph: "\uef2c" };
        if (code === 96 || code === 99) return { label: "Thunderstorm, hail", glyph: "\uef2c" };
        return { label: "", glyph: "\uf0c2" };
    }

    // The colour a condition is drawn in, from the palette: sun yellow, a
    // clear night mauve, cloud grey, fog and rain blue, snow white, storms
    // yellow again.
    function codeColor(code, isDay) {
        if (code === 0) return isDay ? Theme.yellow : Theme.mauve;
        if (code >= 1 && code <= 3) return Theme.subtext1;
        if (code === 45 || code === 48) return Theme.blue;
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return Theme.sapphire;
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return Theme.text;
        if (code >= 95) return Theme.yellow;
        return Theme.text;
    }

    // ── Processes ────────────────────────────────────────────────────────────
    property Process _geo: Process {
        command: ["curl", "-sS", "--max-time", "8", "https://ipwho.is/"]
        stdout: StdioCollector { onStreamFinished: root._parseGeo(text, false) }
    }

    property Process _geoFallback: Process {
        command: ["curl", "-sS", "--max-time", "8", "https://ipapi.co/json/"]
        stdout: StdioCollector { onStreamFinished: root._parseGeo(text, true) }
    }

    property Process _fetch: Process {
        command: [
            "curl", "-sS", "--max-time", "10",
            "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + root.latitude + "&longitude=" + root.longitude
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,"
            + "apparent_temperature_max,wind_speed_10m_max,relative_humidity_2m_mean"
            + "&hourly=temperature_2m,weather_code,is_day"
            + "&timezone=auto&forecast_days=7"
        ]
        stdout: StdioCollector { onStreamFinished: root._parseWeather(text) }
    }

    // ── Timers ───────────────────────────────────────────────────────────────
    // The first attempt may race the network coming up; keep trying until the
    // location lands.
    property Timer _geoRetry: Timer {
        interval: 300000
        repeat: true
        running: !root.located
        onTriggered: root._locate()
    }

    // Weather moves slowly; 20 minutes is plenty and stays well under the
    // free tier's limits.
    property Timer _refresh: Timer {
        interval: 1200000
        repeat: true
        running: root.located
        onTriggered: root.refresh()
    }
}
