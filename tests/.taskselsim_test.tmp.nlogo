;; NetLogo Code based on the paper:
;; "Analysing honeybees' division of labour in broodcare by a multi-agent model"
;; by Thomas Schmickl and Karl Crailsheim

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MODEL SETUP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  chemical-hunger-signal-diffusion-rate ;; D in equation 1 (though NetLogo's diffuse is used) [cite: 64, 66]
  chemical-hunger-signal-decay-rate     ;; mu in equation 1 [cite: 64]
  max-larva-capacity                    ;; capacity_larva = 0.33 [cite: 65]
  larva-hunger-threshold-cr-low         ;; cr_low = 0.25 [cite: 64]
  adult-bee-max-crop-load             ;; 1 unit [cite: 70]
  adult-bee-consumption-rate-low      ;; cr_low_bee = 0.0004 units/step [cite: 70]
  adult-bee-consumption-rate-flying   ;; cr_high = 0.001 units/step [cite: 70]
  larva-consumption-rate              ;; cr_larva = 0.0004 units/step [cite: 71]
  prob-stop-nursing                   ;; lambda_nursing = 0.005/step [cite: 75]
  prob-stop-storing                   ;; lambda_storing = 0.005/step [cite: 75]
  prob-stop-foraging                  ;; lambda_foraging = 0.001/step [cite: 75]
  theta-reduction-xi                  ;; xi = 0.1 [cite: 79]
  theta-increase-phi                  ;; phi = 0.001 [cite: 79]
  n-non-linearity                     ;; n = 2 for all agents [cite: 81]

  waggle-dance-stimulus-strength
  tremble-dance-stimulus-strength
  unloading-stimulus-strength
  light-stimulus-max ;; For hive entrance
]

patches-own [
  chemical-hunger-signal ;; C(x) in equation 1 [cite: 64]
  is-nectar-store-area?
  is-brood-nest-area?
  is-hive-entrance?
  is-inside-hive?
  light-intensity        ;; Light stimulus for navigation [cite: 67]
  nectar-amount          ;; Nectar stored in comb cells
  waggle-dance-signal    ;; Forager recruitment dance signal [cite: 60, 61]
  tremble-dance-signal   ;; Storer recruitment dance signal [cite: 60, 61]
  unloading-signal       ;; Signal from forager to attract storer [cite: 42, 53]
]

breed [adult-bees adult-bee]
breed [larvae larva]

adult-bees-own [
  task              ;; "no-task", "foraging", "storing", "nursing" [cite: 39, 73]
  crop-load         ;; Current nectar in crop (max 1 unit) [cite: 70]
  theta-foraging    ;; Threshold for foraging task [cite: 74, 75]
  theta-storing     ;; Threshold for storing task [cite: 74, 75]
  theta-nursing     ;; Threshold for nursing task [cite: 74, 75]
  time-searching-for-storer ;; T_search for dance decision [cite: 60]
  is-dancing?
  dance-type        ;; "waggle" or "tremble"
  target-larva      ;; For nurse bees
  ticks-at-current-task
  at-hive-entrance?
]

larvae-own [
  nectar-reserve   ;; v_i(t) (max 0.33 units) [cite: 65]
  is-hungry?       ;; True if nectar_reserve < larva-hunger-threshold-cr-low * max-larva-capacity [cite: 64]
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; INITIALIZATION PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  set-default-shape adult-bees "bee"
  set-default-shape larvae "bug"

  ;; Initialize globals based on paper [cite: 64, 65, 70, 71, 75, 79, 81]
  set chemical-hunger-signal-diffusion-rate 0.5 ;; Paper uses NetLogo's diffuse, rate not specified, assuming a value
  set chemical-hunger-signal-decay-rate 0.1   ;; mu, Paper doesn't specify, assuming a value
  set max-larva-capacity 0.33
  set larva-hunger-threshold-cr-low 0.25
  set adult-bee-max-crop-load 1.0
  set adult-bee-consumption-rate-low 0.0004
  set adult-bee-consumption-rate-flying 0.001
  set larva-consumption-rate 0.0004
  set prob-stop-nursing 0.005
  set prob-stop-storing 0.005
  set prob-stop-foraging 0.001
  set theta-reduction-xi 0.1
  set theta-increase-phi 0.001
  set n-non-linearity 2

  set waggle-dance-stimulus-strength 10 ;; Arbitrary, adjust based on model behavior
  set tremble-dance-stimulus-strength 10 ;; Arbitrary
  set unloading-stimulus-strength 5     ;; Arbitrary

  setup-patches
  setup-agents

  reset-ticks
end

to setup-patches
  resize-world 0 30 0 51

  ask patches [
    ;; Inizializzazione
    set chemical-hunger-signal 0
    set is-nectar-store-area? false
    set is-brood-nest-area? false
    set is-hive-entrance? false
    set nectar-amount 0
    set waggle-dance-signal 0
    set tremble-dance-signal 0
    set unloading-signal 0
    set light-intensity 0
  ]

  ;; Aree designate
  ask patches [
    if pycor > 40 [
      set is-nectar-store-area? true
    ]
    if pycor > 15 and pycor < 35 and pxcor > 5 and pxcor < 25 [
      set is-brood-nest-area? true
    ]
    if pycor = min-pycor [
      set is-hive-entrance? true
    ]
  ]

  ask patches [
    set is-inside-hive? (pycor > min-pycor)  ;; Everything above the entrance is inside
  ]

  ;; Stimolo luminoso: prima assegna 1.0 all'ingresso
  ask patches with [is-hive-entrance?] [
    set light-intensity 1.0
  ]

  ;; Poi calcola la distanza per le altre patch
  let entrance-patches patches with [is-hive-entrance?]
  ask patches with [not is-hive-entrance?] [
    let dist-to-entrance min [distance myself] of entrance-patches
    set light-intensity max (list 0 (1 - (dist-to-entrance / world-height)))
  ]

  ;; Quantità iniziale di nettare
  ask patches with [is-nectar-store-area?] [
    set nectar-amount random-float 10.0
  ]
end

;;; TEST
;; For non-foragers - can't leave hive
to restricted-movement
  ifelse [is-inside-hive?] of patch-ahead 1 [
    fd 1  ;; Can move forward if staying inside
  ] [
    rt random-float 180 - random-float 90  ;; Turn away from exit
  ]
end

;; For foragers - special exit rules
to forager-movement
  ifelse _at_hive_entrance? [
    ;; At entrance - can choose to exit
    if random-float 1.0 < 0.1 [  ;; 10% chance to exit each tick
      face patch pxcor (pycor - 1)  ;; Face outward
      fd 1
    ]
  ] [
    ;; Inside hive - normal movement with restrictions
    ifelse [is-inside-hive?] of patch-ahead 1 [
      fd 1
    ] [
      rt random-float 180 - random-float 90
    ]
  ]
end



to update-patch-visuals
  ask patches [
    ;; First, set base colors for areas
    if is-hive-entrance? [ set pcolor grey + 1 ] ;; Entrance
    if is-nectar-store-area? [ set pcolor brown + 2 ] ;; Storage base color
    if is-brood-nest-area? [ set pcolor red + 2 ]     ;; Brood base color
    ;; Default color for other areas
    if not is-hive-entrance? and not is-nectar-store-area? and not is-brood-nest-area? [ set pcolor grey ]

    ;; Now, apply dynamic scaling based on amounts/signals within relevant areas
    if is-nectar-store-area? [
      ;; Scale brown color based on nectar-amount
      ;; Adjust the maximum value (e.g., 20) if your nectar-amount often exceeds this
      set pcolor scale-color brown nectar-amount 0 20
    ]

    if is-brood-nest-area? [
       ;; Scale red color based on chemical-hunger-signal
       ;; Adjust the maximum value (e.g., 5) if your hunger signal often exceeds this
       set pcolor scale-color red chemical-hunger-signal 0 5
    ]
  ]
end
;;; TEST

to setup-agents
  ;; Initial conditions: 700 adult bees, 100 larvae [cite: 82]
  create-adult-bees 700 [
    setxy random-xcor random-ycor
    set heading random-float 360
    set task "no-task"
    set crop-load random-float adult-bee-max-crop-load
    ;; Initial theta values set to 0.001 for all tasks [cite: 81]
    set theta-foraging 0.001
    set theta-storing 0.001
    set theta-nursing 0.001
    set time-searching-for-storer 0
    set is-dancing? false
    set ticks-at-current-task 0
    set size 0.8
    set color white
  ]

  create-larvae 100 [
    ;; Larvae distributed randomly (normal distribution) around the center of the hive [cite: 83]
    ;; Simplified: random placement in brood nest area
    move-to one-of patches with [is-brood-nest-area? and not any? larvae-here]
    if patch-here = nobody [ die ] ;; if no such patch, remove larva
    if patch-here != nobody [
        set nectar-reserve random-float max-larva-capacity ;; Initial crop loads uniformly randomized [cite: 84]
        set is-hungry? (nectar-reserve < (larva-hunger-threshold-cr-low * max-larva-capacity))
        set color pink
        set size 0.8
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RUNTIME PROCEDURES (per time step)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  ;; Order of execution within a time step (as per paper [cite: 34, 35, 36, 37])
  ;; 1. All patches update their status (decay of chemicals).
  update-patch-stimuli

  ;; 2. All agents emit stimuli, chemicals are diffused.
  ask adult-bees [ emit-stimuli ]
  ask larvae [ emit-hunger-signal ]
  diffuse-chemical-hunger-signal

  ;; === ADD THIS LINE TO UPDATE VISUALS ===
  update-patch-visuals

  ;; 3. All agents consume nectar.
  ask adult-bees [ consume-nectar ]
  ask larvae [ consume-nectar ]

  ;; 4. All adult agents decide to engage or to give up a task.
  ask adult-bees [ decide-task ]

  ;; 5. All adult agents perform behaviour according to their task.
  ask adult-bees [ perform-task-behavior ]
  monitor-foragers
  tick
end

to update-patch-stimuli
  ask patches [
    ;; Decay of non-chemical stimuli (dances, unloading) - immediate disappearance when source stops [cite: 62, 53]
    ;; This is handled by bees stopping emission; here we just ensure no stale signals
    set waggle-dance-signal 0
    set tremble-dance-signal 0
    set unloading-signal 0
  ]
end

to emit-stimuli ;; by adult-bees
  ;; Emit dance signals if dancing
  if is-dancing? [
    if dance-type = "waggle" [
      ask patches in-radius 3 [ set waggle-dance-signal waggle-dance-signal + (waggle-dance-stimulus-strength / (1 + distance myself) ) ]
    ]
    if dance-type = "tremble" [
      ask patches in-radius 3 [ set tremble-dance-signal tremble-dance-signal + (tremble-dance-stimulus-strength / (1 + distance myself) ) ]
    ]
  ]

  ;; Foragers waiting to unload emit unloading stimulus
  if task = "foraging" and _at_hive_entrance? and crop-load > 0.1 and not is-dancing? [ ;; and waiting for storer
    ask patches in-radius 1 [ set unloading-signal unloading-signal + unloading-stimulus-strength ]
  ]
end

to emit-hunger-signal ;; by larvae
  set is-hungry? (nectar-reserve < (larva-hunger-threshold-cr-low * max-larva-capacity))
  if is-hungry? [
    let alpha-i (1 - (nectar-reserve / (larva-hunger-threshold-cr-low * max-larva-capacity)))
    if nectar-reserve >= (larva-hunger-threshold-cr-low * max-larva-capacity) [ set alpha-i 0 ]
    if patch-here != nobody [
      ask patch-here [ set chemical-hunger-signal chemical-hunger-signal + alpha-i ] ;; alpha_i(t) * L_hungry(x) [cite: 64]
    ]
  ]
end

to diffuse-chemical-hunger-signal
  ;; Diffuse and decay chemical hunger signal [cite: 64, 66]
  ;; NetLogo's diffuse uses a fraction of the patch variable to share with neighbors.
  ;; The paper's equation 1 is more complex. We use NetLogo's diffuse and a separate decay.
  diffuse chemical-hunger-signal chemical-hunger-signal-diffusion-rate
  ask patches [
    set chemical-hunger-signal chemical-hunger-signal * (1 - chemical-hunger-signal-decay-rate)
    if chemical-hunger-signal < 0.001 [ set chemical-hunger-signal 0 ] ;; Prevent tiny values
  ]
end

to consume-nectar  ;; by agents (bees and larvae)
  ifelse breed = larvae [
    set nectar-reserve nectar-reserve - larva-consumption-rate
    if nectar-reserve <= 0 [ die ]
  ] [
    ;; Adult bee consumption
    let consumption-rate adult-bee-consumption-rate-low
    if (task = "foraging") and (not at-hive-entrance?) [
      set consumption-rate adult-bee-consumption-rate-flying
    ]
    set crop-load crop-load - consumption-rate
    if crop-load <= 0 [ die ]
  ]
end

to decide-task ;; by adult-bees
  set ticks-at-current-task ticks-at-current-task + 1
  ;; Check if bee gives up current task [cite: 75]
  let give-up-prob 0
  if task = "nursing" [ set give-up-prob prob-stop-nursing ]
  if task = "storing" [ set give-up-prob prob-stop-storing ]
  if task = "foraging" [ set give-up-prob prob-stop-foraging ]

  if random-float 1.0 < give-up-prob [
    set-task-to-unemployed ;; also handles theta increase for abandoned task [cite: 78]
  ]

  ;; If unemployed, decide to engage in a new task [cite: 39, 73]
  if task = "no-task" [
    let current-patch patch-here
    if current-patch != nobody [
      let s-foraging [waggle-dance-signal] of current-patch
      let s-storing [tremble-dance-signal] of current-patch + [unloading-signal] of current-patch ;; foragers also attract storers [cite: 42]
      let s-nursing [chemical-hunger-signal] of current-patch

      let p-foraging (s-foraging ^ n-non-linearity) / ((s-foraging ^ n-non-linearity) + (theta-foraging ^ n-non-linearity))
      let p-storing (s-storing ^ n-non-linearity) / ((s-storing ^ n-non-linearity) + (theta-storing ^ n-non-linearity))
      let p-nursing (s-nursing ^ n-non-linearity) / ((s-nursing ^ n-non-linearity) + (theta-nursing ^ n-non-linearity))
      ;; Choose task based on probabilities (e.g., highest probability or roulette wheel)
      ;; Simplified: check in order, take first one that triggers
      let task-chosen false
      if not task-chosen and random-float 1.0 < p-foraging and s-foraging > 0.01 [; Ensure some stimulus
        set task "foraging"
        set theta-foraging max (list 0 (theta-foraging - theta-reduction-xi))
        set task-chosen true
        set-color-by-task
      ]
      if not task-chosen and random-float 1.0 < p-storing and s-storing > 0.01 [
        set task "storing"
        set theta-storing max (list 0 (theta-storing - theta-reduction-xi))
        set task-chosen true
        set-color-by-task
      ]
      if not task-chosen and random-float 1.0 < p-nursing and s-nursing > 0.01 [
        set task "nursing"
        set theta-nursing max (list 0 (theta-nursing - theta-reduction-xi))
        set task-chosen true
        set-color-by-task
      ]

      ;; If no task was chosen, increase thresholds [cite: 78]
      ifelse not task-chosen [
        if s-foraging <= 0.01 or random-float 1.0 >= p-foraging [ set theta-foraging min (list 1 (theta-foraging + theta-increase-phi)) ]
        if s-storing <= 0.01 or random-float 1.0 >= p-storing [ set theta-storing min (list 1 (theta-storing + theta-increase-phi)) ]
        if s-nursing <= 0.01 or random-float 1.0 >= p-nursing [ set theta-nursing min (list 1 (theta-nursing + theta-increase-phi)) ]
      ] [
        set ticks-at-current-task 0
      ]
    ]
  ]
end

to set-task-to-unemployed
  ;; Increase threshold of the task just abandoned [cite: 78]
  if task = "foraging" [ set theta-foraging min (list 1 (theta-foraging + theta-increase-phi)) ]
  if task = "storing" [ set theta-storing min (list 1 (theta-storing + theta-increase-phi)) ]
  if task = "nursing" [ set theta-nursing min (list 1 (theta-nursing + theta-increase-phi)) ]

  set task "no-task"
  set is-dancing? false ;; Stop dancing if any
  set dance-type ""
  set target-larva nobody
  set-color-by-task
  set ticks-at-current-task 0
end


to perform-task-behavior ;; by adult-bees
  if task = "no-task" [
    random-movement
  ]
  if task = "foraging" [
    behavior-forager
  ]
  if task = "storing" [
    behavior-storer
  ]
  if task = "nursing" [
    behavior-nurse
  ]
  if patch-here = nobody [ die ] ;; if moved out of world
end

to random-movement
  rt random-float 50 - random-float 50
  fd 1
end

to behavior-forager
  ;; Leave hive with low crop load, fly to nectar source, fill crop, return to entrance [cite: 40, 41]
  ;; Emit unloading stimulus, then random movement, then dance, then leave again [cite: 42, 43, 44]
  set is-dancing? false ; foragers don't dance while foraging, only after returning
  if not_at_hive_entrance? and crop-load < (adult-bee-max-crop-load * 0.9) [
    ;; Simplified: move towards a fixed nectar source outside the hive
    ;; For this example, let's assume nectar source is far below min-pycor
    face patch 15 (min-pycor - 10)
    fd 1
    if pycor < min-pycor - 5 [ ;; Reached "nectar source"
      set crop-load adult-bee-max-crop-load

  ]
  if crop-load >= (adult-bee-max-crop-load * 0.9) and not_at_hive_entrance? [
    ;; Fly back to entrance
    let entrance-patch one-of patches with [is-hive-entrance?]
    ifelse entrance-patch != nobody [
        face entrance-patch
        fd 1
        if distance entrance-patch < 2 [ move-to entrance-patch ]
    ] [ random-movement ] ;; if no entrance defined
  ] if _at_hive_entrance? and crop-load > 0.1 [
    ;; At entrance, try to unload
    set time-searching-for-storer time-searching-for-storer + 1
    ;; Unloading logic is implicit: storer bees will react to unloading signal
    ;; Dance decision after some time
    if time-searching-for-storer > 10 and not is-dancing? [ ;; Give some time to be unloaded before dancing
        if time-searching-for-storer <= 20 [ ;; Waggle dance if T_search <= 20 [cite: 60]
            set is-dancing? true
            set dance-type "waggle"
            set-color-by-task ;; Update color if needed
    ] if time-searching-for-storer >= 50 [ ;; Tremble dance if T_search >= 50 [cite: 60]
            set is-dancing? true
            set dance-type "tremble"
            set-color-by-task
      ]
    ]
    if crop-load < 0.1 [;; If unloaded
        set time-searching-for-storer 0
        set is-dancing? false
        random-movement ;; Random movement in hive [cite: 43]
        ;; Then leave hive again (will happen in next iteration if still forager)
  ]
    random-movement ;; slight movement while waiting/dancing
] ifelse crop-load < 0.1 and _at_hive_entrance? [;; unloaded, prepare for next trip
      set is-dancing? false
      set time-searching-for-storer 0
      ;; Leave hive: move away from center towards outside
      ifelse patch-here != nobody and [light-intensity] of patch-here < 0.9 [ ;; navigate by light to exit [cite: 67]
          face one-of patches with [is-hive-entrance?]
          bk 1 ;; move out
       ] [
          rt random-float 90 - random-float 45
          fd 1
]
][
    random-movement
]
end

to behavior-storer
  ;; Wait near entrance for foragers, take crop load, go to storage area, drop nectar, return to entrance [cite: 45, 46, 47]
  set is-dancing? false
  let current-p patch-here
  if current-p != nobody [
    ifelse crop-load < (adult-bee-max-crop-load * 0.8) [ ;; If not full, look for foragers
      ;; Navigate towards entrance (higher light) [cite: 67]
      let potential-targets patches in-radius 3 with [unloading-signal > 0 and any? adult-bees-here with [task = "foraging" and crop-load > 0.5]]
      ifelse any? potential-targets [
          let target-forager one-of (adult-bees-on one-of potential-targets with [task = "foraging" and crop-load > 0.5])
          if target-forager != nobody [
              face target-forager
              ifelse distance target-forager < 1.5 [
                  transfer-nectar-from target-forager
        ][fd 1 ]
        ]
      ][ ;; No forager, move towards entrance area
          ifelse [light-intensity] of current-p < 0.8 [
              let target-patch max-one-of patches in-cone 3 90 [light-intensity]
              ifelse target-patch != nobody [ face target-patch fd 1 ] [ random-movement ]
        ][
              random-movement ;; Wait near entrance
        ]
      ]


    ] [ ;; Crop is full, go to storage area
      ;; Navigate towards storage area (darker, designated area)
      let storage-patches patches with [is-nectar-store-area?]
      ifelse any? storage-patches [
        let target-patch min-one-of (storage-patches in-cone 10 180) [distance myself] ;; find closest storage patch
        ifelse target-patch != nobody [
          face target-patch
          ifelse distance target-patch < 1.5 [
            move-to target-patch
            ask patch-here [ set nectar-amount nectar-amount + ([crop-load] of myself * 0.9) ] ;; Deposit 90%
            set crop-load crop-load * 0.1
        ][fd 1 ]
    ][ random-movement ]
    ][ random-movement ] ;; No storage area defined
    ]
  ]
end

to transfer-nectar-from [forager]
  let amount-to-transfer ([crop-load] of forager * 0.9) ;; Storer takes most of it
  if crop-load + amount-to-transfer > adult-bee-max-crop-load [
    set amount-to-transfer adult-bee-max-crop-load - crop-load
  ]
  if amount-to-transfer > 0 [
    set crop-load crop-load + amount-to-transfer
    ask forager [
      set crop-load crop-load - amount-to-transfer
      set time-searching-for-storer 0 ;; Reset forager's search time
      set is-dancing? false ;; stop trying to dance once unloading starts
    ]
  ]
end

to behavior-nurse
  ;; Nurse bee behavior:
  ;; - If low on nectar, seek honey (darker patches)
  ;; - Else, find and feed hungry larvae

  set is-dancing? false
  let current-p patch-here

  if current-p != nobody [

    ;; === Step 1: Needs nectar refill? ===
    ifelse crop-load < 0.1 [
      let honey-patches patches with [is-nectar-store-area? and nectar-amount > 0.1]
      ifelse any? honey-patches [
        let target-honey-patch min-one-of (honey-patches in-cone 10 180) [distance myself]
        ifelse target-honey-patch != nobody [
          face target-honey-patch
          ifelse distance target-honey-patch < 1.5 [
            move-to target-honey-patch
            let amount-to-take min (list (adult-bee-max-crop-load - crop-load) ([nectar-amount] of patch-here * 0.5))
            set crop-load crop-load + amount-to-take
            ask patch-here [ set nectar-amount nectar-amount - amount-to-take ]
          ] [
            fd 1
          ]
        ] [
          random-movement
        ]
      ] [
        random-movement
      ]
      set target-larva nobody
    ]

    ;; === Step 2: Has nectar – find larva ===
     [
      ;; If no target or invalid/hungry too far, find new one
      if not is-turtle? target-larva or not [is-hungry?] of target-larva or distance target-larva > 5 [
        let hungry-larvae larvae with [is-hungry?] in-radius 10
        ifelse any? hungry-larvae [
          let best-patch max-one-of (patches in-cone 5 90 with [any? larvae-here with [is-hungry?]]) [chemical-hunger-signal]
          ifelse best-patch != nobody [
            set target-larva one-of (larvae-on best-patch) with [is-hungry?]
            ifelse target-larva != nobody [
              face target-larva
              fd 1
            ] [
              random-movement
            ]
          ] [
            random-movement
          ]
        ] [
          let brood-patch one-of patches with [is-brood-nest-area?]
          ifelse brood-patch != nobody [
            face brood-patch
            fd 0.5
          ] [
            random-movement
          ]
        ]
      ]

      ;; === Step 3: Try to feed target larva ===
      if is-turtle? target-larva and target-larva != nobody [
        let same-patch? false
        let larva-hungry? false

        if is-turtle? target-larva [
          set same-patch? ([patch-here] of target-larva = patch-here)
          set larva-hungry? [is-hungry?] of target-larva
        ]

        ifelse same-patch? and larva-hungry? [
          let amount-to-feed min (list (crop-load * 0.2) ([max-larva-capacity] of target-larva - [nectar-reserve] of target-larva))
          ifelse amount-to-feed > 0.001 [
            ask target-larva [ set nectar-reserve nectar-reserve + amount-to-feed ]
            set crop-load crop-load - amount-to-feed
            if not [is-hungry?] of target-larva or crop-load < 0.05 [
              set target-larva nobody
            ]
          ] [
            set target-larva nobody ;; cannot feed
          ]
        ] [
          ifelse is-turtle? target-larva [
            face target-larva
            fd 1
          ]  [
            set target-larva nobody
            random-movement
          ]
        ]
      ]
    ]
  ]
end





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; HELPER PROCEDURES & REPORTERS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report _at_hive_entrance?
  report patch-here != nobody and [is-hive-entrance?] of patch-here
end

to-report not_at_hive_entrance?
  report patch-here = nobody or not [is-hive-entrance?] of patch-here
end

to set-color-by-task ;; agent procedure
  if task = "no-task" [ set color white ]
  if task = "foraging" [
      ifelse is-dancing? and dance-type = "waggle" [
      set color orange
    ] [
      ifelse is-dancing? and dance-type = "tremble" [
        set color yellow
    ] [
      set color green
      ]
    ]
  ]
  if task = "storing" [ set color cyan ]
  if task = "nursing" [ set color magenta ]
end

to monitor-foragers
  let foragers count adult-bees with [task = "foraging"]
  let at-entrance count adult-bees with [task = "foraging" and _at_hive_entrance?]
  let dancing count adult-bees with [task = "foraging" and is-dancing?]

  output-print (word "Foragers: " foragers " | At entrance: " at-entrance " | Dancing: " dancing)
end

;; Placeholder for NetLogo File End
@#$#@#$#@
GRAPHICS-WINDOW
413
10
1037
1053
-1
-1
20.0
1
10
1
1
1
0
1
1
1
0
30
0
51
0
0
1
ticks
30.0

BUTTON
54
108
120
141
setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
58
204
121
237
go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

bee
true
0
Polygon -1184463 true false 152 149 77 163 67 195 67 211 74 234 85 252 100 264 116 276 134 286 151 300 167 285 182 278 206 260 220 242 226 218 226 195 222 166
Polygon -16777216 true false 150 149 128 151 114 151 98 145 80 122 80 103 81 83 95 67 117 58 141 54 151 53 177 55 195 66 207 82 211 94 211 116 204 139 189 149 171 152
Polygon -7500403 true true 151 54 119 59 96 60 81 50 78 39 87 25 103 18 115 23 121 13 150 1 180 14 189 23 197 17 210 19 222 30 222 44 212 57 192 58
Polygon -16777216 true false 70 185 74 171 223 172 224 186
Polygon -16777216 true false 67 211 71 226 224 226 225 211 67 211
Polygon -16777216 true false 91 257 106 269 195 269 211 255
Line -1 false 144 100 70 87
Line -1 false 70 87 45 87
Line -1 false 45 86 26 97
Line -1 false 26 96 22 115
Line -1 false 22 115 25 130
Line -1 false 26 131 37 141
Line -1 false 37 141 55 144
Line -1 false 55 143 143 101
Line -1 false 141 100 227 138
Line -1 false 227 138 241 137
Line -1 false 241 137 249 129
Line -1 false 249 129 254 110
Line -1 false 253 108 248 97
Line -1 false 249 95 235 82
Line -1 false 235 82 144 100

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
