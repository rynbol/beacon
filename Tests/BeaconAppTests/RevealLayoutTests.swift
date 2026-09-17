import AppKit
import SwiftUI
import Synchronization
import XCTest
@testable import BeaconApp

/// These tests run SwiftUI's real layout engine offscreen. They protect the
/// invariant behind disclosures: animation changes the viewport, never the
/// proposal used to lay out its text. No Beacon model or application is started.
@MainActor
final class RevealLayoutTests: XCTestCase {
    func testClosedAndPartlyOpenDisclosureKeepTextAtItsNaturalHeight() async throws {
        let width: CGFloat = 280
        let baseline = render(width: width) { notes }
        XCTAssertGreaterThan(baseline.height, 80)

        for progress: CGFloat in [0, 0.15, 0.5, 0.85, 1] {
            let probe = LayoutProbe()
            let size = render(width: width) {
                BeaconRevealLayout(progress: progress) {
                    RecordingLayout(probe: probe) { notes }
                }
            }
            XCTAssertEqual(size.height, baseline.height * progress, accuracy: 1)
            let placement = try XCTUnwrap(probe.placements.last)
            XCTAssertEqual(placement.size.height, baseline.height, accuracy: 1,
                           "The text must stay fully laid out even in a closed viewport")
            XCTAssertEqual(placement.size.width, width, accuracy: 1)
        }
    }

    func testLineLimitedCollapsedMeasurementDoesNotCompressFullNotes() async throws {
        for width: CGFloat in [190, 430] {
            let baselineProbe = LayoutProbe()
            let fullSize = render(width: width) {
                RecordingLayout(probe: baselineProbe) { notes }
            }
            let baselinePlacement = try XCTUnwrap(baselineProbe.placements.last)
            let collapsedSize = render(width: width) { notes.lineLimit(3) }
            XCTAssertGreaterThan(fullSize.height, collapsedSize.height)

            for progress: CGFloat in [0, 0.3, 0.7, 1] {
                let probe = LayoutProbe()
                let size = render(width: width) {
                    BeaconRevealLayout(progress: progress) {
                        RecordingLayout(probe: probe) { notes }
                        notes.lineLimit(3).hidden()
                    }
                }
                XCTAssertEqual(size.height,
                               collapsedSize.height + (fullSize.height - collapsedSize.height) * progress,
                               accuracy: 1)
                let placement = try XCTUnwrap(probe.placements.last)
                XCTAssertEqual(placement.size.height, fullSize.height, accuracy: 1)
                XCTAssertEqual(placement.size.width, baselinePlacement.width, accuracy: 1)
            }
        }
    }

    func testNestedMeetingDetailsUseTheirOwnViewportWithoutSquashingSurroundingText() async throws {
        let width: CGFloat = 260
        let fullSize = render(width: width) { notes }
        for outerProgress: CGFloat in [0, 0.4, 1] {
            for innerProgress: CGFloat in [0, 0.5, 1] {
                let probe = LayoutProbe()
                let reference = render(width: width) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Event notes").font(.headline)
                        Color.clear.frame(height: fullSize.height * innerProgress)
                        Text("Personal note").font(.headline)
                    }
                }
                let actual = render(width: width) {
                    BeaconRevealLayout(progress: outerProgress) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Event notes").font(.headline)
                            BeaconRevealLayout(progress: innerProgress) {
                                RecordingLayout(probe: probe) { notes }
                            }
                            Text("Personal note").font(.headline)
                        }
                    }
                }
                XCTAssertEqual(actual.height, reference.height * outerProgress, accuracy: 1)
                let placement = try XCTUnwrap(probe.placements.last)
                XCTAssertEqual(placement.size.height, fullSize.height, accuracy: 1)
            }
        }
    }

    func testRowExitStaysVisibleLongEnoughToReadAsMotion() {
        XCTAssertEqual(BeaconRowExit.presence(at: 1), 1, accuracy: 0.001)
        XCTAssertEqual(BeaconRowExit.presence(at: 0.35), 0, accuracy: 0.001)
        XCTAssertEqual(BeaconRowExit.presence(at: 0), 0, accuracy: 0.001)

        // The row must not blink out. It stays plainly visible early, and it
        // still carries a trace at the half-way point.
        XCTAssertGreaterThan(BeaconRowExit.presence(at: 0.8), 0.5)
        XCTAssertGreaterThan(BeaconRowExit.presence(at: 0.5), 0.15)

        // It must still empty before the row below climbs over the title, or
        // the two print on the same pixels at full strength.
        XCTAssertLessThan(BeaconRowExit.presence(at: 0.5), 0.35)

        var previous: CGFloat = -1
        for step in stride(from: CGFloat(0), through: 1, by: 0.05) {
            let presence = BeaconRowExit.presence(at: step)
            XCTAssertGreaterThanOrEqual(presence, previous, "presence must not go back up")
            previous = presence
        }
    }

    func testRowExitNeverChangesLayout() throws {
        // The exit must stay out of layout. A viewport that collapses needs a
        // clip, and that clip runs ahead of the row content, which every row
        // carries in a nonanimated transaction. Surviving rows render sliced.
        for width: CGFloat in [320, 640] {
            let baseline = render(width: width) { row }
            for progress: CGFloat in [0, 0.35, 0.65, 0.9, 1] {
                let size = render(width: width) { row.modifier(BeaconRowExit(progress: progress)) }
                XCTAssertEqual(size.height, baseline.height, accuracy: 1)
                XCTAssertEqual(size.width, baseline.width, accuracy: 1)
            }
        }
    }

    private var row: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Circle().strokeBorder(lineWidth: 1.5).frame(width: 21, height: 21).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Send the signed lease back to the letting agent before Friday")
                        .font(.system(size: 14)).lineLimit(2)
                    Text("Tomorrow, 09:00").font(.system(size: 12))
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(minHeight: 68)
            Rectangle().frame(height: 1)
        }
    }

    private var notes: some View {
        Text("""
        Preparation for the meeting includes reviewing the proposal, bringing \
        the current schedule, and writing down the questions that need an answer.

        Meeting details can contain several lines of provider text and a long \
        address such as https://example.com/meetings/project-review?day=friday.

        These final notes should keep the same line breaks while the disclosure \
        opens, closes, or changes direction midway through its animation.
        """)
        .font(.system(size: 13))
    }

    private func render<Content: View>(width: CGFloat, @ViewBuilder content: () -> Content) -> CGSize {
        // The one-point padding keeps a completely collapsed viewport renderable.
        let renderer = ImageRenderer(content: content().frame(width: width).padding(.vertical, 1))
        renderer.proposedSize = .init(width: width, height: nil)
        renderer.scale = 1
        guard let image = renderer.cgImage else {
            XCTFail("Offscreen SwiftUI rendering failed")
            return .zero
        }
        return CGSize(width: image.width, height: image.height - 2)
    }
}

private final class LayoutProbe: Sendable {
    private let storage = Mutex<[CGRect]>([])
    var placements: [CGRect] { storage.withLock { $0 } }
    func record(_ bounds: CGRect) { storage.withLock { $0.append(bounds) } }
}

/// Observe actual placement bounds of a wrapped text view, not just the
/// height returned by BeaconRevealLayout.sizeThatFits.
private struct RecordingLayout: Layout {
    let probe: LayoutProbe

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews[0].sizeThatFits(proposal)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        probe.record(bounds)
        subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: proposal)
    }
}

/// Every date must fit at both compact and expanded window widths.
@MainActor
final class UpcomingBoardWidthTests: XCTestCase {
    func testEveryDateFitsAtEverySupportedWidth() {
        for count in [7, 8] {
            for pane in stride(from: CGFloat(320), through: 2000, by: 10) {
                let column = UpcomingCalendarAgenda.columnWidth(pane: pane, days: count)
                XCTAssertGreaterThan(column, 0)
                XCTAssertEqual(column * CGFloat(count) + CGFloat(count - 1) * UpcomingCalendarAgenda.columnSpacing,
                               pane, accuracy: 0.01)
            }
        }
    }
    func testColumnsGrowContinuouslyWithWindow() {
        XCTAssertLessThan(UpcomingCalendarAgenda.columnWidth(pane: 500, days: 8),
                          UpcomingCalendarAgenda.columnWidth(pane: 900, days: 8))
        XCTAssertLessThan(UpcomingCalendarAgenda.columnWidth(pane: 900, days: 8),
                          UpcomingCalendarAgenda.columnWidth(pane: 1500, days: 8))
    }
}
