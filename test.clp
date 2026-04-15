; =========================
; test_updated.clp
; =========================
; Usage (in CLIPS):
;   (batch* "test_updated.clp")

(clear)
(load "facts.clp")
(load "rules.clp")
(reset)

(deffunction reset-dynamic ()
  (do-for-all-facts ((?u user)) TRUE (retract ?u))
  (do-for-all-facts ((?p phase)) TRUE (retract ?p))
  (do-for-all-facts ((?a asked)) TRUE (retract ?a))
  (do-for-all-facts ((?s score)) TRUE (retract ?s))
  (do-for-all-facts ((?d disq)) TRUE (retract ?d))
  (do-for-all-facts ((?e explain)) TRUE (retract ?e))
  (do-for-all-facts ((?sel selected)) TRUE (retract ?sel))
  (do-for-all-facts ((?r relaxed)) TRUE (retract ?r))
  (do-for-all-facts ((?c cf-score)) TRUE (retract ?c))
  (do-for-all-facts ((?cc cf-contrib)) TRUE (retract ?cc))
  (do-for-all-facts ((?cp cf-pending)) TRUE (retract ?cp))
  (do-for-all-facts ((?cd cf-done)) TRUE (retract ?cd))
  (do-for-all-facts ((?cpd cf-pref-done)) TRUE (retract ?cpd))
  (do-for-all-facts ((?fd fuzzy-score)) TRUE (retract ?fd))
  (do-for-all-facts ((?fp fuzzy-pref)) TRUE (retract ?fp))
  (do-for-all-facts ((?fdeg fuzzy-pending)) TRUE (retract ?fdeg))
  (do-for-all-facts ((?fdn fuzzy-done)) TRUE (retract ?fdn))
  (do-for-all-facts ((?sel cf-selected)) TRUE (retract ?sel))
  (do-for-all-facts ((?sel fuzzy-selected)) TRUE (retract ?sel))
  (do-for-all-facts ((?sel final-selected)) TRUE (retract ?sel)))

(deffunction setup-test (?genre ?mood ?runtime ?scariness ?violence ?complexity ?context)
  (reset-dynamic)
  (assert (user (pref-genre ?genre) (pref-mood ?mood) (pref-runtime ?runtime)
                (pref-scariness ?scariness) (pref-violence ?violence)
                (pref-complexity ?complexity) (pref-context ?context)))
  (assert (phase (name scoring)))
  (assert (asked (field genre)))
  (assert (asked (field mood)))
  (assert (asked (field runtime)))
  (assert (asked (field scariness)))
  (assert (asked (field violence)))
  (assert (asked (field complexity)))
  (assert (asked (field context))))

(deffunction run-test (?name ?genre ?mood ?runtime ?scariness ?violence ?complexity ?context)
  (printout t crlf "=== TEST: " ?name " ===" crlf)
  (setup-test ?genre ?mood ?runtime ?scariness ?violence ?complexity ?context)
  (run)
  (printout t "=== END TEST: " ?name " ===" crlf))

; Helper: print whether a specific title is disqualified
(deffunction print-disq (?title)
  (if (any-factp ((?d disq)) (eq ?d:title ?title)) then
    (printout t "DISQ: " ?title crlf)
  else
    (printout t "OK:   " ?title crlf)))

; Helper: print whether a title is in the final top-3 list
(deffunction print-final-selected (?title)
  (if (any-factp ((?s final-selected)) (eq ?s:title ?title)) then
    (printout t "IN TOP3: " ?title crlf)
  else
    (printout t "NOT IN TOP3: " ?title crlf)))

; Helper: print the certainty-factor score accumulated for a title
(deffunction print-cf-score (?title)
  (bind ?found FALSE)
  (do-for-all-facts ((?s cf-score)) (eq ?s:title ?title)
    (bind ?found TRUE)
    (printout t "CF SCORE: " ?title " = " (round-2 ?s:cf) crlf))
  (if (eq ?found FALSE) then
    (printout t "CF SCORE: " ?title " = 0.0" crlf)))

; Test 1: Low scariness + low violence
; Expectation: movies with scariness=high or violence=high are disqualified.
(run-test "T1 low-scariness-low-violence"
          any any any none low any any)
(printout t "Disqualification checks (expect DISQ):" crlf)
(print-disq "Hereditary")
(print-disq "It")
(print-disq "Scream")
(print-disq "John Wick")

; Test 2: Genre-specific preference
; Expectation: sci-fi titles should rank higher in the final recommendation list.
(run-test "T2 genre-scifi"
          scifi any any any any any any)

; Test 3: CF evidence influence
; Expectation: certainty-factor scores should reflect both general preference
; alignment and movie-specific uncertain evidence where present.
(run-test "T3 cf-evidence"
          any intense any any any any any)
(printout t "CF checks:" crlf)
(print-cf-score "Inception")
(print-cf-score "Mad Max: Fury Road")

; Test 4: Fuzzy influence (runtime=short)
; Expectation: the final recommendation list should reflect fuzzy runtime preference (e.g., "Toy Story").
(run-test "T4 fuzzy-runtime-short"
          animation any short any any any any)
(printout t "Top-3 checks:" crlf)
(print-final-selected "Toy Story")

; Test 5: Fallback activation (force all movies disqualified)
; Expectation: system prints fallback message and returns genre-only list.
(deffunction run-fallback-test ()
  (printout t crlf "=== TEST: T5 forced-fallback ===" crlf)
  (setup-test any any any none low any any)
  (do-for-all-facts ((?m movie)) TRUE
    (assert (disq (title ?m:title) (reason forced))))
  (run)
  (printout t "=== END TEST: T5 forced-fallback ===" crlf))

(run-fallback-test)

; Test 6: Action + intense + high violence (crisp alignment)
; Expectation: action titles like "John Wick" should be in the final top-3.
(run-test "T6 action-intense-high-violence"
          action intense medium any high any any)
(printout t "Top-3 checks:" crlf)
(print-final-selected "John Wick")

; Test 7: Comedy + light + medium runtime (crisp alignment)
; Expectation: catalog entries that match comedy/light/medium strongly should be in the final top-3.
(run-test "T7 comedy-light-medium"
          comedy light medium any any any any)
(printout t "Top-3 checks:" crlf)
(print-final-selected "Superbad")
(print-final-selected "21 Jump Street")
(print-final-selected "Groundhog Day")

; Test 8: Sci-fi + mindbending + long + complex (crisp alignment)
; Expectation: "Inception" should be in the final top-3.
(run-test "T8 scifi-mindbending-long-complex"
          scifi mindbending long any any complex any)
(printout t "Top-3 checks:" crlf)
(print-final-selected "Inception")
