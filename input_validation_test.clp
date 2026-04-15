; =========================
; input_validation_test.clp
; =========================
; Usage (in CLIPS):
;   (batch* "input_validation_test.clp")
;
; This script exercises interactive input validation by intentionally
; providing invalid answers before the valid ones.

(clear)
(load "facts.clp")
(load "rules.clp")
(reset)
(run)

; Genre: invalid, then valid
actoin
action

; Mood: invalid, then valid
lgiht
light

; Remaining valid answers
short
none
low
easy
solo
