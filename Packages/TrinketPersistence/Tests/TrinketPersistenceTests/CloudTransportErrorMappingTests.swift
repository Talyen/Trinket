import CloudKit
import Testing
@testable import TrinketPersistence

/// Isolated coverage for the transport's error mapping: conflicts retry the
/// same request ID while anything else surfaces. No live CloudKit I/O.
struct CloudTransportErrorMappingTests {
    @Test func `server record changed is a conflict`() {
        #expect(CloudKitSaveTransport.isConflict(CKError(.serverRecordChanged)))
    }

    @Test func `already-mapped conflict stays a conflict`() {
        #expect(CloudKitSaveTransport.isConflict(CloudSaveError.conflict))
    }

    @Test func `unrelated failures are not conflicts`() {
        #expect(!CloudKitSaveTransport.isConflict(CloudSaveError.unavailable))
        #expect(!CloudKitSaveTransport.isConflict(CloudSaveError.accountChanged))
        #expect(!CloudKitSaveTransport.isConflict(CKError(.networkFailure)))
        #expect(!CloudKitSaveTransport.isConflict(CKError(.unknownItem)))
    }

    @Test func `nested partial conflict is a conflict`() {
        let recordID = CKRecord.ID(recordName: "head")
        let inner = CKError(.serverRecordChanged)
        let outer = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [recordID: inner]])
        #expect(CloudKitSaveTransport.isConflict(outer))
    }

    @Test func `nested partial non-conflict is not a conflict`() {
        let recordID = CKRecord.ID(recordName: "head")
        let inner = CKError(.networkFailure)
        let outer = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [recordID: inner]])
        #expect(!CloudKitSaveTransport.isConflict(outer))
    }
}
