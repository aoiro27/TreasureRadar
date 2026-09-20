import Foundation
import Testing
@testable import TreasureRadar

struct ProximityMapperTests {
    @Test func accuracyMapsImmediateNearMidAndFar() {
        #expect(ProximityMapper.proximity(accuracyMeters: 0.3, rssi: -90) == .immediate)
        #expect(ProximityMapper.proximity(accuracyMeters: 1.5, rssi: -90) == .near)
        #expect(ProximityMapper.proximity(accuracyMeters: 5.0, rssi: -90) == .mid)
        #expect(ProximityMapper.proximity(accuracyMeters: 12.0, rssi: -40) == .far)
    }

    @Test func unknownAccuracyFallsBackToRSSI() {
        #expect(ProximityMapper.proximity(accuracyMeters: nil, rssi: -30) == .immediate)
        #expect(ProximityMapper.proximity(accuracyMeters: nil, rssi: -55) == .near)
        #expect(ProximityMapper.proximity(accuracyMeters: nil, rssi: -70) == .mid)
        #expect(ProximityMapper.proximity(accuracyMeters: nil, rssi: -90) == .far)
        #expect(ProximityMapper.proximity(accuracyMeters: nil, rssi: 127) == .unknown)
        #expect(ProximityMapper.proximity(accuracyMeters: nil, rssi: 0) == .unknown)
    }

    @Test func radarRadiusMovesTowardCenterWhenCloser() {
        let close = ProximityMapper.radarRadius(accuracyMeters: 0.5, rssi: -40)
        let far = ProximityMapper.radarRadius(accuracyMeters: 16, rssi: -95)
        #expect(close < far)
        #expect(close >= 0.08)
        #expect(far <= 1)
    }

    @Test func beepGetsFasterAsTreasureGetsCloser() {
        #expect(ProximityMapper.beepInterval(for: .immediate) < ProximityMapper.beepInterval(for: .near))
        #expect(ProximityMapper.beepInterval(for: .near) < ProximityMapper.beepInterval(for: .mid))
        #expect(ProximityMapper.beepInterval(for: .mid) < ProximityMapper.beepInterval(for: .far))
        #expect(ProximityMapper.pingFrequency(for: .immediate) > ProximityMapper.pingFrequency(for: .far))
    }

    @Test func stableAngleIsDeterministic() {
        let first = ProximityMapper.stableAngle(for: "demo-1")
        let second = ProximityMapper.stableAngle(for: "demo-1")
        let other = ProximityMapper.stableAngle(for: "demo-2")
        #expect(first == second)
        #expect(first != other)
    }

    @Test func estimatedMetersGetsSmallerAsRSSIGetsStronger() {
        let close = ProximityMapper.estimatedMeters(accuracyMeters: nil, rssi: -45)
        let far = ProximityMapper.estimatedMeters(accuracyMeters: nil, rssi: -80)
        #expect(close != nil)
        #expect(far != nil)
        #expect(close! < far!)
        let oneMeter = ProximityMapper.estimatedMeters(accuracyMeters: nil, rssi: -59)
        #expect(abs(oneMeter! - 1) < 0.05)
    }

    @Test func estimatedMetersPrefersBeaconAccuracy() {
        let meters = ProximityMapper.estimatedMeters(accuracyMeters: 2.4, rssi: -90)
        #expect(meters == 2.4)
        #expect(ProximityMapper.estimatedMeters(accuracyMeters: nil, rssi: 127) == nil)
        let closePower = ProximityMapper.closenessPower(accuracyMeters: 0.4, rssi: -40)
        let farPower = ProximityMapper.closenessPower(accuracyMeters: 18, rssi: -90)
        #expect(closePower != nil)
        #expect(farPower != nil)
        #expect(closePower! > farPower!)
        #expect(ProximityMapper.closenessPowerText(72) == "72")
        #expect(ProximityMapper.closenessPowerText(nil) == "—")
    }
}

struct TreasureMergeTests {
    @Test func mergeSmoothsRadiusAndDropsStaleHits() {
        let now = Date()
        let old = DetectedTreasure.make(
            id: "a",
            title: "しきしろ",
            rssi: -90,
            accuracyMeters: 12,
            now: now.addingTimeInterval(-1)
        )
        let incoming = DetectedTreasure.make(
            id: "a",
            title: "しきしろ",
            rssi: -40,
            accuracyMeters: 0.4,
            now: now
        )
        let stale = DetectedTreasure.make(
            id: "gone",
            title: "消えた",
            rssi: -80,
            accuracyMeters: 8,
            now: now.addingTimeInterval(-8)
        )

        let merged = TreasureMerge.merge(existing: [old, stale], incoming: [incoming], now: now)
        #expect(merged.count == 1)
        #expect(merged[0].id == "a")
        #expect(merged[0].radarRadius < old.radarRadius)
        #expect(merged[0].radarRadius > incoming.radarRadius)
    }
}

struct ScanSettingsTests {
    @Test func parsesOptionalMajorAndMinor() {
        var settings = ScanSettings.default
        settings.majorText = "1"
        settings.minorText = "2"
        #expect(settings.major == 1)
        #expect(settings.minor == 2)

        settings.majorText = ""
        settings.minorText = "  "
        #expect(settings.major == nil)
        #expect(settings.minor == nil)
    }

    @Test func defaultUUIDIsValid() {
        #expect(ScanSettings.default.isUUIDValid)
        #expect(ScanSettings.hunterUUID.uuidString == ScanSettings.hunterUUIDString)
        #expect(ScanSettings.hunterUUIDString != ScanSettings.defaultUUIDString)
    }

    @Test func roundTripsThroughUserDefaults() {
        let defaults = UserDefaults(suiteName: "treasure.radar.tests")!
        defaults.removePersistentDomain(forName: "treasure.radar.tests")
        var settings = ScanSettings.default
        settings.mode = .bleName
        settings.bleName = "HiddenPhone"
        settings.save(defaults: defaults)
        let loaded = ScanSettings.load(defaults: defaults)
        #expect(loaded == settings)
    }

    @Test func missingVoiceFlagDefaultsToOn() throws {
        let json = """
        {"mode":"iBeacon","uuidString":"D4A60A10-7EA5-4E12-9ADA-545245415355","majorText":"1","minorText":"1","bleName":"しきしろ","soundEnabled":true}
        """.data(using: .utf8)!
        let settings = try JSONDecoder().decode(ScanSettings.self, from: json)
        #expect(settings.voiceEnabled)
        #expect(settings.huntedVoiceEnabled)
    }

    @Test func huntedVoiceCanBeTurnedOffAndSaved() {
        let defaults = UserDefaults(suiteName: "treasure.radar.hunted-voice")!
        defaults.removePersistentDomain(forName: "treasure.radar.hunted-voice")
        var settings = ScanSettings.default
        settings.huntedVoiceEnabled = false
        settings.save(defaults: defaults)
        let loaded = ScanSettings.load(defaults: defaults)
        #expect(loaded.huntedVoiceEnabled == false)
        #expect(loaded.voiceEnabled)
    }
}

struct StatusAnnouncerTests {
    @Test func ignoresBriefFlickerThenAnnouncesHeldStatus() {
        var announcer = StatusAnnouncer()
        announcer.holdDuration = 0.75
        let start = Date()
        #expect(announcer.clip(for: .far, now: start) == nil)
        #expect(announcer.clip(for: .mid, now: start.addingTimeInterval(0.2)) == nil)
        #expect(announcer.clip(for: .mid, now: start.addingTimeInterval(0.4)) == nil)
        #expect(announcer.clip(for: .mid, now: start.addingTimeInterval(1.0)) == .mid)
        #expect(announcer.clip(for: .mid, now: start.addingTimeInterval(1.2)) == nil)
    }

    @Test func announcesAgainWhenStatusChangesTheOtherWay() {
        var announcer = StatusAnnouncer()
        announcer.holdDuration = 0.5
        let start = Date()
        _ = announcer.speakNow(.far)
        #expect(announcer.clip(for: .mid, now: start) == nil)
        #expect(announcer.clip(for: .mid, now: start.addingTimeInterval(0.6)) == .mid)
        #expect(announcer.clip(for: .far, now: start.addingTimeInterval(0.7)) == nil)
        #expect(announcer.clip(for: .far, now: start.addingTimeInterval(1.3)) == .far)
    }

    @Test func speakNowSkipsHold() {
        var announcer = StatusAnnouncer()
        #expect(announcer.speakNow(.unknown) == .searching)
        #expect(announcer.clip(for: .unknown, now: Date()) == nil)
    }
}

struct HuntedAlertAnnouncerTests {
    @Test func staysQuietUntilNearIsHeld() {
        var announcer = HuntedAlertAnnouncer()
        announcer.holdDuration = 0.75
        let start = Date()
        #expect(announcer.clip(for: .mid, now: start) == nil)
        #expect(announcer.clip(for: .near, now: start) == nil)
        #expect(announcer.clip(for: .near, now: start.addingTimeInterval(0.4)) == nil)
        #expect(announcer.clip(for: .near, now: start.addingTimeInterval(0.8)) == .hunted)
    }

    @Test func doesNotSpamWhileStillClose() {
        var announcer = HuntedAlertAnnouncer()
        announcer.holdDuration = 0.2
        announcer.cooldown = 10
        let start = Date()
        #expect(announcer.clip(for: .immediate, now: start) == nil)
        #expect(announcer.clip(for: .immediate, now: start.addingTimeInterval(0.3)) == .hunted)
        #expect(announcer.clip(for: .immediate, now: start.addingTimeInterval(1.0)) == nil)
        #expect(announcer.clip(for: .near, now: start.addingTimeInterval(4.0)) == nil)
    }

    @Test func alertsAgainAfterCooldownEvenIfTheyStayClose() {
        var announcer = HuntedAlertAnnouncer()
        announcer.holdDuration = 0.2
        announcer.cooldown = 8
        let start = Date()
        _ = announcer.clip(for: .near, now: start)
        #expect(announcer.clip(for: .near, now: start.addingTimeInterval(0.3)) == .hunted)
        #expect(announcer.clip(for: .near, now: start.addingTimeInterval(8.4)) == .hunted)
    }

    @Test func staysCloseWhenMovingFromNearToImmediate() {
        var announcer = HuntedAlertAnnouncer()
        announcer.holdDuration = 0.5
        let start = Date()
        #expect(announcer.clip(for: .near, now: start) == nil)
        #expect(announcer.clip(for: .immediate, now: start.addingTimeInterval(0.6)) == .hunted)
    }

    @Test func huntedClipTextIsThePanicLine() {
        #expect(VoiceClip.hunted.spokenText == "やばい、ちかづいてきたー！")
        #expect(VoiceClip.hunted.fileName == "voice_hunted")
    }
}

struct FoundTrackerTests {
    @Test func doesNotTriggerFoundUntilImmediateForOneSecond() {
        var tracker = FoundTracker()
        let start = Date()
        #expect(tracker.update(proximity: .immediate, now: start) == false)
        #expect(tracker.isFound == false)
        #expect(tracker.update(proximity: .immediate, now: start.addingTimeInterval(1.05)) == true)
        #expect(tracker.isFound)
        #expect(tracker.update(proximity: .immediate, now: start.addingTimeInterval(1.2)) == false)
    }

    @Test func keepsFoundThroughBriefSignalDrops() {
        var tracker = FoundTracker()
        let start = Date()
        _ = tracker.update(proximity: .immediate, now: start)
        _ = tracker.update(proximity: .immediate, now: start.addingTimeInterval(1.1))
        #expect(tracker.isFound)
        #expect(tracker.update(proximity: .near, now: start.addingTimeInterval(1.4)) == false)
        #expect(tracker.isFound)
        _ = tracker.update(proximity: .near, now: start.addingTimeInterval(3.0))
        #expect(tracker.isFound == false)
    }
}

struct UWBRadarFusionTests {
    @Test func liveUWBIsUsedEvenWhenFartherThanARoom() {
        let now = Date()
        let ble = DetectedTreasure.make(
            id: "a",
            title: "しきしろ",
            rssi: -80,
            accuracyMeters: 14,
            now: now
        )
        let fix = UWBFix(
            distanceMeters: 12,
            horizontalAngle: 0.4,
            timestamp: now
        )
        let result = UWBRadarFusion.apply(
            treasures: [ble],
            fix: fix,
            state: UWBFusionState(),
            now: now
        )
        #expect(result.state.usingUWB)
        #expect(result.treasures[0].accuracyMeters == 12)
        #expect(result.treasures[0].usesUWBDirection)
        #expect(result.treasures[0].usesUWBDistance)
    }

    @Test func zeroDistanceUWBStillSwitchesFromBLE() {
        let now = Date()
        let ble = DetectedTreasure.make(id: "a", title: "宝", rssi: -30, accuracyMeters: 0.2)
        let result = UWBRadarFusion.apply(
            treasures: [ble],
            fix: UWBRadarFusion.fix(distanceMeters: 0, horizontalAngle: 0, now: now),
            state: UWBFusionState(),
            now: now
        )
        #expect(result.state.usingUWB)
        #expect(result.treasures[0].accuracyMeters == 0)
        #expect(result.treasures[0].usesUWBDistance)
        #expect(result.treasures[0].usesUWBDirection)
    }

    @Test func headingWithoutDistanceStillCountsAsUWB() {
        let fix = UWBRadarFusion.fix(distanceMeters: nil, horizontalAngle: 0.3)
        #expect(fix != nil)
        #expect(fix?.horizontalAngle == 0.3)
        #expect(UWBRadarFusion.fix(distanceMeters: nil, horizontalAngle: nil) == nil)
    }

    @Test func closeUWBSwitchesToDistanceAndHeading() {
        let now = Date()
        let ble = DetectedTreasure.make(
            id: "a",
            title: "しきしろ",
            rssi: -70,
            accuracyMeters: 6,
            now: now
        )
        let fix = UWBFix(
            distanceMeters: 2.0,
            horizontalAngle: 0,
            timestamp: now
        )
        let result = UWBRadarFusion.apply(
            treasures: [ble],
            fix: fix,
            state: UWBFusionState(),
            now: now
        )
        #expect(result.state.usingUWB)
        #expect(result.treasures[0].accuracyMeters == 2.0)
        #expect(result.treasures[0].usesUWBDirection)
        #expect(abs(result.treasures[0].radarAngle - UWBRadarFusion.radarAngle(fromHorizontalAngle: 0)) < 0.0001)
        #expect(result.treasures[0].radarRadius < ble.radarRadius)
        #expect(result.treasures[0].proximity == .near)
    }

    @Test func hysteresisKeepsFreshUWBAtLongerRange() {
        let now = Date()
        let ble = DetectedTreasure.make(id: "a", title: "しきしろ", rssi: -70, accuracyMeters: 9)
        let stay = UWBRadarFusion.apply(
            treasures: [ble],
            fix: UWBFix(distanceMeters: 11, horizontalAngle: 0.2, timestamp: now),
            state: UWBFusionState(usingUWB: true),
            now: now
        )
        #expect(stay.state.usingUWB)
        #expect(stay.treasures[0].accuracyMeters == 11)
    }

    @Test func staleFixFallsBackToBLE() {
        let now = Date()
        let ble = DetectedTreasure.make(id: "a", title: "しきしろ", rssi: -50, accuracyMeters: 3)
        let result = UWBRadarFusion.apply(
            treasures: [ble],
            fix: UWBFix(
                distanceMeters: 1.2,
                horizontalAngle: 1,
                timestamp: now.addingTimeInterval(-4)
            ),
            state: UWBFusionState(usingUWB: true),
            now: now
        )
        #expect(result.state.usingUWB == false)
        #expect(result.treasures[0].accuracyMeters == 3)
        #expect(result.treasures[0].radarAngle == ble.radarAngle)
    }

    @Test func uwbDistanceWithoutHeadingKeepsFallbackAngle() {
        let now = Date()
        let ble = DetectedTreasure.make(id: "a", title: "しきしろ", rssi: -55, accuracyMeters: 4)
        let result = UWBRadarFusion.apply(
            treasures: [ble],
            fix: UWBFix(distanceMeters: 1.5, horizontalAngle: nil, timestamp: now),
            state: UWBFusionState(),
            now: now
        )
        #expect(result.state.usingUWB)
        #expect(result.treasures[0].accuracyMeters == 1.5)
        #expect(result.treasures[0].usesUWBDirection == false)
        #expect(result.treasures[0].usesUWBDistance)
        #expect(result.treasures[0].uwbHorizontalAngle == nil)
    }

    @Test func emptyBLEStillShowsCloseUWBBlip() {
        let now = Date()
        let result = UWBRadarFusion.apply(
            treasures: [],
            fix: UWBFix(distanceMeters: 1.1, horizontalAngle: .pi / 2, timestamp: now),
            state: UWBFusionState(),
            now: now
        )
        #expect(result.treasures.count == 1)
        #expect(result.state.usingUWB)
        #expect(result.treasures[0].id == UWBRadarFusion.syntheticTreasureID)
        #expect(result.treasures[0].usesUWBDirection)
        #expect(result.treasures[0].usesUWBDistance)
        #expect(abs(result.treasures[0].radarAngle - UWBRadarFusion.radarAngle(fromHorizontalAngle: .pi / 2)) < 0.0001)
    }

    @Test func overlaysClosestTreasureOnly() {
        let now = Date()
        let close = DetectedTreasure.make(id: "near", title: "近い", rssi: -50, accuracyMeters: 3, now: now)
        let far = DetectedTreasure.make(id: "far", title: "遠い", rssi: -90, accuracyMeters: 16, now: now)
        let result = UWBRadarFusion.apply(
            treasures: [far, close],
            fix: UWBFix(distanceMeters: 0.7, horizontalAngle: 0.5, timestamp: now),
            state: UWBFusionState(),
            now: now
        )
        let updatedClose = result.treasures.first { $0.id == "near" }!
        let updatedFar = result.treasures.first { $0.id == "far" }!
        #expect(updatedClose.accuracyMeters == 0.7)
        #expect(updatedClose.usesUWBDirection)
        #expect(updatedClose.usesUWBDistance)
        #expect(updatedFar.accuracyMeters == 16)
        #expect(updatedFar.usesUWBDirection == false)
        #expect(updatedFar.usesUWBDistance == false)
    }

    @Test func forwardHeadingMapsToTopOfRadar() {
        let angle = UWBRadarFusion.radarAngle(fromHorizontalAngle: 0)
        #expect(abs(angle - (-.pi / 2)) < 0.0001)
        let right = UWBRadarFusion.radarAngle(fromHorizontalAngle: .pi / 2)
        #expect(abs(right) < 0.0001)
    }

    @Test func phoneBackIsForwardOnTheRadar() {
        let front = UWBRadarFusion.horizontalAngle(fromDirection: SIMD3<Float>(0, 0, -1))
        let right = UWBRadarFusion.horizontalAngle(fromDirection: SIMD3<Float>(1, 0, 0))
        #expect(front != nil)
        #expect(right != nil)
        #expect(abs(front!) < 0.0001)
        #expect(abs(right! - .pi / 2) < 0.0001)
        #expect(UWBRadarFusion.relativeDirectionLabel(fromHorizontalAngle: 0) == "まえ")
        #expect(UWBRadarFusion.relativeDirectionLabel(fromHorizontalAngle: .pi / 2) == "みぎ")
        #expect(UWBRadarFusion.relativeDirectionLabel(fromHorizontalAngle: -.pi / 2) == "ひだり")
        #expect(UWBRadarFusion.relativeDirectionLabel(fromHorizontalAngle: .pi) == "うしろ")
        #expect(UWBRadarFusion.seekingHint(meters: 2.4, horizontalAngle: 0).contains("まえ"))
        #expect(UWBRadarFusion.seekingHint(meters: 2.4, horizontalAngle: 0).contains("2.4m"))
        #expect(UWBRadarFusion.seekingHint(meters: 2.4, horizontalAngle: nil).contains("方角はまだ"))
    }

    @Test func uwbHeadingIsSmoothedAfterFirstLock() {
        let now = Date()
        let ble = DetectedTreasure.make(id: "a", title: "しきしろ", rssi: -50, accuracyMeters: 3)
        let first = UWBRadarFusion.apply(
            treasures: [ble],
            fix: UWBFix(distanceMeters: 1.2, horizontalAngle: 0, timestamp: now),
            state: UWBFusionState(),
            now: now
        )
        let second = UWBRadarFusion.apply(
            treasures: [ble],
            fix: UWBFix(distanceMeters: 1.2, horizontalAngle: .pi / 2, timestamp: now),
            state: first.state,
            now: now
        )
        let jumped = UWBRadarFusion.radarAngle(fromHorizontalAngle: .pi / 2)
        #expect(second.treasures[0].usesUWBDirection)
        #expect(abs(second.treasures[0].radarAngle - jumped) > 0.1)
        #expect(abs(second.treasures[0].radarAngle - first.treasures[0].radarAngle) > 0.1)
    }

    @Test func rangingLinkIsNilWhenIdle() {
        #expect(RangingLink.current(isActive: false, usingUWB: false) == nil)
        #expect(RangingLink.current(isActive: false, usingUWB: true) == nil)
    }

    @Test func rangingLinkShowsUWBOnlyWhenUsingIt() {
        #expect(RangingLink.current(isActive: true, usingUWB: false) == .ble)
        #expect(RangingLink.current(isActive: true, usingUWB: true) == .uwb)
        #expect(RangingLink.ble.rawValue == "BLE")
        #expect(RangingLink.uwb.rawValue == "UWB")
    }
}
