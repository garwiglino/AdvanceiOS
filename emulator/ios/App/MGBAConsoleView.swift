// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import UIKit

private final class ConsoleModel: ObservableObject {
    @Published var size = CGSize(width: 874, height: 402)
    @Published var insets = UIEdgeInsets.zero
    @Published var keys: UInt32 = 0
    @Published var padOrigin: CGPoint?
    @Published var padPoint = CGPoint.zero
    let screen: UIView
    let controls: MGBAControls
    let images: [String: UIImage]
    var onAccessibleKey: ((UInt32) -> Void)?
    init(screen: UIView, controls: MGBAControls) {
        self.screen = screen
        self.controls = controls
        let root = Bundle.main.url(forResource: "ios-outline", withExtension: nil)
        var loaded: [String: UIImage] = [:]
        for name in ["dpad", "a", "b", "l", "r", "select", "start"] {
            if let path = root?.appendingPathComponent("png/\(name)@3x.png").path {
                loaded[name] = UIImage(contentsOfFile: path)
            }
        }
        images = loaded
        controls.onPad = { [weak self] origin, point, active in
            guard let self else { return }
            let newOrigin: CGPoint? = active ? origin : nil
            if self.padOrigin != newOrigin { self.padOrigin = newOrigin }
            if self.padPoint != point { self.padPoint = point }
        }
    }
}

/// The game is aspect-fit independently of the controls. Only control positions
/// depend on thumb reach; no console opening can shrink the game anymore.
@objc(MGBAConsoleSurface) final class MGBAConsoleSurface: NSObject {
    private let model: ConsoleModel
    @objc let controller: UIViewController
    @objc var onAccessibleKey: ((UInt32) -> Void)? {
        didSet { model.onAccessibleKey = onAccessibleKey }
    }
    private let feedback = UIImpactFeedbackGenerator(style: .soft)
    @objc init(screen: UIView, controls: MGBAControls) {
        model = ConsoleModel(screen: screen, controls: controls)
        let host = UIHostingController(rootView: ConsoleView(model: model))
        if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
        controller = host
        super.init()
        controller.view.backgroundColor = .black
    }
    @objc func updateLayout(_ size: CGSize, insets: UIEdgeInsets) {
        if model.size != size { model.size = size }
        if model.insets != insets { model.insets = insets }
    }
    @objc func setKeys(_ keys: UInt32) {
        guard model.keys != keys else { return }
        let previous = model.keys
        model.keys = keys
        let enabled = UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true
        if enabled && keys != 0 && ((keys & ~previous) != 0) {
            feedback.impactOccurred(intensity: 0.45)
            feedback.prepare()
        }
    }
    @objc var screenFrame: CGRect { ConsoleLayout(model: model).screen }
    @objc var menuFrame: CGRect { ConsoleLayout(model: model).menu }
}

private struct ConsoleLayout {
    let screen, menu: CGRect
    let visual, hit: [String: CGRect]
    let unit: CGFloat
    init(model: ConsoleModel) {
        let w = max(1, model.size.width), h = max(1, model.size.height)
        let safe = CGRect(x: model.insets.left, y: model.insets.top,
                          width: max(1, w-model.insets.left-model.insets.right),
                          height: max(1, h-model.insets.top-model.insets.bottom))
        let gh = min(safe.height, safe.width/1.5)
        screen = CGRect(x: safe.midX-gh*0.75, y: safe.midY-gh/2, width: gh*1.5, height: gh)
        unit = min(w,h) > 600 ? 1.12 : 1
        let u = unit
        let bottom = safe.maxY-18*u
        let right = min(safe.maxX-16*u, screen.maxX+36*u)
        let left = max(safe.minX+16*u, screen.minX-36*u)
        func centered(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
            CGRect(x: max(safe.minX, min(safe.maxX-width, x-width/2)),
                   y: max(safe.minY, min(safe.maxY-height, y-height/2)), width: width, height: height)
        }
        var frames = [
            "a": centered(right-32*u, bottom-91*u, 64*u, 64*u),
            "b": centered(right-100*u, bottom-44*u, 64*u, 64*u),
            "l": centered(left+44*u, bottom-209*u, 88*u, 48*u),
            "r": centered(right-44*u, bottom-209*u, 88*u, 48*u),
            "select": centered(safe.midX-74, safe.minY+30, 64, 44),
            "start": centered(safe.midX+74, safe.minY+30, 64, 44)
        ]
        menu = centered(safe.midX, safe.minY+30, 44, 44)
        var hits = frames
        frames["dpad"] = centered(left+64*u, bottom-75*u, 128*u, 128*u)
        // The entire left half accepts a fresh movement contact. Buttons win.
        hits["dpad"] = CGRect(x: safe.minX, y: safe.minY, width: safe.width/2, height: safe.height)
        visual = frames
        hit = hits
    }
}
private struct NativeScreen: UIViewRepresentable {
    let view: UIView
    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ uiView: UIView, context: Context) {}
}
private struct TouchSurface: UIViewRepresentable {
    let view: MGBAControls
    let layout: ConsoleLayout
    func makeUIView(context: Context) -> MGBAControls { view }
    func updateUIView(_ uiView: MGBAControls, context: Context) {
        let visual = layout.visual.mapValues { NSValue(cgRect: $0) }
        let hit = layout.hit.mapValues { NSValue(cgRect: $0) }
        DispatchQueue.main.async { [weak uiView] in uiView?.configureVisualRegions(visual, hitRegions: hit) }
    }
}
private extension View {
    func placed(in rect: CGRect) -> some View {
        frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
    }
}
private struct ConsoleView: View {
    @ObservedObject var model: ConsoleModel
    private let names = ["dpad", "a", "b", "l", "r", "select", "start"]
    private func mask(_ name: String) -> UInt32 {
        ["a":1,"b":2,"select":4,"start":8,"r":256,"l":512,"dpad":240][name] ?? 0
    }
    var body: some View {
        let layout = ConsoleLayout(model: model)
        ZStack(alignment: .topLeading) {
            Color.black
            NativeScreen(view: model.screen).placed(in: layout.screen)
            ForEach(names, id: \.self) { name in
                if let slot = layout.visual[name], let image = model.images[name] {
                    let isPad = name == "dpad"
                    let origin = isPad ? model.padOrigin : nil
                    let frame = origin.map { CGRect(x: $0.x-slot.width/2, y: $0.y-slot.height/2, width: slot.width, height: slot.height) } ?? slot
                    let pressed = model.keys & mask(name) != 0
                    Image(uiImage: image).resizable()
                        .opacity(isPad ? (origin != nil || pressed ? 0.9 : 0.25) : (pressed ? 1 : 0.65))
                        .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
                        .shadow(color: .white.opacity(pressed ? 0.4 : 0), radius: 6)
                        .placed(in: frame).allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            if let origin = model.padOrigin {
                let dx = model.padPoint.x-origin.x, dy = model.padPoint.y-origin.y
                let length = hypot(dx,dy), limit = 44*layout.unit*0.7
                let factor = length > limit ? limit/length : 1
                Circle().fill(.white.opacity(0.06)).overlay(Circle().stroke(.white.opacity(0.65), lineWidth: 1.5))
                    .frame(width: 33*layout.unit, height: 33*layout.unit)
                    .position(x: origin.x+dx*factor, y: origin.y+dy*factor)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            TouchSurface(view: model.controls, layout: layout).frame(width: model.size.width, height: model.size.height)
            ForEach(names, id: \.self) { name in
                if let hit = layout.visual[name] {
                    Color.clear.placed(in: hit).allowsHitTesting(false)
                        .accessibilityElement().accessibilityLabel(name == "dpad" ? "Croix directionnelle" : name.uppercased())
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { model.onAccessibleKey?(name == "dpad" ? 128 : mask(name)) }
                        .accessibilityActions {
                            if name == "dpad" {
                                Button("Haut") { model.onAccessibleKey?(64) }
                                Button("Bas") { model.onAccessibleKey?(128) }
                                Button("Gauche") { model.onAccessibleKey?(32) }
                                Button("Droite") { model.onAccessibleKey?(16) }
                            }
                        }
                }
            }
        }.frame(width: model.size.width, height: model.size.height).clipped().ignoresSafeArea()
    }
}
