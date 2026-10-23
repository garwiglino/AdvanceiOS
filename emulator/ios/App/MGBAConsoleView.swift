// SPDX-License-Identifier: MPL-2.0
import SwiftUI
import UIKit

private struct AssetRect: Decodable {
    let x, y, width, height: CGFloat
    var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}
private struct Facade: Decodable {
    let file: String
    let width, height: CGFloat
    let openings: [String: AssetRect]
    let gameRect: AssetRect
    let shellColor: String
}
private struct Sprite: Decodable {
    let file: String
    let width, height: CGFloat
    let contentRect: AssetRect
}
private struct AssetManifest: Decodable {
    let variants: [String: Facade]
    let sprites: [String: Sprite]
}
private final class ConsoleArtwork {
    let manifest: AssetManifest?
    let images: [String: UIImage]
    init() {
        let root = Bundle.main.url(forResource: "gba-indigo", withExtension: nil)
        manifest = root.flatMap { try? Data(contentsOf: $0.appendingPathComponent("manifest.json")) }
            .flatMap { try? JSONDecoder().decode(AssetManifest.self, from: $0) }
        var loaded: [String: UIImage] = [:]
        if let manifest, let root {
            let paths = manifest.variants.values.map(\.file) + manifest.sprites.values.map(\.file)
            for path in paths { loaded[path] = UIImage(contentsOfFile: root.appendingPathComponent(path).path) }
        }
        images = loaded
    }
}
private final class ConsoleModel: ObservableObject {
    @Published var size = CGSize(width: 844, height: 390)
    @Published var insets = UIEdgeInsets.zero
    @Published var keys: UInt32 = 0
    let artwork = ConsoleArtwork()
    let screen: UIView
    let controls: MGBAControls
    var onAccessibleKey: ((UInt32) -> Void)?
    init(screen: UIView, controls: MGBAControls) { self.screen = screen; self.controls = controls }
}

/// Objective-C uses this small adapter; the facade, sprite alignment and physical
/// button animation are SwiftUI. The emulator remains behind MGBAEngine.
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
        // ConsoleLayout already applies the parent's measured safe area. Avoid
        // applying it again inside the hosting view (a half-inset visual shift).
        if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
        controller = host
        super.init()
        controller.view.backgroundColor = .clear
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
    @objc var screenFrame: CGRect {
        guard let layout = ConsoleLayout(model: model) else { return .zero }
        return layout.screen
    }
}

private struct ConsoleLayout {
    let facade: Facade
    let board, screen: CGRect
    let visual, hit: [String: CGRect]
    init?(model: ConsoleModel) {
        let w = max(1, model.size.width), h = max(1, model.size.height)
        let family = w/h >= 2 ? "wide" : w/h >= 1.65 ? "classic" : "ipad"
        guard let facade = model.artwork.manifest?.variants[family] else { return nil }
        self.facade = facade
        let safe = CGRect(origin: .zero, size: model.size).inset(by: model.insets)
        let content = facade.openings.values.map(\.rect) + [facade.gameRect.rect]
        let envelope = content.reduce(CGRect.null) { $0.union($1) }.insetBy(dx: -8, dy: -8)
        let scale = max(0.01, min(w/facade.width, h/facade.height, safe.width/envelope.width, safe.height/envelope.height))
        func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat { max(low, min(high, value)) }
        let x = clamp((w-facade.width*scale)/2, safe.minX-envelope.minX*scale, safe.maxX-envelope.maxX*scale)
        let y = clamp((h-facade.height*scale)/2, safe.minY-envelope.minY*scale, safe.maxY-envelope.maxY*scale)
        board = CGRect(x: x, y: y, width: facade.width*scale, height: facade.height*scale)
        func transform(_ rect: CGRect) -> CGRect {
            CGRect(x: x+rect.minX*scale, y: y+rect.minY*scale, width: rect.width*scale, height: rect.height*scale)
        }
        screen = transform(facade.gameRect.rect)
        var visuals: [String: CGRect] = [:], hits: [String: CGRect] = [:]
        for (name, slot) in facade.openings {
            let r = transform(slot.rect)
            visuals[name] = r
            let minimum: CGFloat = name == "l" || name == "r" ? 56 : 44
            let width = min(safe.width, max(r.width+8*scale, minimum))
            let height = min(safe.height, max(r.height+8*scale, minimum))
            hits[name] = CGRect(x: clamp(r.midX-width/2, safe.minX, safe.maxX-width),
                                y: clamp(r.midY-height/2, safe.minY, safe.maxY-height), width: width, height: height)
        }
        visual = visuals; hit = hits
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
        // A frame update must not publish state from within SwiftUI's render pass.
        DispatchQueue.main.async { [weak uiView] in uiView?.configureVisualRegions(visual, hitRegions: hit) }
    }
}
private extension View {
    func placed(in rect: CGRect) -> some View { frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY) }
}
private extension Color {
    init(hex: String) {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0x50469e
        self.init(red: Double((value >> 16) & 255)/255, green: Double((value >> 8) & 255)/255, blue: Double(value & 255)/255)
    }
}
private struct ConsoleView: View {
    @ObservedObject var model: ConsoleModel
    private let names = ["dpad", "a", "b", "l", "r", "select", "start"]
    var body: some View {
        ZStack(alignment: .topLeading) {
            if let layout = ConsoleLayout(model: model), let manifest = model.artwork.manifest {
                Color(hex: layout.facade.shellColor)
                Color(red: 0.03, green: 0.03, blue: 0.05).placed(in: layout.board)
                NativeScreen(view: model.screen).placed(in: layout.screen)
                if let image = model.artwork.images[layout.facade.file] {
                    Image(uiImage: image).resizable().placed(in: layout.board).allowsHitTesting(false).accessibilityHidden(true)
                }
                ForEach(names, id: \.self) { name in
                    if let slot = layout.visual[name], let sprite = manifest.sprites[name], let image = model.artwork.images[sprite.file] {
                        ConsoleButton(name: name, sprite: sprite, image: image, size: slot.size, keys: model.keys)
                            .placed(in: slot).allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                TouchSurface(view: model.controls, layout: layout).frame(width: model.size.width, height: model.size.height)
                // These hit-test-free accessibility elements share the native input path.
                ForEach(names, id: \.self) { name in
                    if let hit = layout.hit[name] {
                        Color.clear.placed(in: hit).allowsHitTesting(false)
                            .accessibilityElement().accessibilityLabel(label(name)).accessibilityAddTraits(.isButton)
                            .accessibilityAction { model.onAccessibleKey?(mask(name)) }
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
            } else {
                Color.black
                Text("Façade manquante : vérifier les ressources du projet.").foregroundStyle(.white).padding()
            }
        }
        .frame(width: model.size.width, height: model.size.height).clipped().ignoresSafeArea()
    }
    private func label(_ name: String) -> String { name == "dpad" ? "Croix directionnelle" : name.uppercased() }
    private func mask(_ name: String) -> UInt32 { ["a":1,"b":2,"select":4,"start":8,"r":256,"l":512,"dpad":128][name] ?? 0 }
}
private struct ConsoleButton: View {
    let name: String
    let sprite: Sprite
    let image: UIImage
    let size: CGSize
    let keys: UInt32
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var dx: Double { Double((keys & 16 != 0 ? 1 : 0) - (keys & 32 != 0 ? 1 : 0)) }
    private var dy: Double { Double((keys & 128 != 0 ? 1 : 0) - (keys & 64 != 0 ? 1 : 0)) }
    private var pressed: Bool {
        let masks: [String: UInt32] = ["a":1,"b":2,"select":4,"start":8,"r":256,"l":512,"dpad":240]
        return keys & (masks[name] ?? 0) != 0
    }
    var body: some View {
        let content = sprite.contentRect
        let factor = min(size.width/content.width, size.height/content.height)
        let isPad = name == "dpad"
        // Offset the entire unmodified PNG so contentRect (not its transparent
        // square canvas) is centred in the physical opening, matching the preview.
        Image(uiImage: image).resizable()
            .frame(width: sprite.width*factor, height: sprite.height*factor)
            .offset(x: (sprite.width/2-content.x-content.width/2)*factor,
                    y: (sprite.height/2-content.y-content.height/2)*factor)
            .frame(width: size.width, height: size.height).clipped()
            .brightness(pressed ? -0.10 : 0)
            .scaleEffect(!isPad && pressed && !reduceMotion ? 0.975 : 1)
            .rotation3DEffect(.degrees(isPad && pressed && !reduceMotion ? 10 : 0),
                              axis: (x: CGFloat(-dy), y: CGFloat(dx), z: isPad && pressed ? 0 : 1), perspective: 0.55)
            .offset(x: isPad && !reduceMotion ? dx : 0,
                    y: reduceMotion ? 0 : isPad ? dy : pressed ? 2 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.065), value: keys)
    }
}
