import WorkFlow
import rNews

// this file was generated by Xcode-Better-Refactor-Tools
// https://github.com/tjarratt/xcode-better-refactor-tools

class FakeMigrationUseCase : MigrationUseCase {
    init() {
    }

    private(set) var addSubscriberCallCount : Int = 0
    private var addSubscriberArgs : Array<(MigrationUseCaseSubscriber)> = []
    func addSubscriberArgsForCall(callIndex: Int) -> (MigrationUseCaseSubscriber) {
        return self.addSubscriberArgs[callIndex]
    }
    func addSubscriber(subscriber: MigrationUseCaseSubscriber) {
        self.addSubscriberCallCount++
        self.addSubscriberArgs.append((subscriber))
    }

    private(set) var beginMigrationCallCount : Int = 0
    func beginMigration() {
        self.beginMigrationCallCount++
    }

    private(set) var beginWorkCallCount : Int = 0
    private var beginWorkArgs : Array<(WorkFlowFinishCallback)> = []
    func beginWorkArgsForCall(callIndex: Int) -> (WorkFlowFinishCallback) {
        return self.beginWorkArgs[callIndex]
    }
    func beginWork(finish: WorkFlowFinishCallback) {
        self.beginWorkCallCount++
        self.beginWorkArgs.append((finish))
    }

    static func reset() {
    }
}

class FakeMigrationUseCaseSubscriber : MigrationUseCaseSubscriber {
    init() {
    }

    private(set) var migrationUseCaseDidFinishCallCount : Int = 0
    private var migrationUseCaseDidFinishArgs : Array<(MigrationUseCase)> = []
    func migrationUseCaseDidFinishArgsForCall(callIndex: Int) -> (MigrationUseCase) {
        return self.migrationUseCaseDidFinishArgs[callIndex]
    }
    func migrationUseCaseDidFinish(migrationUseCase: MigrationUseCase) {
        self.migrationUseCaseDidFinishCallCount++
        self.migrationUseCaseDidFinishArgs.append((migrationUseCase))
    }

    private(set) var migrationUseCaseDidUpdateProgressCallCount : Int = 0
    private var migrationUseCaseDidUpdateProgressArgs : Array<(MigrationUseCase, Double)> = []
    func migrationUseCaseDidUpdateProgressArgsForCall(callIndex: Int) -> (MigrationUseCase, Double) {
        return self.migrationUseCaseDidUpdateProgressArgs[callIndex]
    }
    func migrationUseCase(migrationUseCase: MigrationUseCase, didUpdateProgress progress: Double) {
        self.migrationUseCaseDidUpdateProgressCallCount++
        self.migrationUseCaseDidUpdateProgressArgs.append((migrationUseCase, progress))
    }

    static func reset() {
    }
}