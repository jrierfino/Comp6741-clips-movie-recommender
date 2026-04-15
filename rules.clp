; =========================
; rules.clp
; =========================

; ---------- Helper functions ----------

(deffunction read-answer ()
  ; Normalize console input so validation is case-insensitive.
  (sym-cat (lowcase (str-cat (read)))))

(deffunction ask-choice (?prompt $?choices)
  (printout t crlf ?prompt crlf)
  (printout t "Options: " $?choices crlf "> ")
  (bind ?ans (read-answer))
  (while (not (member$ ?ans $?choices)) do
    (printout t "Invalid input: " ?ans ". Please choose one of: " $?choices crlf "> ")
    (bind ?ans (read-answer)))
  ?ans)

(deffunction normalize-any (?x)
  (if (or (eq ?x any) (eq ?x ANY)) then any else ?x))

(deffunction clear-dynamic-facts ()
  (do-for-all-facts ((?a asked)) TRUE (retract ?a))
  (do-for-all-facts ((?s score)) TRUE (retract ?s))
  (do-for-all-facts ((?d disq)) TRUE (retract ?d))
  (do-for-all-facts ((?e explain)) TRUE (retract ?e))
  (do-for-all-facts ((?sel selected)) TRUE (retract ?sel))
  (do-for-all-facts ((?sel final-selected)) TRUE (retract ?sel))
  (do-for-all-facts ((?r relaxed)) TRUE (retract ?r))
  (do-for-all-facts ((?c cf-score)) TRUE (retract ?c))
  (do-for-all-facts ((?cc cf-contrib)) TRUE (retract ?cc))
  (do-for-all-facts ((?cp cf-pending)) TRUE (retract ?cp))
  (do-for-all-facts ((?cd cf-done)) TRUE (retract ?cd))
  (do-for-all-facts ((?cpd cf-pref-done)) TRUE (retract ?cpd))
  (do-for-all-facts ((?sel cf-selected)) TRUE (retract ?sel))
  (do-for-all-facts ((?fd fuzzy-score)) TRUE (retract ?fd))
  (do-for-all-facts ((?fp fuzzy-pref)) TRUE (retract ?fp))
  (do-for-all-facts ((?fdeg fuzzy-pending)) TRUE (retract ?fdeg))
  (do-for-all-facts ((?fdn fuzzy-done)) TRUE (retract ?fdn))
  (do-for-all-facts ((?sel fuzzy-selected)) TRUE (retract ?sel)))

(deffunction add-points (?title ?delta)
  (do-for-fact ((?s score)) (eq ?s:title ?title)
    (modify ?s (points (+ ?s:points ?delta)))))

(deffunction is-disqualified (?title)
  (if (any-factp ((?d disq)) (eq ?d:title ?title)) then TRUE else FALSE))

(deffunction already-selected (?title)
  (if (any-factp ((?sel selected)) (eq ?sel:title ?title)) then TRUE else FALSE))

(deffunction select-top3-by-score ()
  (do-for-all-facts ((?sel selected)) TRUE (retract ?sel))
  (bind ?rank 1)
  (while (<= ?rank 3) do
    (bind ?bestTitle "")
    (bind ?bestScore -999999)

    (do-for-all-facts ((?sc score)) TRUE
      (bind ?t ?sc:title)
      (bind ?p ?sc:points)
      (if (and (not (is-disqualified ?t))
               (not (already-selected ?t))
               (> ?p ?bestScore))
        then
          (bind ?bestScore ?p)
          (bind ?bestTitle ?t)))

    (if (eq ?bestTitle "") then
      (return))

    (assert (selected (title ?bestTitle) (rank ?rank) (points ?bestScore)))
    (bind ?rank (+ ?rank 1))))

(deffunction select-top3-genre-only (?preferredGenre)
  ; Genre-only fallback: ignore soft scoring; use catalog order within genre.
  ; If preferredGenre is 'any', fall back to global catalog order.
  (do-for-all-facts ((?sel selected)) TRUE (retract ?sel))

  (bind ?rank 1)
  (do-for-all-facts ((?m movie)) TRUE
    (if (and (<= ?rank 3)
             (or (eq ?preferredGenre any) (eq ?m:genre ?preferredGenre)))
      then
        (assert (selected (title ?m:title) (rank ?rank) (points 0)))
        (bind ?rank (+ ?rank 1))))
)

; ---------- Final ranking helpers ----------
(defglobal
  ?*cf-weight* = 5.0
  ?*fuzzy-weight* = 5.0)

(deffunction get-score-points (?title)
  (bind ?p 0)
  (do-for-fact ((?s score)) (eq ?s:title ?title)
    (bind ?p ?s:points))
  ?p)

(deffunction get-cf-score (?title)
  (bind ?c 0)
  (do-for-fact ((?s cf-score)) (eq ?s:title ?title)
    (bind ?c ?s:cf))
  ?c)

(deffunction fuzzy-final (?sum ?count)
  (if (> ?count 0) then (/ ?sum ?count) else 0))

(deffunction round-2 (?n)
  (if (>= ?n 0)
    then (/ (integer (+ (* ?n 100) 0.5)) 100.0)
    else (/ (integer (- (* ?n 100) 0.5)) 100.0)))

(deffunction get-fuzzy-mu (?title)
  (bind ?mu 0)
  (do-for-fact ((?s fuzzy-score)) (eq ?s:title ?title)
    (bind ?mu (fuzzy-final ?s:sum ?s:count)))
  ?mu)

(deffunction final-score (?title)
  (bind ?points (get-score-points ?title))
  (bind ?cf (get-cf-score ?title))
  (bind ?mu (get-fuzzy-mu ?title))
  (+ ?points (* ?*cf-weight* ?cf) (* ?*fuzzy-weight* ?mu)))

(deffunction select-top3-by-final-score ()
  (do-for-all-facts ((?sel final-selected)) TRUE (retract ?sel))
  (bind ?rank 1)
  (while (<= ?rank 3) do
    (bind ?bestTitle "")
    (bind ?bestVal -999999)

    (do-for-all-facts ((?m movie)) TRUE
      (bind ?t ?m:title)
      (if (and (not (is-disqualified ?t))
               (not (any-factp ((?sel final-selected)) (eq ?sel:title ?t))))
        then
          (bind ?val (final-score ?t))
          (if (> ?val ?bestVal) then
            (bind ?bestVal ?val)
            (bind ?bestTitle ?t))))

    (if (eq ?bestTitle "") then
      (return))

    (assert (final-selected (title ?bestTitle) (rank ?rank) (value ?bestVal)))
    (bind ?rank (+ ?rank 1))))

(deffunction select-top3-genre-only-final (?preferredGenre)
  (do-for-all-facts ((?sel final-selected)) TRUE (retract ?sel))
  (bind ?rank 1)
  (do-for-all-facts ((?m movie)) TRUE
    (if (and (<= ?rank 3)
             (or (eq ?preferredGenre any) (eq ?m:genre ?preferredGenre)))
      then
        (assert (final-selected (title ?m:title) (rank ?rank) (value 0)))
        (bind ?rank (+ ?rank 1)))))

(deffunction print-explanations (?title)
  (bind ?count 0)
  (do-for-all-facts ((?e explain)) (eq ?e:title ?title)
    (if (< ?count 4) then
      (printout t "   - " ?e:msg crlf)
      (bind ?count (+ ?count 1)))))

; ---------- Certainty Factors helpers ----------
(deffunction combine-cf (?cf1 ?cf2)
  (if (and (>= ?cf1 0) (>= ?cf2 0)) then
    (+ ?cf1 (* ?cf2 (- 1 ?cf1)))
  else
    (if (and (<= ?cf1 0) (<= ?cf2 0)) then
      (+ ?cf1 (* ?cf2 (+ 1 ?cf1)))
    else
      (/ (+ ?cf1 ?cf2) (- 1 (min (abs ?cf1) (abs ?cf2)))))))

(deffunction select-top3-by-cf ()
  (do-for-all-facts ((?sel cf-selected)) TRUE (retract ?sel))
  (bind ?rank 1)
  (while (<= ?rank 3) do
    (bind ?bestTitle "")
    (bind ?bestCF -999999)

    (do-for-all-facts ((?sc cf-score)) TRUE
      (bind ?t ?sc:title)
      (bind ?c ?sc:cf)
      (if (and (not (is-disqualified ?t))
               (not (any-factp ((?sel cf-selected)) (eq ?sel:title ?t)))
               (> ?c ?bestCF))
        then
          (bind ?bestCF ?c)
          (bind ?bestTitle ?t)))

    (if (eq ?bestTitle "") then
      (return))

    (assert (cf-selected (title ?bestTitle) (rank ?rank) (cf ?bestCF)))
    (bind ?rank (+ ?rank 1))))

; ---------- Fuzzy helpers ----------
(deffunction add-fuzzy (?title ?mu)
  (do-for-fact ((?s fuzzy-score)) (eq ?s:title ?title)
    (modify ?s (sum (+ ?s:sum ?mu)) (count (+ ?s:count 1)))))

(deffunction select-top3-by-fuzzy ()
  (do-for-all-facts ((?sel fuzzy-selected)) TRUE (retract ?sel))
  (bind ?rank 1)
  (while (<= ?rank 3) do
    (bind ?bestTitle "")
    (bind ?bestMu -999999)

    (do-for-all-facts ((?sc fuzzy-score)) TRUE
      (bind ?t ?sc:title)
      (bind ?mu (fuzzy-final ?sc:sum ?sc:count))
      (if (and (not (is-disqualified ?t))
               (not (any-factp ((?sel fuzzy-selected)) (eq ?sel:title ?t)))
               (> ?mu ?bestMu))
        then
          (bind ?bestMu ?mu)
          (bind ?bestTitle ?t)))

    (if (eq ?bestTitle "") then
      (return))

    (assert (fuzzy-selected (title ?bestTitle) (rank ?rank) (mu ?bestMu)))
    (bind ?rank (+ ?rank 1))))

; ---------- Fuzzy preference helpers ----------
(deffunction assert-genre-prefs (?preferred)
  (bind ?genres (create$ action comedy drama horror thriller romance scifi animation))
  (foreach ?g ?genres
    (if (eq ?g ?preferred)
      then (assert (fuzzy-pref (feature genre) (label ?g) (mu 1.0)))
      else (assert (fuzzy-pref (feature genre) (label ?g) (mu 0.0))))))


; =====================================================
; Interview rules
; =====================================================

; R1 Ask genre
(defrule R1-ask-genre
  (phase (name interview))
  ?u <- (user (pref-genre ?g))
  (not (asked (field genre)))
  =>
  (bind ?ans (ask-choice
               "Pick a genre (or type 'any'):"
               action comedy drama horror thriller romance scifi animation any))
  (modify ?u (pref-genre (normalize-any ?ans)))
  (assert (asked (field genre))))

; R2 Ask mood
(defrule R2-ask-mood
  (phase (name interview))
  ?u <- (user (pref-mood ?m))
  (not (asked (field mood)))
  =>
  (bind ?ans (ask-choice
               "What mood/vibe do you want (or 'any')?"
               light intense emotional mindbending scary any))
  (modify ?u (pref-mood (normalize-any ?ans)))
  (assert (asked (field mood))))

; R3 Ask runtime
(defrule R3-ask-runtime
  (phase (name interview))
  ?u <- (user (pref-runtime ?r))
  (not (asked (field runtime)))
  =>
  (bind ?ans (ask-choice
               "How long should it be (or 'any')?"
               short medium long any))
  (modify ?u (pref-runtime (normalize-any ?ans)))
  (assert (asked (field runtime))))

; R4 Ask scariness
(defrule R4-ask-scariness
  (phase (name interview))
  ?u <- (user (pref-scariness ?s))
  (not (asked (field scariness)))
  =>
  (bind ?ans (ask-choice
               "Scariness tolerance (or 'any')?"
               none mild high any))
  (modify ?u (pref-scariness (normalize-any ?ans)))
  (assert (asked (field scariness))))

; R5 Ask violence tolerance
(defrule R5-ask-violence
  (phase (name interview))
  ?u <- (user (pref-violence ?v))
  (not (asked (field violence)))
  =>
  (bind ?ans (ask-choice
               "Violence tolerance (or 'any')?"
               low medium high any))
  (modify ?u (pref-violence (normalize-any ?ans)))
  (assert (asked (field violence))))

; R6 Ask complexity
(defrule R6-ask-complexity
  (phase (name interview))
  ?u <- (user (pref-complexity ?c))
  (not (asked (field complexity)))
  =>
  (bind ?ans (ask-choice
               "How complex should it be (or 'any')?"
               easy medium complex any))
  (modify ?u (pref-complexity (normalize-any ?ans)))
  (assert (asked (field complexity))))

; R7 Ask context (solo/group)
(defrule R7-ask-context
  (phase (name interview))
  ?u <- (user (pref-context ?ctx))
  (not (asked (field context)))
  =>
  (bind ?ans (ask-choice
               "Watching solo or with a group (or 'any')?"
               solo group any))
  (modify ?u (pref-context (normalize-any ?ans)))
  (assert (asked (field context))))


; =====================================================
; Initialization rules
; =====================================================

; R8 Initialize scores
(defrule R8-init-scores
  (phase (name scoring))
  (movie (title ?t))
  (not (score (title ?t)))
  =>
  (assert (score (title ?t) (points 0))))

; R9 Start recommendation phase when all answers are filled
(defrule R9-start-scoring
  ?p <- (phase (name interview))
  (asked (field genre))
  (asked (field mood))
  (asked (field runtime))
  (asked (field scariness))
  (asked (field violence))
  (asked (field complexity))
  (asked (field context))
  =>
  (retract ?p)
  (assert (phase (name scoring))))


; =====================================================
; Hard constraints
; =====================================================

; R10 Disqualify too scary (high) when user wants none
(defrule R10-disq-too-scary-high
  (phase (name scoring))
  (user (pref-scariness none))
  (movie (title ?t) (scariness high))
  (not (disq (title ?t)))
  =>
  (assert (disq (title ?t) (reason too-scary))))

; R11 Disqualify too violent when user wants low
(defrule R11-disq-too-violent
  (phase (name scoring))
  (user (pref-violence low))
  (movie (title ?t) (violence high))
  (not (disq (title ?t)))
  =>
  (assert (disq (title ?t) (reason too-violent))))


; =====================================================
; Soft scoring rules
; =====================================================

; R12 Genre match bonus (+5) + explanation
(defrule R12-genre-match
  (phase (name scoring))
  (user (pref-genre ?pg))
  (test (neq ?pg any))
  (movie (title ?t) (genre ?pg))
  (not (disq (title ?t)))
  =>
  (add-points ?t 5)
  (assert (explain (title ?t) (msg "Matches preferred genre."))))

; R13 Genre mismatch penalty (-2)
(defrule R13-genre-mismatch
  (phase (name scoring))
  (user (pref-genre ?pg))
  (test (neq ?pg any))
  (movie (title ?t) (genre ?g&:(neq ?g ?pg)))
  (not (disq (title ?t)))
  =>
  (add-points ?t -2))

; R14 Mood match bonus (+4) + explanation
(defrule R14-mood-match
  (phase (name scoring))
  (user (pref-mood ?pm))
  (test (neq ?pm any))
  (movie (title ?t) (mood ?pm))
  (not (disq (title ?t)))
  =>
  (add-points ?t 4)
  (assert (explain (title ?t) (msg "Matches desired mood."))))

; R15 Mood partial compatibility: pref=light and movie=emotional (+1)
(defrule R15-mood-partial
  (phase (name scoring))
  (user (pref-mood light))
  (movie (title ?t) (mood emotional))
  (not (disq (title ?t)))
  =>
  (add-points ?t 1))

; R16 Runtime match bonus (+2) + explanation
(defrule R16-runtime-match
  (phase (name scoring))
  (user (pref-runtime ?pr))
  (test (neq ?pr any))
  (movie (title ?t) (runtime ?pr))
  (not (disq (title ?t)))
  =>
  (add-points ?t 2)
  (assert (explain (title ?t) (msg "Fits time available."))))

; R17 Runtime mismatch penalty (-1)
(defrule R17-runtime-mismatch
  (phase (name scoring))
  (user (pref-runtime ?pr))
  (test (neq ?pr any))
  (movie (title ?t) (runtime ?r&:(neq ?r ?pr)))
  (not (disq (title ?t)))
  =>
  (add-points ?t -1))

; R18 Complexity match bonus (+2)
(defrule R18-complexity-match
  (phase (name scoring))
  (user (pref-complexity ?pc))
  (test (neq ?pc any))
  (movie (title ?t) (complexity ?pc))
  (not (disq (title ?t)))
  =>
  (add-points ?t 2))

; R19 Complexity conflict penalty: pref easy and movie complex (-3)
(defrule R19-complexity-conflict
  (phase (name scoring))
  (user (pref-complexity easy))
  (movie (title ?t) (complexity complex))
  (not (disq (title ?t)))
  =>
  (add-points ?t -3))

; R20 Group-fit bonus: pref group and groupfit good (+2) + explanation
(defrule R20-groupfit-bonus
  (phase (name scoring))
  (user (pref-context group))
  (movie (title ?t) (groupfit good))
  (not (disq (title ?t)))
  =>
  (add-points ?t 2)
  (assert (explain (title ?t) (msg "Good for groups."))))

; R21 Group-fit penalty: pref group and groupfit poor (-3)
(defrule R21-groupfit-penalty
  (phase (name scoring))
  (user (pref-context group))
  (movie (title ?t) (groupfit poor))
  (not (disq (title ?t)))
  =>
  (add-points ?t -3))

; R22 Scariness match bonus (+2) (pref-scariness known)
(defrule R22-scariness-match
  (phase (name scoring))
  (user (pref-scariness ?ps))
  (test (and (neq ?ps any) (neq ?ps unknown)))
  (movie (title ?t) (scariness ?ps))
  (not (disq (title ?t)))
  =>
  (add-points ?t 2))

; R23 Violence soft penalty: pref-violence medium and movie high (-1)
(defrule R23-violence-soft-penalty
  (phase (name scoring))
  (user (pref-violence medium))
  (movie (title ?t) (violence high))
  (not (disq (title ?t)))
  =>
  (add-points ?t -1))


; =====================================================
; Probabilistic Uncertainty (Certainty Factors)
; =====================================================

; CF0 Initialize CF scores for each movie
(defrule CF0-init-cf-score
  (phase (name scoring))
  (movie (title ?t))
  (not (cf-score (title ?t)))
  =>
  (assert (cf-score (title ?t) (cf 0))))

; CF0 Initialize pending evidence
(defrule CF0-init-cf-pending
  (phase (name scoring))
  (prob-evidence (title ?t) (feature ?f) (value ?v))
  (not (cf-pending (title ?t) (feature ?f) (value ?v)))
  (not (cf-done (title ?t) (feature ?f) (value ?v)))
  =>
  (assert (cf-pending (title ?t) (feature ?f) (value ?v))))

; CF-Genre match/mismatch (align CF list with user intent)
(defrule CF-G1-genre-match
  (declare (salience 9))
  (phase (name scoring))
  (user (pref-genre ?pg&:(neq ?pg any)))
  (movie (title ?t) (genre ?g))
  (test (eq ?g ?pg))
  (not (cf-pref-done (title ?t) (feature genre)))
  =>
  (assert (cf-contrib (title ?t) (cf 0.6) (why "Genre matches (CF).")))
  (assert (cf-pref-done (title ?t) (feature genre))))

(defrule CF-G2-genre-mismatch
  (declare (salience 9))
  (phase (name scoring))
  (user (pref-genre ?pg&:(neq ?pg any)))
  (movie (title ?t) (genre ?g))
  (test (neq ?g ?pg))
  (not (cf-pref-done (title ?t) (feature genre)))
  =>
  (assert (cf-contrib (title ?t) (cf -0.2) (why "Genre mismatch (CF).")))
  (assert (cf-pref-done (title ?t) (feature genre))))

; CF-Mood match/mismatch
(defrule CF-M1-mood-match
  (declare (salience 9))
  (phase (name scoring))
  (user (pref-mood ?pm&:(neq ?pm any)))
  (movie (title ?t) (mood ?m))
  (test (eq ?m ?pm))
  (not (cf-pref-done (title ?t) (feature mood)))
  =>
  (assert (cf-contrib (title ?t) (cf 0.4) (why "Mood matches (CF).")))
  (assert (cf-pref-done (title ?t) (feature mood))))

(defrule CF-M2-mood-mismatch
  (declare (salience 9))
  (phase (name scoring))
  (user (pref-mood ?pm&:(neq ?pm any)))
  (movie (title ?t) (mood ?m))
  (test (neq ?m ?pm))
  (not (cf-pref-done (title ?t) (feature mood)))
  =>
  (assert (cf-contrib (title ?t) (cf -0.1) (why "Mood mismatch (CF).")))
  (assert (cf-pref-done (title ?t) (feature mood))))

; CF-Runtime match/mismatch
(defrule CF-R1-runtime-match
  (declare (salience 9))
  (phase (name scoring))
  (user (pref-runtime ?pr&:(neq ?pr any)))
  (movie (title ?t) (runtime ?r))
  (test (eq ?r ?pr))
  (not (cf-pref-done (title ?t) (feature runtime)))
  =>
  (assert (cf-contrib (title ?t) (cf 0.3) (why "Runtime matches (CF).")))
  (assert (cf-pref-done (title ?t) (feature runtime))))

(defrule CF-R2-runtime-mismatch
  (declare (salience 9))
  (phase (name scoring))
  (user (pref-runtime ?pr&:(neq ?pr any)))
  (movie (title ?t) (runtime ?r))
  (test (neq ?r ?pr))
  (not (cf-pref-done (title ?t) (feature runtime)))
  =>
  (assert (cf-contrib (title ?t) (cf -0.1) (why "Runtime mismatch (CF).")))
  (assert (cf-pref-done (title ?t) (feature runtime))))

; CF-Complexity match/mismatch
(defrule CF-C1-complexity-match
  (declare (salience 9))
  (phase (name scoring))
  (user (pref-complexity ?pc&:(neq ?pc any)))
  (movie (title ?t) (complexity ?cplx))
  (test (eq ?cplx ?pc))
  (not (cf-pref-done (title ?t) (feature complexity)))
  =>
  (assert (cf-contrib (title ?t) (cf 0.3) (why "Complexity matches (CF).")))
  (assert (cf-pref-done (title ?t) (feature complexity))))

(defrule CF-C2-complexity-mismatch
  (declare (salience 9))
  (phase (name scoring))
  (user (pref-complexity ?pc&:(neq ?pc any)))
  (movie (title ?t) (complexity ?cplx))
  (test (neq ?cplx ?pc))
  (not (cf-pref-done (title ?t) (feature complexity)))
  =>
  (assert (cf-contrib (title ?t) (cf -0.1) (why "Complexity mismatch (CF).")))
  (assert (cf-pref-done (title ?t) (feature complexity))))

; CF1 Scariness match
(defrule CF1-match-scariness
  (declare (salience 10))
  (phase (name scoring))
  ?p <- (cf-pending (title ?t) (feature scariness) (value ?v))
  (user (pref-scariness ?ps&:(and (neq ?ps any) (neq ?ps unknown))))
  (prob-evidence (title ?t) (feature scariness) (value ?v) (cf ?c))
  (test (eq ?v ?ps))
  =>
  (assert (cf-contrib (title ?t) (cf ?c) (why "Scariness matches (uncertain).")))
  (assert (cf-done (title ?t) (feature scariness) (value ?v)))
  (retract ?p))

; CF2 Scariness conflict: user wants none, evidence is mild/high
(defrule CF2-conflict-scariness
  (declare (salience 10))
  (phase (name scoring))
  ?p <- (cf-pending (title ?t) (feature scariness) (value ?v))
  (user (pref-scariness none))
  (prob-evidence (title ?t) (feature scariness) (value ?v) (cf ?c))
  (test (or (eq ?v mild) (eq ?v high)))
  =>
  (bind ?neg (* -1 ?c))
  (assert (cf-contrib (title ?t) (cf ?neg) (why "Scariness conflicts (uncertain).")))
  (assert (cf-done (title ?t) (feature scariness) (value ?v)))
  (retract ?p))

; CF3 Violence match
(defrule CF3-match-violence
  (declare (salience 10))
  (phase (name scoring))
  ?p <- (cf-pending (title ?t) (feature violence) (value ?v))
  (user (pref-violence ?pv&:(neq ?pv any)))
  (prob-evidence (title ?t) (feature violence) (value ?v) (cf ?c))
  (test (eq ?v ?pv))
  =>
  (assert (cf-contrib (title ?t) (cf ?c) (why "Violence level matches (uncertain).")))
  (assert (cf-done (title ?t) (feature violence) (value ?v)))
  (retract ?p))

; CF4 Violence conflict: user wants low, evidence is high
(defrule CF4-conflict-violence
  (declare (salience 10))
  (phase (name scoring))
  ?p <- (cf-pending (title ?t) (feature violence) (value high))
  (user (pref-violence low))
  (prob-evidence (title ?t) (feature violence) (value high) (cf ?c))
  =>
  (bind ?neg (* -1 ?c))
  (assert (cf-contrib (title ?t) (cf ?neg) (why "Violence conflicts (uncertain).")))
  (assert (cf-done (title ?t) (feature violence) (value high)))
  (retract ?p))

; CF5 Complexity match
(defrule CF5-match-complexity
  (declare (salience 10))
  (phase (name scoring))
  ?p <- (cf-pending (title ?t) (feature complexity) (value ?v))
  (user (pref-complexity ?pc&:(neq ?pc any)))
  (prob-evidence (title ?t) (feature complexity) (value ?v) (cf ?c))
  (test (eq ?v ?pc))
  =>
  (assert (cf-contrib (title ?t) (cf ?c) (why "Complexity matches (uncertain).")))
  (assert (cf-done (title ?t) (feature complexity) (value ?v)))
  (retract ?p))

; CF6 Complexity conflict: user wants easy, evidence is complex
(defrule CF6-conflict-complexity
  (declare (salience 10))
  (phase (name scoring))
  ?p <- (cf-pending (title ?t) (feature complexity) (value complex))
  (user (pref-complexity easy))
  (prob-evidence (title ?t) (feature complexity) (value complex) (cf ?c))
  =>
  (bind ?neg (* -1 ?c))
  (assert (cf-contrib (title ?t) (cf ?neg) (why "Complexity conflicts (uncertain).")))
  (assert (cf-done (title ?t) (feature complexity) (value complex)))
  (retract ?p))

; CF7 Mood match
(defrule CF7-match-mood
  (declare (salience 10))
  (phase (name scoring))
  ?p <- (cf-pending (title ?t) (feature mood) (value ?v))
  (user (pref-mood ?pm&:(neq ?pm any)))
  (prob-evidence (title ?t) (feature mood) (value ?v) (cf ?c))
  (test (eq ?v ?pm))
  =>
  (assert (cf-contrib (title ?t) (cf ?c) (why "Mood matches (uncertain).")))
  (assert (cf-done (title ?t) (feature mood) (value ?v)))
  (retract ?p))

; CF8 Runtime match
(defrule CF8-match-runtime
  (declare (salience 10))
  (phase (name scoring))
  ?p <- (cf-pending (title ?t) (feature runtime) (value ?v))
  (user (pref-runtime ?pr&:(neq ?pr any)))
  (prob-evidence (title ?t) (feature runtime) (value ?v) (cf ?c))
  (test (eq ?v ?pr))
  =>
  (assert (cf-contrib (title ?t) (cf ?c) (why "Runtime matches (uncertain).")))
  (assert (cf-done (title ?t) (feature runtime) (value ?v)))
  (retract ?p))

; CF9 Clear pending when no applicable preference (fallback)
(defrule CF9-clear-cf-pending
  (declare (salience -10))
  (phase (name scoring))
  ?p <- (cf-pending (title ?t) (feature ?f) (value ?v))
  =>
  (assert (cf-done (title ?t) (feature ?f) (value ?v)))
  (retract ?p))

; CF10 Combine contributions into cf-score
(defrule CF10-combine-cf
  (declare (salience 5))
  (phase (name scoring))
  ?c <- (cf-contrib (title ?t) (cf ?d))
  ?s <- (cf-score (title ?t) (cf ?cur))
  =>
  (bind ?new (combine-cf ?cur ?d))
  (modify ?s (cf ?new))
  (retract ?c))


; =====================================================
; Possibilistic Uncertainty (Fuzzy Logic)
; =====================================================

; FZ0 Initialize fuzzy scores for each movie
(defrule FZ0-init-fuzzy-score
  (phase (name scoring))
  (movie (title ?t))
  (not (fuzzy-score (title ?t)))
  =>
  (assert (fuzzy-score (title ?t) (sum 0) (count 0))))

; FZ0a Default fuzzy degrees from crisp catalog (mu=1.0)
(defrule FZ0a-default-genre-degree
  (phase (name scoring))
  (movie (title ?t) (genre ?g))
  (not (fuzzy-degree (title ?t) (feature genre) (label ?g)))
  =>
  (assert (fuzzy-degree (title ?t) (feature genre) (label ?g) (mu 1.0) (source "catalog"))))

(defrule FZ0b-default-mood-degree
  (phase (name scoring))
  (movie (title ?t) (mood ?m))
  (not (fuzzy-degree (title ?t) (feature mood) (label ?m)))
  =>
  (assert (fuzzy-degree (title ?t) (feature mood) (label ?m) (mu 1.0) (source "catalog"))))

(defrule FZ0c-default-runtime-degree
  (phase (name scoring))
  (movie (title ?t) (runtime ?r))
  (not (fuzzy-degree (title ?t) (feature runtime) (label ?r)))
  =>
  (assert (fuzzy-degree (title ?t) (feature runtime) (label ?r) (mu 1.0) (source "catalog"))))

(defrule FZ0d-default-scariness-degree
  (phase (name scoring))
  (movie (title ?t) (scariness ?s))
  (not (fuzzy-degree (title ?t) (feature scariness) (label ?s)))
  =>
  (assert (fuzzy-degree (title ?t) (feature scariness) (label ?s) (mu 1.0) (source "catalog"))))

(defrule FZ0e-default-complexity-degree
  (phase (name scoring))
  (movie (title ?t) (complexity ?c))
  (not (fuzzy-degree (title ?t) (feature complexity) (label ?c)))
  =>
  (assert (fuzzy-degree (title ?t) (feature complexity) (label ?c) (mu 1.0) (source "catalog"))))

(defrule FZ0f-default-violence-degree
  (phase (name scoring))
  (movie (title ?t) (violence ?v))
  (not (fuzzy-degree (title ?t) (feature violence) (label ?v)))
  =>
  (assert (fuzzy-degree (title ?t) (feature violence) (label ?v) (mu 1.0) (source "catalog"))))

; FZ0 Initialize pending degrees
(defrule FZ0-init-fuzzy-pending
  (phase (name scoring))
  (fuzzy-degree (title ?t) (feature ?f) (label ?l))
  (not (fuzzy-pending (title ?t) (feature ?f) (label ?l)))
  (not (fuzzy-done (title ?t) (feature ?f) (label ?l)))
  =>
  (assert (fuzzy-pending (title ?t) (feature ?f) (label ?l))))

; FZ1 Scariness preference: none
(defrule FZ1-pref-scariness-none
  (phase (name scoring))
  (user (pref-scariness none))
  (not (fuzzy-pref (feature scariness) (label none)))
  =>
  (assert (fuzzy-pref (feature scariness) (label none) (mu 1.0)))
  (assert (fuzzy-pref (feature scariness) (label mild) (mu 0.2)))
  (assert (fuzzy-pref (feature scariness) (label high) (mu 0.0))))

; FZ1a Genre preference (crisp)
(defrule FZ1a-pref-genre
  (phase (name scoring))
  (user (pref-genre ?pg&:(neq ?pg any)))
  (not (fuzzy-pref (feature genre)))
  =>
  (assert-genre-prefs ?pg))

; FZ2 Scariness preference: mild
(defrule FZ2-pref-scariness-mild
  (phase (name scoring))
  (user (pref-scariness mild))
  (not (fuzzy-pref (feature scariness) (label mild)))
  =>
  (assert (fuzzy-pref (feature scariness) (label mild) (mu 1.0)))
  (assert (fuzzy-pref (feature scariness) (label none) (mu 0.3)))
  (assert (fuzzy-pref (feature scariness) (label high) (mu 0.3))))

; FZ3 Scariness preference: high
(defrule FZ3-pref-scariness-high
  (phase (name scoring))
  (user (pref-scariness high))
  (not (fuzzy-pref (feature scariness) (label high)))
  =>
  (assert (fuzzy-pref (feature scariness) (label high) (mu 1.0)))
  (assert (fuzzy-pref (feature scariness) (label mild) (mu 0.4)))
  (assert (fuzzy-pref (feature scariness) (label none) (mu 0.0))))

; FZ4 Mood preference: light
(defrule FZ4-pref-mood-light
  (phase (name scoring))
  (user (pref-mood light))
  (not (fuzzy-pref (feature mood) (label light)))
  =>
  (assert (fuzzy-pref (feature mood) (label light) (mu 1.0)))
  (assert (fuzzy-pref (feature mood) (label emotional) (mu 0.4)))
  (assert (fuzzy-pref (feature mood) (label intense) (mu 0.0)))
  (assert (fuzzy-pref (feature mood) (label mindbending) (mu 0.0)))
  (assert (fuzzy-pref (feature mood) (label scary) (mu 0.0))))

; FZ5 Mood preference: intense
(defrule FZ5-pref-mood-intense
  (phase (name scoring))
  (user (pref-mood intense))
  (not (fuzzy-pref (feature mood) (label intense)))
  =>
  (assert (fuzzy-pref (feature mood) (label intense) (mu 1.0)))
  (assert (fuzzy-pref (feature mood) (label mindbending) (mu 0.4)))
  (assert (fuzzy-pref (feature mood) (label light) (mu 0.0)))
  (assert (fuzzy-pref (feature mood) (label emotional) (mu 0.0)))
  (assert (fuzzy-pref (feature mood) (label scary) (mu 0.0))))

; FZ6 Mood preference: emotional
(defrule FZ6-pref-mood-emotional
  (phase (name scoring))
  (user (pref-mood emotional))
  (not (fuzzy-pref (feature mood) (label emotional)))
  =>
  (assert (fuzzy-pref (feature mood) (label emotional) (mu 1.0)))
  (assert (fuzzy-pref (feature mood) (label light) (mu 0.3)))
  (assert (fuzzy-pref (feature mood) (label intense) (mu 0.0)))
  (assert (fuzzy-pref (feature mood) (label mindbending) (mu 0.0)))
  (assert (fuzzy-pref (feature mood) (label scary) (mu 0.0))))

; FZ6b Mood preference: mindbending
(defrule FZ6b-pref-mood-mindbending
  (phase (name scoring))
  (user (pref-mood mindbending))
  (not (fuzzy-pref (feature mood) (label mindbending)))
  =>
  (assert (fuzzy-pref (feature mood) (label mindbending) (mu 1.0)))
  (assert (fuzzy-pref (feature mood) (label intense) (mu 0.4)))
  (assert (fuzzy-pref (feature mood) (label light) (mu 0.0)))
  (assert (fuzzy-pref (feature mood) (label emotional) (mu 0.0)))
  (assert (fuzzy-pref (feature mood) (label scary) (mu 0.0))))

; FZ6c Mood preference: scary
(defrule FZ6c-pref-mood-scary
  (phase (name scoring))
  (user (pref-mood scary))
  (not (fuzzy-pref (feature mood) (label scary)))
  =>
  (assert (fuzzy-pref (feature mood) (label scary) (mu 1.0)))
  (assert (fuzzy-pref (feature mood) (label intense) (mu 0.4)))
  (assert (fuzzy-pref (feature mood) (label light) (mu 0.0)))
  (assert (fuzzy-pref (feature mood) (label emotional) (mu 0.0)))
  (assert (fuzzy-pref (feature mood) (label mindbending) (mu 0.0))))

; FZ7 Complexity preference: easy
(defrule FZ7-pref-complexity-easy
  (phase (name scoring))
  (user (pref-complexity easy))
  (not (fuzzy-pref (feature complexity) (label easy)))
  =>
  (assert (fuzzy-pref (feature complexity) (label easy) (mu 1.0)))
  (assert (fuzzy-pref (feature complexity) (label medium) (mu 0.4)))
  (assert (fuzzy-pref (feature complexity) (label complex) (mu 0.0))))

; FZ8 Complexity preference: medium
(defrule FZ8-pref-complexity-medium
  (phase (name scoring))
  (user (pref-complexity medium))
  (not (fuzzy-pref (feature complexity) (label medium)))
  =>
  (assert (fuzzy-pref (feature complexity) (label medium) (mu 1.0)))
  (assert (fuzzy-pref (feature complexity) (label easy) (mu 0.4)))
  (assert (fuzzy-pref (feature complexity) (label complex) (mu 0.4))))

; FZ9 Complexity preference: complex
(defrule FZ9-pref-complexity-complex
  (phase (name scoring))
  (user (pref-complexity complex))
  (not (fuzzy-pref (feature complexity) (label complex)))
  =>
  (assert (fuzzy-pref (feature complexity) (label complex) (mu 1.0)))
  (assert (fuzzy-pref (feature complexity) (label medium) (mu 0.4)))
  (assert (fuzzy-pref (feature complexity) (label easy) (mu 0.0))))

; FZ10 Runtime preference: short
(defrule FZ10-pref-runtime-short
  (phase (name scoring))
  (user (pref-runtime short))
  (not (fuzzy-pref (feature runtime) (label short)))
  =>
  (assert (fuzzy-pref (feature runtime) (label short) (mu 1.0)))
  (assert (fuzzy-pref (feature runtime) (label medium) (mu 0.3)))
  (assert (fuzzy-pref (feature runtime) (label long) (mu 0.0))))

; FZ11 Runtime preference: medium
(defrule FZ11-pref-runtime-medium
  (phase (name scoring))
  (user (pref-runtime medium))
  (not (fuzzy-pref (feature runtime) (label medium)))
  =>
  (assert (fuzzy-pref (feature runtime) (label medium) (mu 1.0)))
  (assert (fuzzy-pref (feature runtime) (label short) (mu 0.3)))
  (assert (fuzzy-pref (feature runtime) (label long) (mu 0.3))))

; FZ12 Runtime preference: long
(defrule FZ12-pref-runtime-long
  (phase (name scoring))
  (user (pref-runtime long))
  (not (fuzzy-pref (feature runtime) (label long)))
  =>
  (assert (fuzzy-pref (feature runtime) (label long) (mu 1.0)))
  (assert (fuzzy-pref (feature runtime) (label medium) (mu 0.3)))
  (assert (fuzzy-pref (feature runtime) (label short) (mu 0.0))))

; FZ12b Violence preference: low
(defrule FZ12b-pref-violence-low
  (phase (name scoring))
  (user (pref-violence low))
  (not (fuzzy-pref (feature violence) (label low)))
  =>
  (assert (fuzzy-pref (feature violence) (label low) (mu 1.0)))
  (assert (fuzzy-pref (feature violence) (label medium) (mu 0.4)))
  (assert (fuzzy-pref (feature violence) (label high) (mu 0.0))))

; FZ12c Violence preference: medium
(defrule FZ12c-pref-violence-medium
  (phase (name scoring))
  (user (pref-violence medium))
  (not (fuzzy-pref (feature violence) (label medium)))
  =>
  (assert (fuzzy-pref (feature violence) (label medium) (mu 1.0)))
  (assert (fuzzy-pref (feature violence) (label low) (mu 0.4)))
  (assert (fuzzy-pref (feature violence) (label high) (mu 0.4))))

; FZ12d Violence preference: high
(defrule FZ12d-pref-violence-high
  (phase (name scoring))
  (user (pref-violence high))
  (not (fuzzy-pref (feature violence) (label high)))
  =>
  (assert (fuzzy-pref (feature violence) (label high) (mu 1.0)))
  (assert (fuzzy-pref (feature violence) (label medium) (mu 0.4)))
  (assert (fuzzy-pref (feature violence) (label low) (mu 0.0))))

; FZ13 Apply fuzzy match and accumulate
(defrule FZ13-apply-fuzzy
  (declare (salience 5))
  (phase (name scoring))
  ?p <- (fuzzy-pending (title ?t) (feature ?f) (label ?l))
  (fuzzy-degree (title ?t) (feature ?f) (label ?l) (mu ?muM))
  (fuzzy-pref (feature ?f) (label ?l) (mu ?muP))
  =>
  (bind ?mu (min ?muM ?muP))
  (add-fuzzy ?t ?mu)
  (assert (fuzzy-done (title ?t) (feature ?f) (label ?l)))
  (retract ?p))

; FZ14 Clear pending when no applicable preference
(defrule FZ14-clear-fuzzy-pending
  (declare (salience -10))
  (phase (name scoring))
  ?p <- (fuzzy-pending (title ?t) (feature ?f) (label ?l))
  =>
  (assert (fuzzy-done (title ?t) (feature ?f) (label ?l)))
  (retract ?p))

; =====================================================
; Fallback rule
; =====================================================

; R24 Final fallback (genre-only):
; IF after filtering there are zero viable candidates
; THEN ignore soft constraints and recommend top entries from preferred genre
; (or global defaults if genre is unknown).
(defrule R25-final-fallback-genre-only
  (phase (name scoring))
  (not (relaxed (what final-fallback)))
  ?u <- (user (pref-genre ?pg))
  =>
  ; Check if any non-disqualified movie exists at this point.
  (bind ?existsViable FALSE)
  (do-for-all-facts ((?m movie)) TRUE
    (if (not (is-disqualified ?m:title)) then
      (bind ?existsViable TRUE)))

  (if (eq ?existsViable FALSE) then
    (assert (explain (title "SYSTEM")
                    (msg "No viable candidates remained after constraints; using genre-only fallback.")))
    ; As a last resort, clear disqualifications to guarantee an output.
    ; (This is only reached when *all* movies are disqualified.)
    (do-for-all-facts ((?d disq)) TRUE (retract ?d))
    (assert (relaxed (what final-fallback)))))


; =====================================================
; Output rule: compute recommendations and print top 3
; =====================================================

(defrule OUTPUT-generate-and-print
  (declare (salience -100))
  ?p <- (phase (name scoring))
  (user (pref-genre ?pg))
  =>
  ; If the final fallback triggered, prefer genre-only selection.
  (if (any-factp ((?r relaxed)) (eq ?r:what final-fallback))
    then
      (select-top3-genre-only-final ?pg)
    else
      (select-top3-by-final-score))

  (printout t crlf "=== Recommendations ===" crlf)

  (do-for-all-facts ((?e explain)) (eq ?e:title "SYSTEM")
    (printout t ?e:msg crlf))

  (do-for-all-facts ((?sel final-selected)) TRUE
    (printout t crlf ?sel:rank ". " ?sel:title " (score: " (round-2 ?sel:value) ")" crlf)
    (print-explanations ?sel:title))

  (retract ?p)
  (assert (phase (name halted)))
  (halt))
