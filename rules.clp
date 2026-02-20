; =========================
; rules.clp
; =========================

; ---------- Helper functions ----------

(deffunction ask-choice (?prompt $?choices)
  (printout t crlf ?prompt crlf)
  (printout t "Options: " $?choices crlf "> ")
  (bind ?ans (read))
  ?ans)

(deffunction normalize-any (?x)
  (if (or (eq ?x any) (eq ?x ANY)) then any else ?x))

(deffunction clear-dynamic-facts ()
  (do-for-all-facts ((?a asked)) TRUE (retract ?a))
  (do-for-all-facts ((?s score)) TRUE (retract ?s))
  (do-for-all-facts ((?d disq)) TRUE (retract ?d))
  (do-for-all-facts ((?e explain)) TRUE (retract ?e))
  (do-for-all-facts ((?sel selected)) TRUE (retract ?sel))
  (do-for-all-facts ((?r relaxed)) TRUE (retract ?r)))

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

(deffunction print-explanations (?title)
  (bind ?count 0)
  (do-for-all-facts ((?e explain)) (eq ?e:title ?title)
    (if (< ?count 4) then
      (printout t "   - " ?e:msg crlf)
      (bind ?count (+ ?count 1)))))


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
  ?p <- (phase (name scoring))
  (user (pref-genre ?pg))
  =>
  ; If R24 triggered, prefer genre-only selection (or global default order).
  (if (any-factp ((?r relaxed)) (eq ?r:what final-fallback))
    then
      (select-top3-genre-only ?pg)
    else
      (select-top3-by-score))

  (printout t crlf "=== Recommendations ===" crlf)

  (do-for-all-facts ((?e explain)) (eq ?e:title "SYSTEM")
    (printout t ?e:msg crlf))

  (do-for-all-facts ((?sel selected)) TRUE
    (printout t crlf ?sel:rank ". " ?sel:title " (score: " ?sel:points ")" crlf)
    (print-explanations ?sel:title))

  (printout t crlf "=======================" crlf)

  (retract ?p)
  (assert (phase (name halted)))
  (halt))

