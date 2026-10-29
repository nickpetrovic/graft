import SwiftUI

struct ReorderableCards<Item: Identifiable, Header: View, Row: View>: View where Item.ID == String {
    struct CardDrag: Equatable {
        let id: String
        let from: Int
        let grab: CGFloat
        var pointer: CGFloat
        var target: Int
    }

    struct Settling: Equatable {
        let id: String
        var offset: CGFloat
    }

    struct ScrollMetrics: Equatable {
        var offset: CGFloat = 0
        var minOffset: CGFloat = 0
        var maxOffset: CGFloat = 0
        var height: CGFloat = 0
    }

    static var spacing: CGFloat { 8 }
    static var motion: Animation { .spring(duration: 0.32, bounce: 0.16) }
    static var edgeZone: CGFloat { 64 }
    static var maxScrollStep: CGFloat { 18 }

    let items: [Item]
    let isLocked: Bool
    let margin: CGFloat
    var cornerRadius: CGFloat = 14
    @ViewBuilder let header: () -> Header
    @ViewBuilder let row: (Item, Int) -> Row
    let move: (String, Int) -> Void

    @ViewState private var drag: CardDrag?
    @ViewState private var settling: Settling?
    @ViewState private var frames: [String: CGRect] = [:]
    @ViewState private var cardsTop: CGFloat = 0
    @ViewState private var metrics = ScrollMetrics()
    @ViewState private var scroll = ScrollPosition(edge: .top)

    var body: some View {
        let layout = drag == nil ? nil : self.layout
        ScrollView {
            VStack(alignment: .leading, spacing: Self.spacing) {
                header()
                VStack(spacing: Self.spacing) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { position, item in
                        card(item, at: position, layout: layout)
                    }
                }
                .coordinateSpace(.named(CardSpace.cards))
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(CardSpace.viewport)).minY } action: { cardsTop = $0 }
            }
            .padding(.horizontal, margin)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .scrollPosition($scroll)
        .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
            let minOffset = -geometry.contentInsets.top
            return ScrollMetrics(offset: geometry.contentOffset.y, minOffset: minOffset,
                                 maxOffset: max(minOffset, geometry.contentSize.height + geometry.contentInsets.bottom - geometry.containerSize.height),
                                 height: geometry.containerSize.height)
        } action: { _, new in
            metrics = new
        }
        .coordinateSpace(.named(CardSpace.viewport))
        .task(id: drag?.id) {
            await scrollWhileDragging()
        }
    }

    private var layout: CardLayout {
        CardLayout(frames: items.map { frames[$0.id] ?? .zero }, spacing: Self.spacing)
    }

    private func card(_ item: Item, at position: Int, layout: CardLayout?) -> some View {
        let lifted = drag?.id == item.id || settling?.id == item.id
        return row(item, displayPosition(at: position))
            .background(.background, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .offset(y: offset(of: item.id, at: position, layout: layout))
            .animation(drag?.id == item.id ? nil : Self.motion, value: drag?.target)
            .scaleEffect(lifted ? 1.02 : 1)
            .shadow(color: .black.opacity(lifted ? 0.32 : 0), radius: lifted ? 18 : 0, y: lifted ? 10 : 0)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(CardSpace.cards)) } action: { frames[item.id] = $0 }
            .zIndex(lifted ? 1 : 0)
            .gesture(dragGesture(for: item.id, at: position))
    }

    private func offset(of id: String, at position: Int, layout: CardLayout?) -> CGFloat {
        if let settling, settling.id == id { return settling.offset }
        guard let drag, let layout, let dragged = frames[drag.id] else { return 0 }
        if id == drag.id { return draggedTop(drag) - dragged.minY }
        return layout.shift(of: position, from: drag.from, target: drag.target)
    }

    private func displayPosition(at position: Int) -> Int {
        guard let drag else { return position }
        return CardLayout.displayPosition(of: position, from: drag.from, target: drag.target)
    }

    private func draggedTop(_ drag: CardDrag) -> CGFloat {
        drag.pointer - cardsTop - drag.grab
    }

    private func dragGesture(for id: String, at position: Int) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(CardSpace.viewport))
            .onChanged { value in
                if drag == nil {
                    guard !isLocked, settling == nil, let frame = frames[id] else { return }
                    withAnimation(Self.motion) {
                        drag = CardDrag(id: id, from: position, grab: value.startLocation.y - cardsTop - frame.minY,
                                        pointer: value.location.y, target: position)
                    }
                } else if drag?.id == id {
                    drag?.pointer = value.location.y
                    updateTarget()
                }
            }
            .onEnded { _ in
                if drag?.id == id { drop() }
            }
    }

    private func updateTarget() {
        guard let current = drag else { return }
        let target = layout.target(of: current.from, top: draggedTop(current))
        if target != current.target { drag?.target = target }
    }

    private func drop() {
        guard let current = drag else { return }
        let release = Settling(id: current.id, offset: draggedTop(current) - layout.landingTop(of: current.from, target: current.target))
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            if current.target != current.from { move(current.id, current.target) }
            drag = nil
            settling = release
        }
        Task { @MainActor in
            withAnimation(Self.motion) { settling = nil }
        }
    }

    private func scrollWhileDragging() async {
        while !Task.isCancelled, let current = drag {
            var step: CGFloat = 0
            if current.pointer < Self.edgeZone {
                step = -Self.maxScrollStep * min(1, (Self.edgeZone - current.pointer) / Self.edgeZone)
            } else if current.pointer > metrics.height - Self.edgeZone {
                step = Self.maxScrollStep * min(1, (current.pointer - (metrics.height - Self.edgeZone)) / Self.edgeZone)
            }
            let next = min(max(metrics.offset + step, metrics.minOffset), metrics.maxOffset)
            if step != 0, next != metrics.offset {
                scroll.scrollTo(y: next)
                updateTarget()
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }
}

struct CardLayout {
    let frames: [CGRect]
    let spacing: CGFloat

    static func displayPosition(of index: Int, from: Int, target: Int) -> Int {
        if index == from { return target }
        if from < target, index > from, index <= target { return index - 1 }
        if target < from, index >= target, index < from { return index + 1 }
        return index
    }

    func target(of from: Int, top: CGFloat) -> Int {
        let center = top + frames[from].height / 2
        return frames.indices.filter { $0 != from && frames[$0].midY < center }.count
    }

    func shift(of index: Int, from: Int, target: Int) -> CGFloat {
        let distance = frames[from].height + spacing
        if from < target, index > from, index <= target { return -distance }
        if target < from, index >= target, index < from { return distance }
        return 0
    }

    func landingTop(of from: Int, target: Int) -> CGFloat {
        if target > from { return frames[target].maxY - frames[from].height }
        if target < from { return frames[target].minY }
        return frames[from].minY
    }
}

private enum CardSpace: Hashable {
    case cards
    case viewport
}
