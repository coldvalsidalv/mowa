"""Ad-hoc eval harness: run a small gold-set of B1 essays through the grading
endpoint for several models and print a comparison. Local/dev only."""
import json, os, time, urllib.request

BASE = "http://127.0.0.1:8787"
TASK = {
    "type": "email",
    "prompt": "Napisz e-mail do kolegi z pracy, ktory zastapi Cie podczas Twojego urlopu.",
    "required_points": ["kiedy bedziesz na urlopie", "jakie obowiazki przejac", "gdzie sa dokumenty", "podziekuj i zaproponuj rewans"],
    "min_words": 60, "max_words": 120,
}
CRIT = ["wykonanie_zadania", "poprawnosc_gramatyczna", "slownictwo", "styl", "ortografia_interpunkcja"]

# Gold-set: expected ordering weak(E3) < heavy(E1) < medium(E4) < strong(E2)
ESSAYS = {
    "E1_heavy_no_diacritics": "Czesc Marek! Pisze do ciebie bo ja jade na urlop od poniedzialek do piatek. Ty musisz robic moje obowiazki w pracy, na przyklad odpowiadac na maile i dzwonic do klientow. Dokumenty sa w szafce obok mojego biurka, klucz ma sekretarka. Bardzo dziekuje ci za pomoc, nastepnym razem ja tobie pomoge kiedy ty bedziesz na urlopie. Do zobaczenia! Pozdrawiam, Tomek",
    "E2_strong": "Czesc Marku! Pisze, poniewaz od poniedzialku do piatku bede na urlopie. Czy moglbys przejac moje obowiazki - odpowiadac na maile i dzwonic do klientow? Wszystkie dokumenty znajdziesz w szafce obok mojego biurka, a klucz ma sekretarka. Bardzo Ci dziekuje za pomoc i chetnie zrewanzuje sie, gdy Ty bedziesz na urlopie. Pozdrawiam, Tomek".replace("Czesc","Cześć").replace("Pisze","Piszę").replace("poniewaz","ponieważ").replace("poniedzialku","poniedziałku").replace("piatku","piątku").replace("bede","będę").replace("moglbys","mógłbyś").replace("przejac","przejąć").replace("dzwonic","dzwonić").replace("klientow","klientów").replace("dziekuje","dziękuję").replace("chetnie","chętnie").replace("zrewanzuje","zrewanżuję").replace("bedziesz","będziesz").replace("Marku","Marku"),
    "E4_medium": "Cześć Marku! Piszę do ciebie bo od poniedziałek będę na urlopie do piątek. Musisz robić moje obowiązki, na przykład odpowiadać na maile i dzwonić do klienci. Dokumenty są w szafce, klucz ma sekretarka. Dziękuję za pomoc, następny raz ja pomogę tobie. Pozdrawiam, Tomek",
    "E3_offtask": "Cześć! Dzisiaj jest bardzo ładna pogoda. Lubię pić kawę rano i czytać dobre książki. Mój kot ma na imię Felix i jest czarny. Do widzenia!",
}

MODELS = ["gemini-2.5-flash-lite"]


def login():
    r = urllib.request.urlopen(urllib.request.Request(
        BASE + "/api/v1/table/users/auth/login-password",
        data=json.dumps({"identity": "writingtest@example.com", "password": "verbum-test-123"}).encode(),
        headers={"Content-Type": "application/json"}))
    return json.load(r)["token"]


def grade(tok, model, text):
    body = {"model": model, "task_id": "eval", "task": TASK, "text": text}
    last = None
    for attempt in range(4):  # retry transient 502/429
        t = time.time()
        try:
            r = urllib.request.urlopen(urllib.request.Request(
                BASE + "/api/v1/writing/grade", data=json.dumps(body).encode(),
                headers={"Content-Type": "application/json", "Authorization": f"Bearer {tok}"}), timeout=90)
            return json.load(r), time.time() - t
        except urllib.error.HTTPError as e:
            last = e
            if e.code in (429, 502, 503, 529):
                time.sleep(4 * (attempt + 1))
                continue
            raise
    raise last


tok = login()
for model in MODELS:
    print(f"\n=== {model} ===")
    print(f"{'essay':28} {'wyk':>4} {'gram':>4} {'slow':>4} {'styl':>4} {'ort':>4} {'overall':>7} {'pass':>5} {'errs':>4} {'time':>5}")
    for name, text in ESSAYS.items():
        try:
            d, dt = grade(tok, model, text)
            s = d.get("scores", {})
            cells = " ".join(f"{s.get(c):>4}" for c in CRIT)
            print(f"{name:28} {cells} {d.get('overall_percent'):>6}% {str(d.get('passed_estimate')):>5} {len(d.get('errors',[])):>4} {dt:>4.1f}s")
        except Exception as e:
            print(f"{name:28} ERR {str(e)[:60]}")
        time.sleep(2)  # space calls to avoid provider throttling
