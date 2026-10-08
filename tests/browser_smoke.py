#!/usr/bin/env python3
"""Integration smoke test using actual keyboard movement and visible UI.

Run `python tests/browser_smoke.py`; an isolated local HTTP server is started
automatically. Use --url to exercise an already running development server.
The Chromium browser and Python Playwright package must be installed.
"""

from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
from threading import Thread
from urllib.parse import quote

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "tests" / "artifacts"
STATE = """() => {
  const exposed = window.__imperio;
  const game = window.game || (exposed && (exposed.game || exposed.model || exposed));
  return game && game.state ? JSON.parse(JSON.stringify(game.state)) : null;
}"""


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def screenshot(page, name):
    page.screenshot(path=str(ARTIFACTS / (name + ".png")), full_page=True)


def state(page):
    value = page.evaluate(STATE)
    assert value is not None, "El juego debe exponer window.game o window.__imperio para diagnóstico."
    return value


def press_for(page, key, milliseconds):
    page.keyboard.down(key)
    page.wait_for_timeout(milliseconds)
    page.keyboard.up(key)


def button(page, pattern):
    return page.get_by_role("button", name=re.compile(pattern, re.I)).first


def trade_five(page, side):
    quantity = page.locator("#quantity")
    if quantity.count() and quantity.is_visible():
        quantity.select_option("5")
        page.locator(f'[data-trade="{side}"][data-product="bruma"]').click()
    else:
        quantity = page.locator("input[type=number]").first
        action = button(page, r"Comprar Bruma azul" if side == "buy" else r"Vender Bruma azul")
        if quantity.count() and quantity.is_visible():
            quantity.fill("5")
            action.click()
        else:
            for _ in range(5):
                action.click()


def play(page, url, errors):
    page.goto(url, wait_until="networkidle")
    screenshot(page, "01-menu")
    button(page, r"Nueva partida|Empezar de cero").click()
    page.locator("#enter-city").click()
    page.wait_for_timeout(300)
    initial = state(page)
    assert initial["cash"] == 500, initial
    assert initial["inventory"]["bruma"] == 0
    assert "500" in page.locator("#cash").inner_text()
    for key, axis, direction in [("w", "y", -1), ("s", "y", 1), ("a", "x", -1), ("d", "x", 1)]:
        before = state(page)[axis]
        press_for(page, key, 120)
        assert (state(page)[axis] - before) * direction > 2, f"WASD: {key} debe mover el personaje."
    screenshot(page, "02-barrio")

    # Monfe stands just east of the initial apartment, within E range.
    page.keyboard.press("e")
    page.wait_for_timeout(100)
    assert "monfe" in state(page)["met"], "E debe abrir el diálogo y conocer al socio."
    assert page.get_by_text("Monfe", exact=True).count() > 0
    trade_five(page, "buy")
    bought = state(page)
    assert bought["inventory"]["bruma"] == 5, bought
    assert bought["totalBought"] >= 5
    assert re.search(r"5\s*/\s*20", page.locator("#capacity-label").inner_text())
    assert "Bruma azul" in page.locator("#inventory-mini").inner_text()
    screenshot(page, "03-comercio-monfe")
    page.keyboard.press("Escape")

    # Traverse the street to Lola using D, without changing game coordinates.
    # Holding a key in short segments also verifies repeated animation updates.
    for _ in range(18):
        current = state(page)
        if current["x"] >= 553:
            break
        press_for(page, "d", 90)
    moved = state(page)
    assert moved["x"] - initial["x"] > 200, (initial, moved)
    page.keyboard.press("e")
    page.wait_for_timeout(100)
    assert "lola" in state(page)["met"], (state(page)["x"], state(page)["y"])
    trade_five(page, "sell")
    sold = state(page)
    assert sold["inventory"]["bruma"] == 0, sold
    assert sold["totalSold"] >= 5
    assert sold["mission"] >= 3
    assert sold["cash"] > bought["cash"]
    screenshot(page, "04-venta-lola")
    page.keyboard.press("Escape")

    page.keyboard.press("Escape")
    page.wait_for_timeout(100)
    frozen = state(page)
    press_for(page, "a", 180)
    after = state(page)
    assert after["x"] == frozen["x"], "La pausa bloquea el movimiento."
    screenshot(page, "05-pausa")
    settings = button(page, r"Opciones|Ajustes|Configuración")
    assert settings.is_visible(), "La pausa debe permitir abrir ajustes."
    settings.click()
    page.wait_for_timeout(100)
    slider = page.locator('input[type="range"]').first
    if slider.count() and slider.is_visible():
        volume = slider.input_value()
        slider.press("ArrowLeft")
        if slider.input_value() == volume:
            slider.press("ArrowRight")
        assert slider.input_value() != volume, "El control de volumen debe responder al teclado."
    screenshot(page, "06-ajustes")
    page.keyboard.press("Escape")
    page.keyboard.press("i")
    assert "INVENTARIO Y ESTADÍSTICAS" in page.locator("#panel").inner_text()
    assert "Bruma azul" in page.locator("#panel").inner_text()
    screenshot(page, "08-inventario")
    page.keyboard.press("Escape")
    page.keyboard.press("m")
    assert page.locator("#map-canvas").is_visible()
    assert page.locator(".map-list > div").count() == 6
    assert page.locator(".map-list .locked").count() > 0
    screenshot(page, "09-mapa")
    page.locator("#map-canvas").click(position={"x": 140, "y": 140})
    assert page.evaluate("window.__imperio.mode") == "play", "Marcar destino debe volver al juego."
    save = button(page, r"Guardar")
    if save.is_visible():
        save.click()
        page.wait_for_timeout(80)
    saved = state(page)
    assert page.evaluate("localStorage.getItem('mancebo-robles-save-v1') !== null"), "Debe existir un guardado local."
    page.reload(wait_until="networkidle")
    button(page, r"Continuar partida|Continuar").click()
    page.wait_for_timeout(180)
    restored = state(page)
    for key in ["cash", "inventory", "met", "mission", "totalBought", "totalSold"]:
        assert restored[key] == saved[key], f"La continuación cambia {key}: {restored[key]} != {saved[key]}"
    screenshot(page, "07-continuacion")
    assert not errors, "Errores JavaScript/consola: " + json.dumps(errors, ensure_ascii=False)
    (ARTIFACTS / "failure.png").unlink(missing_ok=True)
    return {"ok": True, "cash": restored["cash"], "mission": restored["mission"],
            "x": restored["x"], "y": restored["y"], "errors": errors}


def responsive_smoke(browser, url):
    results = []
    for width, height in [(390, 844), (800, 450)]:
        context = browser.new_context(viewport={"width": width, "height": height}, is_mobile=True, has_touch=True)
        page = context.new_page()
        errors = []
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.goto(url, wait_until="networkidle")
        screenshot(page, f"responsive-{width}x{height}-menu")
        assert page.evaluate("document.documentElement.scrollWidth") <= width + 1
        for selector in ["#new-game", "#continue-game", "#settings-button"]:
            bounds = page.locator(selector).bounding_box()
            assert bounds["y"] >= 0 and bounds["y"] + bounds["height"] <= height, (
                f"Los botones del menú deben caber en {width}x{height}: {selector}", bounds)
        page.locator("#new-game").tap()
        page.locator("#enter-city").tap()
        assert page.evaluate("window.__imperio.mode") == "play"
        page.wait_for_timeout(150)
        interact = page.get_by_role("button", name="Interactuar", exact=True)
        assert interact.is_visible(), f"Los controles táctiles deben estar disponibles en {width}x{height}."
        start = state(page)
        movement = page.get_by_role("button", name="Derecha", exact=True)
        box = movement.bounding_box()
        page.mouse.move(box["x"] + box["width"] / 2, box["y"] + box["height"] / 2)
        page.mouse.down()
        page.wait_for_timeout(150)
        page.mouse.up()
        assert state(page)["x"] > start["x"] + 5, "El botón direccional debe desplazar al personaje."
        interact.tap()
        assert page.locator("#panel-overlay").is_visible()
        assert "monfe" in state(page)["met"]
        trade_five(page, "buy")
        assert state(page)["inventory"]["bruma"] == 5
        screenshot(page, f"responsive-{width}x{height}-dialog")
        bounds = page.locator("#panel").bounding_box()
        assert bounds["x"] >= -1 and bounds["x"] + bounds["width"] <= width + 1, bounds
        close = page.locator(".close").first
        assert close.is_visible(), "El cierre del diálogo debe ser accesible."
        close.tap()
        page.locator("#pause-button").tap()
        screenshot(page, f"responsive-{width}x{height}-pause")
        assert page.locator("#resume").is_visible()
        assert not errors, errors
        results.append({"width": width, "height": height, "touch_controls": True,
                        "inventory_bruma": state(page)["inventory"]["bruma"], "errors": errors})
        context.close()
    return results


def main():
    global ARTIFACTS
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", help="URL de la aplicación HTML")
    parser.add_argument("--standalone", type=Path, help="HTML empaquetado: servirlo localmente y prohibir solicitudes adicionales")
    parser.add_argument("--headed", action="store_true", help="Mostrar Chromium")
    parser.add_argument("--responsive", action="store_true", help="También probar controles táctiles a390x844 y800x450")
    parser.add_argument("--artifacts-dir", type=Path, default=ARTIFACTS, help="Carpeta de capturas e informe JSON")
    args = parser.parse_args()
    ARTIFACTS = args.artifacts_dir.resolve()
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    server = None
    if not args.url:
        directory = args.standalone.resolve().parent if args.standalone else ROOT
        server = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(directory)))
        Thread(target=server.serve_forever, daemon=True).start()
        relative = quote(args.standalone.name) if args.standalone else "web/index.html"
        args.url = f"http://127.0.0.1:{server.server_port}/{relative}"
    report = {"ok": False, "url": args.url}
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch(executable_path="/usr/bin/chromium", headless=not args.headed,
                                                 args=["--no-sandbox", "--disable-dev-shm-usage"])
            context = browser.new_context(viewport={"width": 1365, "height": 900})
            if args.standalone:
                context.route("**/*", lambda route: route.continue_() if route.request.url == args.url else route.abort())
            page = context.new_page()
            page.set_default_timeout(15000)
            errors = []
            requests = []
            page.on("request", lambda request: requests.append(request.url))
            page.on("pageerror", lambda error: errors.append(str(error)))
            page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)
            try:
                report.update(play(page, args.url, errors))
                if args.standalone:
                    assert requests and all(url == args.url for url in requests), requests
                    report.update({"standalone_html": str(args.standalone.resolve()), "network_requests": requests})
                if args.responsive:
                    report["responsive"] = responsive_smoke(browser, args.url)
            except Exception as error:
                screenshot(page, "failure")
                report.update({"ok": False, "error": str(error), "console_errors": errors})
                raise
            finally:
                (ARTIFACTS / "browser-report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
                browser.close()
    finally:
        if server:
            server.shutdown()
            server.server_close()
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
