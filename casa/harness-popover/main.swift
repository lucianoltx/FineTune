// Teste comportamental do PopoverHost patchado: abre uma janela colada na borda direita da tela
// (como o popup da barra de menu), um trigger no canto direito dela, mostra o painel e mede.
import AppKit
import SwiftUI

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

guard let screen = NSScreen.main else { fatalError("sem tela") }
let vis = screen.visibleFrame
var failures = 0
@MainActor func check(_ cond: Bool, _ msg: String) { print((cond ? "  ✅ " : "  ❌ ") + msg); if !cond { failures += 1 } }

struct Big: View { var body: some View { Color.red.frame(width: 240, height: 200) } }
struct Bigger: View { var body: some View { Color.blue.frame(width: 320, height: 260) } }

@MainActor
func scenario(name: String, windowOrigin: NSPoint, triggerAt: NSRect, grow: Bool, expectAbove: Bool) {
    print("== \(name)")
    let win = NSWindow(contentRect: NSRect(origin: windowOrigin, size: NSSize(width: 360, height: 300)),
                       styleMask: [.borderless], backing: .buffered, defer: false)
    win.isReleasedWhenClosed = false
    let trigger = NSView(frame: triggerAt)
    win.contentView?.addSubview(trigger)
    win.orderFrontRegardless()

    var presented = true
    let binding = Binding<Bool>(get: { presented }, set: { presented = $0 })
    let coord = PopoverHost<Big>.Coordinator(isPresented: binding)
    coord.showPanel(from: trigger, content: { Big() }, preferredColorScheme: nil, nsAppearance: nil)
    guard let panel = coord.panel else { check(false, "painel não criado"); return }
    let trig = win.convertToScreen(trigger.convert(trigger.bounds, to: nil))
    var f = panel.frame
    print("  tela visível: \(vis)  trigger: \(trig)  painel: \(f)")
    check(f.maxX <= vis.maxX - 8 + 0.5, "borda direita do painel dentro da tela (maxX \(f.maxX) <= \(vis.maxX - 8))")
    check(f.minX >= vis.minX + 8 - 0.5, "borda esquerda dentro da tela")
    if trig.minX + f.width > vis.maxX - 8 {
        check(abs(f.maxX - trig.maxX) < 0.5 || abs(f.maxX - (vis.maxX - 8)) < 0.5, "sem espaço à direita → alinhado à direita do trigger (ou colado na margem)")
    }
    if expectAbove {
        check(f.minY >= trig.maxY, "sem espaço embaixo → painel acima do trigger (minY \(f.minY) >= \(trig.maxY))")
    } else {
        check(abs(f.maxY - (trig.minY - 4)) < 0.5, "painel 4pt abaixo do trigger")
    }
    if grow {
        coord.updateContent({ Bigger() }, preferredColorScheme: nil, nsAppearance: nil)
        f = panel.frame
        print("  após crescer: \(f)")
        check(f.maxX <= vis.maxX - 8 + 0.5, "cresceu e continua dentro da tela")
        check(expectAbove ? f.minY >= trig.maxY : abs(f.maxY - (trig.minY - 4)) < 0.5, "cresceu e manteve a âncora no trigger (não subiu por cima dele)")
    }
    coord.dismissPanel()
    win.orderOut(nil)
}

// 1) popup colado na borda direita, trigger no canto direito (o bug do print)
let rightWin = NSPoint(x: vis.maxX - 360, y: vis.maxY - 300)
scenario(name: "trigger no canto direito da tela", windowOrigin: rightWin,
         triggerAt: NSRect(x: 320, y: 200, width: 30, height: 30), grow: true, expectAbove: false)
// 2) trigger com espaço de sobra (comportamento antigo tem que continuar: alinhado à esquerda)
let leftWin = NSPoint(x: vis.minX + 100, y: vis.maxY - 300)
scenario(name: "trigger com espaço (alinha à esquerda como antes)", windowOrigin: leftWin,
         triggerAt: NSRect(x: 20, y: 200, width: 30, height: 30), grow: false, expectAbove: false)
// 3) trigger perto do rodapé: sem espaço embaixo → vira pra cima
let bottomWin = NSPoint(x: vis.minX + 100, y: vis.minY)
scenario(name: "trigger no rodapé (flip pra cima)", windowOrigin: bottomWin,
         triggerAt: NSRect(x: 20, y: 10, width: 30, height: 30), grow: true, expectAbove: true)

// 4) janela-pai se move com o painel aberto → no próximo resize o painel segue o trigger (achado Codex)
@MainActor func movedScenario() {
    print("== janela-pai movida com painel aberto (segue o trigger)")
    let win = NSWindow(contentRect: NSRect(origin: NSPoint(x: vis.minX + 100, y: vis.maxY - 300), size: NSSize(width: 360, height: 300)),
                       styleMask: [.borderless], backing: .buffered, defer: false)
    win.isReleasedWhenClosed = false
    let trigger = NSView(frame: NSRect(x: 20, y: 200, width: 30, height: 30))
    win.contentView?.addSubview(trigger)
    win.orderFrontRegardless()
    var presented = true
    let coord = PopoverHost<Big>.Coordinator(isPresented: Binding(get: { presented }, set: { presented = $0 }))
    coord.showPanel(from: trigger, content: { Big() }, preferredColorScheme: nil, nsAppearance: nil)
    guard let panel = coord.panel else { check(false, "painel não criado"); return }
    win.setFrameOrigin(NSPoint(x: vis.minX + 600, y: vis.maxY - 300))   // move 500pt pra direita
    coord.updateContent({ Bigger() }, preferredColorScheme: nil, nsAppearance: nil)
    let trig = win.convertToScreen(trigger.convert(trigger.bounds, to: nil))
    let f = panel.frame
    print("  trigger agora: \(trig)  painel: \(f)")
    check(abs(f.minX - trig.minX) < 0.5, "painel acompanhou o trigger em X (minX \(f.minX) == \(trig.minX))")
    check(abs(f.maxY - (trig.minY - 4)) < 0.5, "painel acompanhou o trigger em Y")
    coord.dismissPanel(); win.orderOut(nil)
}
movedScenario()

print(failures == 0 ? "RESULTADO: todos os cenários passaram" : "RESULTADO: \(failures) falha(s)")
exit(failures == 0 ? 0 : 1)
