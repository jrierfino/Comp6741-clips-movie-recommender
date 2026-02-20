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
         (scariness none) (violence medium) (complexity medium) (groupfit good))
  (movie (title "Die Hard") (genre action) (mood intense) (runtime medium)
         (scariness none) (violence high) (complexity easy) (groupfit good))
  (movie (title "Mission: Impossible - Fallout") (genre action) (mood intense) (runtime long)
         (scariness none) (violence high) (complexity medium) (groupfit good))
  (movie (title "Edge of Tomorrow") (genre action) (mood intense) (runtime medium)
         (scariness mild) (violence high) (complexity medium) (groupfit good))

  ; --- Comedy ---
  (movie (title "Superbad") (genre comedy) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "The Grand Budapest Hotel") (genre comedy) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity medium) (groupfit ok))
  (movie (title "Palm Springs") (genre comedy) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity medium) (groupfit good))
  (movie (title "The Hangover") (genre comedy) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "21 Jump Street") (genre comedy) (mood light) (runtime medium)
         (scariness none) (violence medium) (complexity easy) (groupfit good))
  (movie (title "Groundhog Day") (genre comedy) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity medium) (groupfit good))

  ; --- Drama ---
  (movie (title "The Shawshank Redemption") (genre drama) (mood emotional) (runtime long)
         (scariness none) (violence medium) (complexity easy) (groupfit good))
  (movie (title "Whiplash") (genre drama) (mood intense) (runtime medium)
         (scariness none) (violence low) (complexity medium) (groupfit ok))
  (movie (title "Parasite") (genre drama) (mood intense) (runtime medium)
         (scariness mild) (violence medium) (complexity complex) (groupfit ok))
  (movie (title "The Godfather") (genre drama) (mood intense) (runtime long)
         (scariness none) (violence high) (complexity complex) (groupfit ok))
  (movie (title "Fight Club") (genre drama) (mood intense) (runtime medium)
         (scariness mild) (violence high) (complexity complex) (groupfit ok))
  (movie (title "Forrest Gump") (genre drama) (mood emotional) (runtime long)
         (scariness none) (violence medium) (complexity easy) (groupfit good))

  ; --- Horror ---
  (movie (title "The Conjuring") (genre horror) (mood scary) (runtime medium)
         (scariness high) (violence medium) (complexity easy) (groupfit good))
  (movie (title "A Quiet Place") (genre horror) (mood scary) (runtime short)
         (scariness mild) (violence medium) (complexity easy) (groupfit good))
  (movie (title "Hereditary") (genre horror) (mood scary) (runtime long)
         (scariness high) (violence medium) (complexity complex) (groupfit poor))
  (movie (title "It") (genre horror) (mood scary) (runtime long)
         (scariness high) (violence high) (complexity easy) (groupfit good))
  (movie (title "The Babadook") (genre horror) (mood scary) (runtime medium)
         (scariness high) (violence medium) (complexity medium) (groupfit ok))
  (movie (title "Scream") (genre horror) (mood scary) (runtime medium)
         (scariness high) (violence high) (complexity easy) (groupfit good))

  ; --- Thriller ---
  (movie (title "Get Out") (genre thriller) (mood intense) (runtime medium)
         (scariness mild) (violence medium) (complexity medium) (groupfit good))
  (movie (title "Gone Girl") (genre thriller) (mood mindbending) (runtime long)
         (scariness none) (violence medium) (complexity complex) (groupfit ok))
  (movie (title "Knives Out") (genre thriller) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity medium) (groupfit good))
  (movie (title "Se7en") (genre thriller) (mood intense) (runtime medium)
         (scariness mild) (violence high) (complexity medium) (groupfit ok))
  (movie (title "Prisoners") (genre thriller) (mood intense) (runtime long)
         (scariness mild) (violence medium) (complexity complex) (groupfit ok))
  (movie (title "Shutter Island") (genre thriller) (mood mindbending) (runtime medium)
         (scariness mild) (violence medium) (complexity complex) (groupfit ok))

  ; --- Romance ---
  (movie (title "La La Land") (genre romance) (mood emotional) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "10 Things I Hate About You") (genre romance) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "Eternal Sunshine of the Spotless Mind") (genre romance) (mood emotional) (runtime medium)
         (scariness none) (violence low) (complexity complex) (groupfit ok))
  (movie (title "Crazy, Stupid, Love.") (genre romance) (mood light) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "The Notebook") (genre romance) (mood emotional) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "About Time") (genre romance) (mood emotional) (runtime medium)
         (scariness none) (violence low) (complexity medium) (groupfit good))

  ; --- Sci-Fi ---
  (movie (title "Inception") (genre scifi) (mood mindbending) (runtime long)
         (scariness none) (violence medium) (complexity complex) (groupfit good))
  (movie (title "Interstellar") (genre scifi) (mood emotional) (runtime long)
         (scariness none) (violence low) (complexity complex) (groupfit good))
  (movie (title "The Matrix") (genre scifi) (mood intense) (runtime medium)
         (scariness none) (violence high) (complexity medium) (groupfit good))
  (movie (title "Blade Runner 2049") (genre scifi) (mood intense) (runtime long)
         (scariness mild) (violence medium) (complexity complex) (groupfit ok))
  (movie (title "Ex Machina") (genre scifi) (mood mindbending) (runtime medium)
         (scariness mild) (violence low) (complexity complex) (groupfit ok))
  (movie (title "Arrival") (genre scifi) (mood emotional) (runtime medium)
         (scariness none) (violence low) (complexity complex) (groupfit good))

  ; --- Animation ---
  (movie (title "Toy Story") (genre animation) (mood light) (runtime short)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "Spirited Away") (genre animation) (mood mindbending) (runtime medium)
         (scariness mild) (violence low) (complexity medium) (groupfit good))
  (movie (title "Inside Out") (genre animation) (mood emotional) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "Shrek") (genre animation) (mood light) (runtime short)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "Coco") (genre animation) (mood emotional) (runtime medium)
         (scariness none) (violence low) (complexity easy) (groupfit good))
  (movie (title "Your Name") (genre animation) (mood emotional) (runtime medium)
         (scariness none) (violence low) (complexity medium) (groupfit good))
)
