import Foundation
import simd
@preconcurrency import MultipeerConnectivity
@preconcurrency import NearbyInteraction

@MainActor
protocol UWBPeerDelegate: AnyObject {
    func uwbDidUpdate(_ fix: UWBFix?)
    func uwbDidChangeStatus(_ message: String)
}

@MainActor
final class UWBPeerCoordinator: NSObject {
    private static let serviceType = "trradar-uwb"

    private weak var delegate: UWBPeerDelegate?
    private var role: BeaconRole = .treasure
    private var running = false

    private var niSession: NISession?
    private var peerToken: NIDiscoveryToken?

    private var peerID: MCPeerID?
    private var mcSession: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    init(delegate: UWBPeerDelegate) {
        self.delegate = delegate
        super.init()
    }

    func start(role: BeaconRole) {
        stop()
        self.role = role
        running = true

        guard NISession.isSupported else { return }

        let session = NISession()
        session.delegate = self
        niSession = session

        let peerID = MCPeerID(displayName: String(UUID().uuidString.prefix(12)))
        self.peerID = peerID
        let mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        mcSession.delegate = self
        self.mcSession = mcSession

        let info = ["role": roleName]
        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: info,
            serviceType: Self.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    func stop() {
        running = false
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        mcSession?.disconnect()
        niSession?.invalidate()
        browser = nil
        advertiser = nil
        mcSession = nil
        peerID = nil
        niSession = nil
        peerToken = nil
    }

    private func sendDiscoveryToken() {
        guard let token = niSession?.discoveryToken,
              let mcSession,
              !mcSession.connectedPeers.isEmpty
        else { return }

        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            try mcSession.send(data, toPeers: mcSession.connectedPeers, with: .reliable)
        } catch {
            delegate?.uwbDidChangeStatus("UWBのつなぎに失敗したよ")
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                guard self.running else { return }
                self.sendDiscoveryToken()
            }
        }
    }

    private func run(with token: NIDiscoveryToken) {
        guard running else { return }
        if peerToken == token { return }
        peerToken = token
        let configuration = NINearbyPeerConfiguration(peerToken: token)
        if NISession.deviceCapabilities.supportsCameraAssistance {
            configuration.isCameraAssistanceEnabled = true
        }
        niSession?.run(configuration)
    }

    nonisolated private static func fix(from object: NINearbyObject) -> UWBFix? {
        guard let distance = object.distance else { return nil }
        let heading = object.horizontalAngle.map(Double.init)
            ?? object.direction.flatMap(UWBRadarFusion.horizontalAngle(fromDirection:))
        return UWBFix(
            distanceMeters: Double(distance),
            horizontalAngle: heading,
            timestamp: Date()
        )
    }

    private func restartNearbySessionIfNeeded() {
        guard running, NISession.isSupported else { return }
        niSession?.invalidate()
        let session = NISession()
        session.delegate = self
        niSession = session
        peerToken = nil
        sendDiscoveryToken()
    }

    private var roleName: String {
        role == .treasure ? "hide" : "seek"
    }

    private var oppositeRole: String {
        role == .treasure ? "seek" : "hide"
    }
}

extension UWBPeerCoordinator: NISessionDelegate {
    nonisolated func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        let fixes = nearbyObjects.compactMap(Self.fix(from:))
        Task { @MainActor in
            self.delegate?.uwbDidUpdate(fixes.first)
        }
    }

    nonisolated func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        Task { @MainActor in
            self.delegate?.uwbDidUpdate(nil)
        }
    }

    nonisolated func sessionWasSuspended(_ session: NISession) {
        Task { @MainActor in
            self.delegate?.uwbDidUpdate(nil)
        }
    }

    nonisolated func sessionSuspensionEnded(_ session: NISession) {
        Task { @MainActor in
            if let token = self.peerToken {
                self.peerToken = nil
                self.run(with: token)
            }
        }
    }

    nonisolated func session(_ session: NISession, didInvalidateWith error: any Error) {
        Task { @MainActor in
            self.delegate?.uwbDidUpdate(nil)
            try? await Task.sleep(for: .seconds(1))
            self.restartNearbySessionIfNeeded()
        }
    }
}

extension UWBPeerCoordinator: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            if state == .connected {
                self.sendDiscoveryToken()
            } else if state == .notConnected {
                self.peerToken = nil
                self.delegate?.uwbDidUpdate(nil)
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let token: NIDiscoveryToken?
        do {
            token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data)
        } catch {
            token = nil
        }
        Task { @MainActor in
            if let token {
                let isNewPeer = self.peerToken != token
                self.run(with: token)
                if isNewPeer {
                    self.sendDiscoveryToken()
                }
            }
        }
    }

    nonisolated func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    nonisolated func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: (any Error)?
    ) {}
}

extension UWBPeerCoordinator: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        let theirRole = context.flatMap { String(data: $0, encoding: .utf8) }
        let handler = UncheckedInvitationHandler(invitationHandler)
        Task { @MainActor in
            let accept = self.running && theirRole == self.oppositeRole
            handler.call(accept, self.mcSession)
        }
    }
}

extension UWBPeerCoordinator: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        let theirRole = info?["role"]
        Task { @MainActor in
            guard self.running else { return }
            guard theirRole == self.oppositeRole else { return }
            guard let mcSession = self.mcSession else { return }
            guard !mcSession.connectedPeers.contains(peerID) else { return }
            let context = Data(self.roleName.utf8)
            self.browser?.invitePeer(peerID, to: mcSession, withContext: context, timeout: 10)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

private struct UncheckedInvitationHandler: @unchecked Sendable {
    let call: (Bool, MCSession?) -> Void

    init(_ call: @escaping (Bool, MCSession?) -> Void) {
        self.call = call
    }
}
