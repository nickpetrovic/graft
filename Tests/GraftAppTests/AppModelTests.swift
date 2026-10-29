import Foundation
import ModKit
import Testing
@testable import GraftApp

@MainActor
struct AppModelTests {
    let game = GameDefinition(id: "graft-app-model-tests", name: "Test Game", titleId: "0100000000000000")

    @Test func finishingTheLastTaskReportsThatGraftIsIdle() async {
        let model = AppModel(game: game)
        var idle = 0
        model.onIdle = { idle += 1 }

        await model.refresh()
        await model.refresh()

        #expect(idle == 2)
        #expect(!model.isWorking)
    }

    @Test func aChangedDefinitionReplacesTheGameAndAnotherIdIsIgnored() {
        let model = AppModel(game: game)
        var renamed = game
        renamed.name = "Renamed"
        var other = game
        other.id = "graft-app-model-tests-other"

        model.update(definition: renamed)
        model.update(definition: other)

        #expect(model.game == renamed)
    }
}
