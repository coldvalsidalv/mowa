"""Official gold-set eval: 4 real B1 Pisanie answers from the Państwowa Komisja
exam-standards PDF, each scored by two examiners (A+B) on the five criteria.
We grade each with our endpoint and measure how far the model's scores are from
the real examiners' (averaged) scores. Local/dev only.

To run:
1. Seed the DB: create writingtest@example.com / verbum-test-123 via the admin API.
2. In writing.ts, temporarily add to GradeBody:
     task_override?: ExamTask
     model?: string
   Change the task lookup line to:
     const task = body.task_override ?? TASKS[body?.task_id ?? '']
   Change the model line to:
     const model = body.model ?? env.GEMINI_MODEL ?? DEFAULT_MODEL
3. Run: python3 backend/scripts/goldset_official.py
4. Revert writing.ts (do not commit — client must not control the grading task)."""
import json, time, urllib.request, urllib.error

BASE = "http://127.0.0.1:8787"
CRIT = ["wykonanie_zadania", "poprawnosc_gramatyczna", "slownictwo", "styl", "ortografia_interpunkcja"]

ZESTAW_I = {"type": "pozdrowienia + wypowiedź o hobby",
    "prompt": "a) Proszę napisać pozdrowienia z wakacji do swojego dyrektora/profesora/nauczyciela (25 słów). b) „Każdy ma jakieś zainteresowania” — proszę napisać o swoim hobby (175 słów).",
    "required_points": ["pozdrowienia z wakacji (gdzie, co słychać)", "opis swojego hobby", "dlaczego to hobby jest interesujące"],
    "min_words": 170, "max_words": 230}
ZESTAW_II = {"type": "zaproszenie + list o mieszkaniu",
    "prompt": "a) Proszę zaprosić swoich sąsiadów (starszych państwa) na imieniny/urodziny (30 słów). b) Proszę napisać list do kolegi/koleżanki, w którym opisze Pan/Pani swoje mieszkanie (170 słów).",
    "required_points": ["zaproszenie sąsiadów (okazja, miejsce, czas)", "opis mieszkania", "zachęta do odwiedzin"],
    "min_words": 170, "max_words": 230}
ZESTAW_III = {"type": "ogłoszenie + opowiadanie",
    "prompt": "a) Zgubił/ła Pan/Pani swój zegarek. Proszę napisać ogłoszenie (30 słów). b) „Nie lubię poniedziałków” — proszę napisać opowiadanie (170 słów).",
    "required_points": ["ogłoszenie o zgubie (co, gdzie, kontakt)", "opowiadanie na temat", "spójna narracja z puentą"],
    "min_words": 170, "max_words": 230}

# Texts transcribed from the PDF (examiner error-marks √ and page artifacts removed; student errors kept).
EXAMPLES = [
  {"id": "ex1_psych_86", "task": ZESTAW_I,
   "gold": {"wykonanie_zadania": 3.125, "poprawnosc_gramatyczna": 3.625, "slownictwo": 3.5, "styl": 3.375, "ortografia_interpunkcja": 3.625},
   "text": "Lille, 12 sierpnia 2006 roku. Szanowna Pani Dyrektor! Życzę wszystkiego dobrego z wakacji. Jestem z mężem we Francji, a jest bardzo spokojnie. Mam nadzieję, że wszystko w biurze jest w porządku bezemnie. Dozobaczenia za tydzień! Pozdrawiam. Izabela Dupont. Chciałabym rozmawiać o psychologii, bo to są moje ulubione hobby. Kiedy miałam osiemnaście lat zaczynałam studiować na uniwersytecie w Utrechcie w Holandii. Sądzę, że człowiek jest bardzo interesującym źródłem i dlatego wybierałam sobie psychologię. Istnieją różne kierunki w tej dyscyplinie, na przykład psychologia społeczna, psychologia kliniczna i psychologia medyczna. Interesowałam się najbardziej neuropsychologią. Z mojego punktu widzenia, neuropsychologia jest najładniejszym kierunkiem. Ludzie którzy są neuropsychologami, patrzą na mózg i postępowanie. Przynajmniej pomagają osobom chorym i starym i myśle, że neuropsychologia dlatego jest ładny zawód. Przeczytawszy książkę o neuropsychologii, widziałam że to jest dobry wybór. Jednocześnie uwielbiam zajmować się pacjentom. Pacjenci z uszkodzeniem mózgu mogą się dziwni zachowywać. Zarazem mogą się pojawiać zaburzenia emocji i np. płakać cały dzień. Istotną sprawą dla mnie wtedy jest uspokoić rodzinę pacjenta. Moim zdaniem to jest bardzo ważne i w ogólnie wiadomo mi się wydaję. Zepsuty mózg ma wiele wpływ na postępowanie i osobowość pacjentów. Według mojej opinii jest teraz udowodniony dlaczego neuropsychologia jest taką ciekawą i interesującą dyscypliną."},
  {"id": "ex2_ornit_55", "task": ZESTAW_I,
   "gold": {"wykonanie_zadania": 2.625, "poprawnosc_gramatyczna": 1.625, "slownictwo": 2.5, "styl": 2.375, "ortografia_interpunkcja": 1.875},
   "text": "Droga nauczyciela, pozdrawiam z wakacja na mój miasta Rzimie. Jest piekna i bardzo kulturalne. Ja będę od druga do piata czerwca. Ornitologja nie jest bardzo popularny. Ale, na każdy kraj, laś lub jezioro można zrobić. Dlatego, na każdy miasto są ornitolog (anateurski lub profosionaliski). W początku to tani hobby. Inwestycja na sprzęt jest minimalna: dyskretnie ubrania, stary buty, lornetka i ewentualny kaiąka o ptaki. Potem, żeby kupić dobrych opticzny sprętu, to kostuje! Naj droszej są też podroż (żeby oglądać specyficzna ptaka w drógi konczu Europa). Zima, w Polsce, jest bardzo spokonia pora. Zostaje tylko kilka szykorka, wróbel lub krók. Ale z wisnią, wracają ptaków. To czas na podroże i obserwacje. Bardzo znany miescie jest Biebrza. Uwielbiam ten wielki bagna. Są milionów ptaków. Każdy rok jedziemy tam z pczejacielu. Dwa lata temu oglądaliśmy ten blisko 60 różny gatunek ptaków. Rekordowa! By lis my jak dziecko z nowym zabawa: jaka piekna dudek! Patrz, bielik! Widzałesz ten mływa. Piekni! Niestyty, w jecziń, ptaki migrują i wracają do czeejliszey kraju. I my, ornitology, zostajemy sam w zimna i czekamy na powrot ptakom!"},
  {"id": "ex3_mieszk_94", "task": ZESTAW_II,
   "gold": {"wykonanie_zadania": 3.875, "poprawnosc_gramatyczna": 3.75, "slownictwo": 3.75, "styl": 3.875, "ortografia_interpunkcja": 3.625},
   "text": "Drodzy Państwo! Z okazji moich imieni całym cercem zpraszam na imprezy w Berlinie. Fertyń zaczyna się o godzinie siedemnastej (drugiego marca) w „Klubie Polskich Nieudaczników”. Mam nadzieję że mają państwo czas przyjechać do Berlinu. Z przyjemności powitałabym was! Serdeczne pozdrowienia. Lena. Berlin, 11 lutego 2006 roku. Kochana Malwino! Bardzo się cieszę, że tak szybko odpisałaś. I bardzo mi miło usłyszeć, że u Ciebie i Twojej Rodziny wszystko jest w porządku. W twoim liście spytałaś mnie o moje nowe mieszkanie. Nie chcę się tym chełpić, ale właśnie znalazłyśmy bardzo fajne mieszkanie. Muszę jednak przyznać, że trzeba było duży remont. Mieszkam razem z koleżanką. Ona jest miłą i życzliwą osobą i będzie ci na pewno podobała. Mamy dwa równie duże pokoje (23 m2!). To było dla nas bardzo ważne, bo wtedy jest sprawiedliwe ze względu na czynsz. Mój pokój wychodzi na podworek i jest spokojny i słoneczny. Wszystkie mebli dobrze się pomieściły i w związku z tym pozostało mi wystarczające miejsce, żeby uprawiać yogę. Biurko mam przy okniu, więc mogę przy uczeniu się przyglądać się stojące przed oknem drzewo. Niestety ostatnio brakowało mi czasu na wieszanie zdjęc i plakatów na ścianie. Kuchnia i łazienka są prawdziwie małe, ale zawierają wszystko to, co potrzebne. Mamy jeszcze ładny przedpokój, który kończy się małym pomieszczeniem, gdzie możemy wygodnie siedzieć na fotelach i pogadać. Nasze mieszkanie jest niedaleko od parku. Tam się fajnie spaceruje. Naprawdę nie mogę doczekać twoich odwiedzin. Wtedy możesz wszystko zobaczyć na swoje oczy. Właśnie przygotowuję fajny program zwiedzania Berlina, ale więcej już nie piszę. Ściskam Cię mocno, Lena"},
  {"id": "ex4_ponied_69", "task": ZESTAW_III,
   "gold": {"wykonanie_zadania": 2.5, "poprawnosc_gramatyczna": 2.875, "slownictwo": 2.875, "styl": 3.0, "ortografia_interpunkcja": 2.625},
   "text": "Wczoraj, spacerując w parku im. Jna Nowka w okolicach placu zabaw, zgubiłam stary, pamiątkowy, damski zegarek z wygrawerowanymi inicjałami J. B. Bardzo proszę znalazce o skontaktowanie się ze mna telefonicznie w godzinach wieczorowych nr. 0504875236. CZEKA WYSOKA NAGRODA!!! W litaraturzy i w znanych piosenkach, najmniej lubiany dzień tygodniowy, to poniedziałek. Główny temat, przed wszytkiem piosenek, jest fakt, ze w poniedziałku znaczy się kolejna dniach w któryh ludzi chodzą do pracy. W tym sposób, uniwersalna awersja poniedziałków ma charakter dość proletarealny. Widaje mi się, że tylko osoby, które mają regularą pracę u kogoś uwagą prawiedliwie nie nawiedzić tego dnia, który jest symbolem granicy ich wolności. Osobistnie, ja nie mam żadnij preferencji między dniami tydodniowimi. Nawet lubię początek tygodnia, bo często się nudzę w weck-endach. Ale wiem, że my, które wolimy tygodnie niż weck-endy, które wolimy życie i nie lubimy szarych, długich niedziel, jesteśmy w mniejszości. I to jest dlatego nie lubię poniedziałków – to jest ten jedyny dzień, kiedy nikt nie się śmieje, i zucia ma wygląd depresyjny. Ja nie lubię tego dnia, bo nikt nie go lubi. Ja nie lubię tego dnia, bo inne ludzi zabiją moją radość."},
]

MODELS = ["gemini-3.1-flash-lite"]


def login():
    r = urllib.request.urlopen(urllib.request.Request(
        BASE + "/api/v1/table/users/auth/login-password",
        data=json.dumps({"identity": "writingtest@example.com", "password": "verbum-test-123"}).encode(),
        headers={"Content-Type": "application/json"}))
    return json.load(r)["token"]


def grade(tok, model, ex):
    body = {"model": model, "task_override": ex["task"], "text": ex["text"]}
    for attempt in range(4):
        try:
            r = urllib.request.urlopen(urllib.request.Request(
                BASE + "/api/v1/writing/grade", data=json.dumps(body).encode(),
                headers={"Content-Type": "application/json", "Authorization": f"Bearer {tok}"}), timeout=90)
            return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code in (429, 502, 503, 529):
                time.sleep(4 * (attempt + 1)); continue
            raise
    raise RuntimeError("retries exhausted")


if __name__ == "__main__":
    tok = login()
    for model in MODELS:
        print(f"\n=== {model} — model scores vs examiner gold (abs error) ===")
        print(f"{'essay':16} {'gold%':>5} {'pred%':>5} " + " ".join(f"{c.split('_')[0][:4]:>5}" for c in CRIT) + f"  {'MAE':>4}")
        maes = []
        overall_errs = []
        for ex in EXAMPLES:
            g = ex["gold"]; gold_overall = round(sum(g.values()) / 20 * 100)
            try:
                d = grade(tok, model, ex)
                s = d.get("scores", {})
                missing = [c for c in CRIT if c not in s]
                if missing:
                    print(f"  WARN: backend omitted scores for {missing!r} — skipping example")
                    time.sleep(2); continue
                overall_pct = d.get("overall_percent")
                if overall_pct is None:
                    print(f"  WARN: backend omitted overall_percent — skipping example")
                    time.sleep(2); continue
                diffs = [abs(float(s[c]) - g[c]) for c in CRIT]
                mae = sum(diffs) / len(diffs)
                maes.append(mae); overall_errs.append(abs(overall_pct - gold_overall))
                print(f"{ex['id']:16} {gold_overall:>4}% {overall_pct:>4}% " + " ".join(f"{x:>5.1f}" for x in diffs) + f"  {mae:>4.2f}")
            except Exception as e:
                print(f"{ex['id']:16} ERR {str(e)[:50]}")
            time.sleep(2)
        if maes:
            print(f"  -> mean criterion MAE: {sum(maes)/len(maes):.2f}  |  mean overall-% error: {sum(overall_errs)/len(overall_errs):.0f}pp  (over {len(maes)}/{len(EXAMPLES)} examples)")
