; =========================
; facts.clp
; =========================

; ---------- Templates ----------
(deftemplate movie
  (slot title)
  (slot genre)        ; action comedy drama horror thriller romance scifi animation
  (slot mood)         ; light intense emotional mindbending scary
  (slot runtime)      ; short medium long
  (slot scariness)    ; none mild high
  (slot violence)     ; low medium high
  (slot complexity)   ; easy medium complex
  (slot groupfit))    ; good ok poor

(deftemplate user
  (slot pref-genre)       ; action.. or any
  (slot pref-mood)        ; light.. or any
  (slot pref-runtime)     ; short/medium/long/any
  (slot pref-scariness)   ; none/mild/high/any/unknown
  (slot pref-violence)    ; low/medium/high/any
  (slot pref-complexity)  ; easy/medium/complex/any
  (slot pref-context))    ; solo/group/any

(deftemplate asked
  (slot field))

(deftemplate score
  (slot title)
  (slot points))

(deftemplate disq
  (slot title)
  (slot reason))

(deftemplate explain
  (slot title)
  (slot msg))

(deftemplate phase
  (slot name))

(deftemplate next-rank
  (slot value))

(deftemplate selected
  (slot title)
  (slot rank)
  (slot points))

(deftemplate relaxed
  (slot what))

; ---------- Uncertainty templates ----------
(deftemplate prob-evidence
  (slot title)
  (slot feature)   ; scariness/violence/complexity/mood/runtime
  (slot value)
  (slot cf)        ; certainty factor in [-1,1]
  (slot source))

(deftemplate cf-score
  (slot title)
  (slot cf))

(deftemplate cf-contrib
  (slot title)
  (slot cf)
  (slot why))

(deftemplate cf-pending
  (slot title)
  (slot feature)
  (slot value))

(deftemplate cf-done
  (slot title)
  (slot feature)
  (slot value))

(deftemplate cf-pref-done
  (slot title)
  (slot feature))

(deftemplate fuzzy-degree
  (slot title)
  (slot feature)   ; scariness/violence/complexity/mood/runtime
  (slot label)
  (slot mu)        ; membership in [0,1]
  (slot source))

(deftemplate fuzzy-pref
  (slot feature)
  (slot label)
  (slot mu))

(deftemplate fuzzy-score
  (slot title)
  (slot sum)
  (slot count))

(deftemplate fuzzy-pending
  (slot title)
  (slot feature)
  (slot label))

(deftemplate fuzzy-done
  (slot title)
  (slot feature)
  (slot label))

(deftemplate cf-selected
  (slot title)
  (slot rank)
  (slot cf))

(deftemplate fuzzy-selected
  (slot title)
  (slot rank)
  (slot mu))

(deftemplate final-selected
  (slot title)
  (slot rank)
  (slot value))


; ---------- Initial facts ----------
(deffacts initial-state
  (user (pref-genre any)
        (pref-mood any)
        (pref-runtime any)
        (pref-scariness unknown)
        (pref-violence any)
        (pref-complexity any)
        (pref-context any))
  (phase (name interview)))

; ---------- Movie catalog (48 examples) ----------
(deffacts movie-catalog
  ; --- Action ---
  (movie (title "Mad Max: Fury Road") (genre action) (mood intense) (runtime medium)
         (scariness none) (violence high) (complexity easy) (groupfit good))
  (movie (title "John Wick") (genre action) (mood intense) (runtime medium)
         (scariness none) (violence high) (complexity easy) (groupfit good))
  (movie (title "Spider-Man: Into the Spider-Verse") (genre action) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity medium) (groupfit good))
  (movie (title "Die Hard") (genre action) (mood intense) (runtime medium)
         (scariness none) (violence high) (complexity easy) (groupfit good))
  (movie (title "Mission: Impossible - Fallout") (genre action) (mood intense) (runtime long)
         (scariness none) (violence high) (complexity medium) (groupfit good))
  (movie (title "Edge of Tomorrow") (genre action) (mood intense) (runtime medium)
         (scariness mild) (violence medium) (complexity medium) (groupfit good))

  ; --- Comedy ---
  (movie (title "Superbad") (genre comedy) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "The Grand Budapest Hotel") (genre comedy) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit ok))
  (movie (title "Palm Springs") (genre comedy) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "The Hangover") (genre comedy) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "21 Jump Street") (genre comedy) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "Groundhog Day") (genre comedy) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity medium) (groupfit good))

  ; --- Drama ---
  (movie (title "The Shawshank Redemption") (genre drama) (mood emotional) (runtime long)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "Whiplash") (genre drama) (mood intense) (runtime medium)
         (scariness mild) (violence low) (complexity easy) (groupfit ok))
  (movie (title "Parasite") (genre drama) (mood intense) (runtime medium)
         (scariness mild) (violence medium) (complexity complex) (groupfit ok))
  (movie (title "The Godfather") (genre drama) (mood intense) (runtime long)
         (scariness none) (violence high) (complexity complex) (groupfit ok))
  (movie (title "Fight Club") (genre drama) (mood intense) (runtime medium)
         (scariness mild) (violence high) (complexity complex) (groupfit ok))
  (movie (title "Forrest Gump") (genre drama) (mood light) (runtime long)
         (scariness none) (violence low) (complexity easy) (groupfit good))

  ; --- Horror ---
  (movie (title "The Conjuring") (genre horror) (mood scary) (runtime medium)
         (scariness high) (violence low) (complexity easy) (groupfit good))
  (movie (title "A Quiet Place") (genre horror) (mood scary) (runtime short)
         (scariness high) (violence medium) (complexity easy) (groupfit good))
  (movie (title "Hereditary") (genre horror) (mood scary) (runtime long)
         (scariness high) (violence medium) (complexity complex) (groupfit poor))
  (movie (title "It") (genre horror) (mood scary) (runtime long)
         (scariness high) (violence medium) (complexity medium) (groupfit good))
  (movie (title "The Babadook") (genre horror) (mood scary) (runtime medium)
         (scariness high) (violence low) (complexity easy) (groupfit ok))
  (movie (title "Scream") (genre horror) (mood scary) (runtime medium)
         (scariness high) (violence high) (complexity easy) (groupfit good))

  ; --- Thriller ---
  (movie (title "Get Out") (genre thriller) (mood intense) (runtime medium)
         (scariness mild) (violence medium) (complexity medium) (groupfit good))
  (movie (title "Gone Girl") (genre thriller) (mood mindbending) (runtime long)
         (scariness none) (violence low) (complexity complex) (groupfit ok))
  (movie (title "Knives Out") (genre thriller) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity medium) (groupfit good))
  (movie (title "Se7en") (genre thriller) (mood intense) (runtime medium)
         (scariness high) (violence high) (complexity medium) (groupfit ok))
  (movie (title "Prisoners") (genre thriller) (mood intense) (runtime long)
         (scariness mild) (violence medium) (complexity complex) (groupfit ok))
  (movie (title "Shutter Island") (genre thriller) (mood mindbending) (runtime medium)
         (scariness mild) (violence medium) (complexity complex) (groupfit ok))

  ; --- Romance ---
  (movie (title "La La Land") (genre romance) (mood emotional) (runtime medium)
         (scariness none) (violence low) (complexity medium) (groupfit good))
  (movie (title "10 Things I Hate About You") (genre romance) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "Eternal Sunshine of the Spotless Mind") (genre romance) (mood emotional) (runtime medium)
         (scariness none) (violence medium) (complexity complex) (groupfit ok))
  (movie (title "Crazy, Stupid, Love.") (genre romance) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "The Notebook") (genre romance) (mood emotional) (runtime medium)
         (scariness none) (violence medium) (complexity easy) (groupfit good))
  (movie (title "About Time") (genre romance) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))

  ; --- Sci-Fi ---
  (movie (title "Inception") (genre scifi) (mood mindbending) (runtime long)
         (scariness none) (violence medium) (complexity complex) (groupfit good))
  (movie (title "Interstellar") (genre scifi) (mood emotional) (runtime long)
         (scariness mild) (violence low) (complexity complex) (groupfit good))
  (movie (title "The Matrix") (genre scifi) (mood mindbending) (runtime medium)
         (scariness none) (violence high) (complexity complex) (groupfit good))
  (movie (title "Blade Runner 2049") (genre scifi) (mood emotional) (runtime long)
         (scariness none) (violence medium) (complexity complex) (groupfit ok))
  (movie (title "Ex Machina") (genre scifi) (mood mindbending) (runtime medium)
         (scariness none) (violence low) (complexity medium) (groupfit ok))
  (movie (title "Arrival") (genre scifi) (mood emotional) (runtime medium)
         (scariness none) (violence low) (complexity complex) (groupfit good))

  ; --- Animation ---
  (movie (title "Toy Story") (genre animation) (mood light) (runtime short)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "Spirited Away") (genre animation) (mood mindbending) (runtime medium)
         (scariness none) (violence low) (complexity medium) (groupfit good))
  (movie (title "Inside Out") (genre animation) (mood emotional) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "Shrek") (genre animation) (mood light) (runtime short)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "Coco") (genre animation) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "Your Name") (genre animation) (mood emotional) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
)

; ---------- Probabilistic evidence (Certainty Factors) ----------
(deffacts prob-evidence-facts
  (prob-evidence (title "10 Things I Hate About You") (feature mood) (value light) (cf 0.75)
                 (source "TMDb review inference"))
  (prob-evidence (title "21 Jump Street") (feature mood) (value light) (cf 0.62)
                 (source "TMDb review inference"))
  (prob-evidence (title "Groundhog Day") (feature mood) (value light) (cf 0.62)
                 (source "TMDb review inference"))
  (prob-evidence (title "Hereditary") (feature scariness) (value high) (cf 0.55)
                 (source "TMDb review inference"))
  (prob-evidence (title "Inside Out") (feature mood) (value emotional) (cf 0.55)
                 (source "TMDb review inference"))
  (prob-evidence (title "It") (feature mood) (value scary) (cf 0.55)
                 (source "TMDb review inference"))
  (prob-evidence (title "It") (feature scariness) (value high) (cf 0.73)
                 (source "TMDb review inference"))
  (prob-evidence (title "Shrek") (feature mood) (value light) (cf 0.74)
                 (source "TMDb review inference"))
  (prob-evidence (title "Superbad") (feature mood) (value light) (cf 0.56)
                 (source "TMDb review inference"))
  (prob-evidence (title "The Babadook") (feature scariness) (value high) (cf 0.62)
                 (source "TMDb review inference"))
  (prob-evidence (title "The Conjuring") (feature scariness) (value high) (cf 0.64)
                 (source "TMDb review inference"))
  (prob-evidence (title "The Notebook") (feature mood) (value emotional) (cf 0.62)
                 (source "TMDb review inference"))
)

; ---------- Fuzzy degrees (Possibilistic) ----------
(deffacts fuzzy-degree-facts
  (fuzzy-degree (title "A Quiet Place") (feature scariness) (label high) (mu 1.0)
                (source "TMDb review inference"))
  (fuzzy-degree (title "A Quiet Place") (feature scariness) (label mild) (mu 0.43)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Arrival") (feature mood) (label emotional) (mu 1.0)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Arrival") (feature mood) (label intense) (mu 0.50)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Coco") (feature mood) (label light) (mu 1.0)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Coco") (feature mood) (label emotional) (mu 0.67)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Eternal Sunshine of the Spotless Mind") (feature mood) (label emotional) (mu 1.0)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Eternal Sunshine of the Spotless Mind") (feature mood) (label light) (mu 0.50)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Inside Out") (feature mood) (label emotional) (mu 1.0)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Inside Out") (feature mood) (label light) (mu 0.44)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Palm Springs") (feature mood) (label light) (mu 1.0)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Palm Springs") (feature mood) (label emotional) (mu 0.50)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Prisoners") (feature violence) (label medium) (mu 1.0)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Prisoners") (feature violence) (label high) (mu 0.33)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Shutter Island") (feature scariness) (label mild) (mu 1.0)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Shutter Island") (feature scariness) (label high) (mu 0.50)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Spider-Man: Into the Spider-Verse") (feature mood) (label light) (mu 1.0)
                (source "TMDb review inference"))
  (fuzzy-degree (title "Spider-Man: Into the Spider-Verse") (feature mood) (label emotional) (mu 0.67)
                (source "TMDb review inference"))
)
