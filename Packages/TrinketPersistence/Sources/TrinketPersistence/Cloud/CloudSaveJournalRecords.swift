/// Persistent blocks form a binary forest rather than an unbounded ownership
/// chain. Append copies at most 63 records and logarithmically many references;
/// forward iteration needs only a logarithmic stack, with no history-sized array.
struct CloudSaveJournalRecords: Sendable, Sequence {
    typealias Record = CloudSaveJournal.Record

    fileprivate final class Node: Sendable {
        enum Storage: Sendable {
            case leaf([Record])
            case branch(Node, Node)
        }

        let storage: Storage
        let count: Int

        init(records: [Record]) {
            storage = .leaf(records)
            count = records.count
        }

        init(left: Node, right: Node) {
            storage = .branch(left, right)
            count = left.count + right.count
        }

        func appendSuffix(after skipped: Int, offset: Int, to result: inout [(index: Int, record: Record)]) {
            guard skipped < count else { return }
            switch storage {
            case let .leaf(records):
                for index in Swift.max(0, skipped) ..< records.count {
                    result.append((offset + index, records[index]))
                }
            case let .branch(left, right):
                left.appendSuffix(after: skipped, offset: offset, to: &result)
                right.appendSuffix(after: skipped - left.count, offset: offset + left.count, to: &result)
            }
        }
    }

    // Complete blocks descend in size. Equal sizes merge like a binary carry;
    // every branch has equally sized children, so depth never becomes linear.
    private var blocks: [Node] = []
    private var pending: [Record] = []
    private(set) var count = 0

    var isEmpty: Bool {
        count == 0
    }

    mutating func append(_ record: Record) {
        pending.append(record)
        count += 1
        guard pending.count == 64 else { return }
        var block = Node(records: pending)
        pending = []
        while let previous = blocks.last, previous.count == block.count {
            blocks.removeLast()
            block = Node(left: previous, right: block)
        }
        blocks.append(block)
    }

    func suffix(after skipped: Int) -> [(index: Int, record: Record)] {
        guard skipped < count else { return [] }
        var result: [(index: Int, record: Record)] = []
        result.reserveCapacity(Swift.max(0, count - Swift.max(0, skipped)))
        var offset = 0
        for block in blocks {
            block.appendSuffix(after: skipped - offset, offset: offset, to: &result)
            offset += block.count
        }
        for index in Swift.min(pending.count, Swift.max(0, skipped - offset)) ..< pending.count {
            result.append((offset + index, pending[index]))
        }
        return result
    }

    struct Iterator: IteratorProtocol {
        fileprivate var stack: [Node]
        fileprivate var pending: [Record].Iterator
        private var leaf = [Record]().makeIterator()

        fileprivate init(stack: [Node], pending: [Record].Iterator) {
            self.stack = stack
            self.pending = pending
        }

        mutating func next() -> Record? {
            while true {
                if let record = leaf.next() {
                    return record
                }
                guard let node = stack.popLast() else { return pending.next() }
                switch node.storage {
                case let .leaf(records): leaf = records.makeIterator()
                case let .branch(left, right):
                    stack.append(right)
                    stack.append(left)
                }
            }
        }
    }

    func makeIterator() -> Iterator {
        Iterator(stack: Array(blocks.reversed()), pending: pending.makeIterator())
    }

    func sharesStorage(with other: Self) -> Bool {
        count == other.count && pending == other.pending
            && blocks.count == other.blocks.count
            && zip(blocks, other.blocks).allSatisfy { $0 === $1 }
    }
}
