//
//  SessionLink.swift
//  Splits
//
//  WCSession 래퍼. iPhone과 워치가 같이 쓴다.
//  델리게이트 콜백은 백그라운드 큐에서 오므로 값만 꺼내 메인 액터로 넘긴다.
//

import Foundation
import WatchConnectivity

nonisolated final class SessionLink: NSObject, WCSessionDelegate, @unchecked Sendable {
    /// 활성화가 끝났거나 페어링·앱 설치 상태가 바뀌었다.
    var onStateChange: (@MainActor () -> Void)?
    /// 상대가 보낸 applicationContext의 payload.
    var onContext: (@MainActor (Data) -> Void)?
    /// 상대가 보낸 세션 파일의 내용.
    var onWorkoutFile: (@MainActor (Data) -> Void)?
    /// 내가 보낸 파일 전송이 끝났다. 보낼 때 붙인 파일 ID와 성공 여부.
    var onFileSent: (@MainActor (String, Bool) -> Void)?

    private var session: WCSession { WCSession.default }

    /// 콜백을 모두 붙인 뒤에 부른다.
    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    var isActivated: Bool {
        WCSession.isSupported() && session.activationState == .activated
    }

    #if os(iOS)
    /// 짝지은 워치에 Splits가 깔려 있어야 보낼 의미가 있다.
    var isWatchAppInstalled: Bool {
        isActivated && session.isPaired && session.isWatchAppInstalled
    }
    #endif

    func updateContext(_ data: Data) throws {
        try session.updateApplicationContext([SyncCoding.payloadKey: data])
    }

    /// 파일 이름을 ID로 메타데이터에 싣는다. 끝나면 그 ID로 onFileSent가 온다.
    func transferWorkoutFile(_ url: URL) {
        session.transferFile(url, metadata: [
            SyncCoding.kindKey: SyncCoding.workoutKind,
            SyncCoding.fileIDKey: url.lastPathComponent,
        ])
    }

    /// 아직 보내는 중인 파일의 ID.
    var outstandingFileIDs: Set<String> {
        guard isActivated else { return [] }
        return Set(session.outstandingFileTransfers.compactMap { $0.file.metadata?[SyncCoding.fileIDKey] as? String })
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext[SyncCoding.payloadKey] as? Data
        Task { @MainActor in
            if let context {
                self.onContext?(context)
            }
            self.onStateChange?()
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext[SyncCoding.payloadKey] as? Data else { return }
        Task { @MainActor in
            self.onContext?(data)
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // 이 콜백이 끝나면 시스템이 파일을 지운다. 여기서 읽어 둔다.
        guard file.metadata?[SyncCoding.kindKey] as? String == SyncCoding.workoutKind,
              let data = try? Data(contentsOf: file.fileURL) else { return }
        Task { @MainActor in
            self.onWorkoutFile?(data)
        }
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        guard let id = fileTransfer.file.metadata?[SyncCoding.fileIDKey] as? String else { return }
        let succeeded = error == nil
        Task { @MainActor in
            self.onFileSent?(id, succeeded)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    /// 다른 워치로 바꿨을 때. 다시 활성화해야 새 워치와 이어진다.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.onStateChange?()
        }
    }
    #endif
}
