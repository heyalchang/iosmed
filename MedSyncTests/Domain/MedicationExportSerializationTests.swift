import XCTest
@testable import MedSync

final class MedicationExportSerializationTests: XCTestCase {
    func testJSONSerializationIncludesSchemaAndMedicationFields() throws {
        let payload = samplePayload()

        let data = try MedicationExportSerializer.serialize(payload, as: .json)
        let decoded = try JSONDecoder.medSync.decode(MedicationExportPayload.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.exportType, "medications")
        XCTAssertEqual(decoded.data.medications.count, 1)
        XCTAssertEqual(decoded.data.medications.first?.medication.displayText, "Tirzepatide 7.5mg/0.5mL Solution for injection")
        XCTAssertEqual(decoded.data.medications.first?.logStatus, .taken)
    }

    func testCSVSerializationFlattensMedicationRows() throws {
        let payload = samplePayload()

        let data = try MedicationExportSerializer.serialize(payload, as: .csv)
        let string = String(decoding: data, as: UTF8.self)
        let lines = string.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(lines.first, "id,startDate,endDate,logStatus,scheduleType,scheduledDate,doseQuantity,scheduledDoseQuantity,unit,displayText,nickname,hasSchedule,isArchived,generalForm,codings")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].contains("\"taken\""))
        XCTAssertTrue(lines[1].contains("\"injection\""))
        XCTAssertTrue(lines[1].contains("rxnorm"))
    }

    private func samplePayload() -> MedicationExportPayload {
        let date = ISO8601DateFormatter().date(from: "2026-03-14T11:05:00-07:00")!
        let record = MedicationExportRecord(
            id: "sample-id",
            startDate: date,
            endDate: date,
            logStatus: .taken,
            scheduleType: .scheduled,
            scheduledDate: date,
            doseQuantity: 0.5,
            scheduledDoseQuantity: 0.5,
            unit: "mL",
            medication: MedicationIdentity(
                displayText: "Tirzepatide 7.5mg/0.5mL Solution for injection",
                nickname: "Weekly shot",
                hasSchedule: true,
                isArchived: false,
                generalForm: "injection",
                codings: [
                    MedicationCoding(system: "http://www.nlm.nih.gov/research/umls/rxnorm", version: "", code: "2601784")
                ]
            )
        )

        return MedicationExportPayload(
            exportedAt: date,
            dateRange: date...date,
            preset: .lastDay,
            medications: [record]
        )
    }
}
