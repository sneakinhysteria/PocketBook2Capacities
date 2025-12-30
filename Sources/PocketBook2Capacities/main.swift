import ArgumentParser
import Foundation
import PocketBook2CapacitiesCore

@main
struct PocketBook2Capacities: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "pocketbook2capacities",
        abstract: "Sync reading highlights from PocketBook Cloud to Capacities",
        version: "1.0.0",
        subcommands: [
            LoginCommand.self,
            SyncCommand.self,
            StatusCommand.self,
            ConfigCommand.self,
        ],
        defaultSubcommand: StatusCommand.self
    )
}
