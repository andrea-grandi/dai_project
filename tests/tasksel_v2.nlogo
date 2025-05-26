globals [
  total-nectar
  hive-left
  hive-right
  hive-bottom
  hive-top
  flower
  total-bees
  total-larvae
  nurse-specialists
  storer-specialists
  forager-specialists
]

breed [ foragers forager ]
breed [ storers storer ]
breed [ nurses nurse ]
breed [ unemployeds unemployed ]
breed [ larvae larva ]
breed [ flowers flower-agent ]

patches-own [
  nursing-stimulus    ; Chemical hunger signal from larvae
  foraging-stimulus   ; Waggle dance stimulus
  storing-stimulus    ; Tremble dance/storing stimulus
  nectar-stored       ; Nectar in this cell
  is-brood-cell?      ; True if cell contains larva
  is-storage-cell?    ; True if storage area
  pheromone-decay     ; Rate of pheromone decay
  pheromone-diffusion ; Diffusion rate of pheromones
]

turtles-own [
  task-state         ; Current task: "foraging", "storing", "nursing", "no-task"
  activity-state     ; Current activity (e.g., "fly-out", "unload")
  nectar-load        ; Current nectar carried (0-1.0)
  theta-foraging     ; Threshold for foraging task
  theta-storing      ; Threshold for storing task
  theta-nursing      ; Threshold for nursing task
  search-time        ; Time spent searching for storers (foragers)
  age                ; Age of the bee in ticks
  specialization     ; Degree of specialization (0-1)
  last-task          ; Last task performed
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; SETUP PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all
  setup-hive
  setup-flower
  setup-patches
  setup-bees
  setup-larvae
  reset-ticks
  set total-nectar 0
  set total-bees count turtles with [breed != flowers and breed != larvae]
  set total-larvae count larvae
  update-specialization-counts
end

to setup-hive
  ;; Define hive boundaries on the right third of the world
  set hive-left max-pxcor - (world-width / 2)
  set hive-right max-pxcor
  set hive-bottom min-pycor + 3
  set hive-top max-pycor - 3

  ;; Draw the hive with yellow and red border
  ask patches with [
    pxcor >= hive-left and pxcor <= hive-right and
    pycor >= hive-bottom and pycor <= hive-top
  ] [
    set pcolor yellow
  ]

  ;; Draw red border
  ask patches with [
    (pxcor = hive-left or pxcor = hive-right or
     pycor = hive-bottom or pycor = hive-top) and
    pxcor >= hive-left and pxcor <= hive-right and
    pycor >= hive-bottom and pycor <= hive-top
  ] [
    set pcolor red
  ]

  ;; Hive aperture at bottom-left corner of hive
  ask patch hive-left hive-bottom [
    set pcolor black
  ]
end

to setup-flower
  ;; Clear any existing flowers first
  ask flowers [ die ]

  ;; Calculate fixed position for the flower (left of hive entrance)
  let flower-x hive-left - 5  ; 5 patches left of hive entrance
  let flower-y hive-bottom    ; Same height as hive entrance

  ;; Create the flower at this fixed position
  ask patch flower-x flower-y [
    sprout-flowers 1 [
      set shape "flower"
      set color violet
      set size 1.5
      set heading 0
      set flower self
    ]
  ]
end

to setup-patches
  ;; Initialize all patches
  ask patches [
    set is-brood-cell? false
    set is-storage-cell? false
    set nectar-stored 0
    set pcolor black
    set pheromone-decay 0.05
    set pheromone-diffusion 0.1

    ;; Only set hive properties for patches inside hive
    if (pxcor >= hive-left and pxcor <= hive-right and
        pycor >= hive-bottom and pycor <= hive-top) [
      ;; Brood area in center of hive
      set is-brood-cell? (distancexy (hive-left + (hive-right - hive-left) / 2)
                                   (hive-bottom + (hive-top - hive-bottom) / 2) < 10)
      ;; Storage area at top of hive
      set is-storage-cell? (pycor > hive-top - 5)

      ;; Visualization
      ifelse is-brood-cell? [
        set pcolor brown - 2
      ] [
        ifelse is-storage-cell? [
          update-cell-color
        ] [
          set pcolor brown + 3
        ]
      ]
    ]
  ]
end

to setup-bees
  ;; Create unemployed bees
  create-unemployeds initial-unemployed [
    set shape "bee"
    set color white
    set size 0.7
    set task-state "no-task"
    set theta-foraging random-float 1.0
    set theta-storing random-float 1.0
    set theta-nursing random-float 1.0
    set nectar-load random-float 0.8
    set age random 1000
    set specialization 0
    set last-task "none"
    move-to one-of patches with [
      pxcor >= hive-left and pxcor <= hive-right and
      pycor >= hive-bottom and pycor <= hive-top
    ]
  ]

  ;; Create initial foragers (older bees)
  create-foragers initial-foragers [
    set shape "bee"
    set color blue
    set size 0.8
    set task-state "foraging"
    set activity-state "leave-hive"
    set theta-foraging random-float 0.2  ; Lower threshold for foraging
    set theta-storing random-float 0.8
    set theta-nursing random-float 0.8
    set nectar-load 0.9
    set age 1000 + random 1000  ; Older bees
    set specialization 0.5 + random-float 0.5
    set last-task "foraging"
    move-to one-of patches with [
      pxcor >= hive-left and pxcor <= hive-right and
      pycor >= hive-bottom and pycor <= hive-top
    ]
  ]
end

to setup-larvae
  ;; Create larvae only in brood cells
  create-larvae initial-larvae [
    set shape "circle"
    set color pink
    set size 0.5
    move-to one-of patches with [
      pxcor >= hive-left and pxcor <= hive-right and
      pycor >= hive-bottom and pycor <= hive-top and
      is-brood-cell?
    ]
    set nectar-load random-float 0.33
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; MAIN SIMULATION LOOP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  ;; Stop condition if all bees or all larvae die
  if count turtles with [breed != flowers] = 0 or count larvae = 0 [ stop ]

  ;; Ensure flower exists
  ensure-flower-exists

  ;; Update stimuli and perform activities
  update-stimuli
  ask turtles with [breed != flowers] [
    perform-activity
    set age age + 1
  ]

  ;; Diffuse chemical signals
  diffuse nursing-stimulus pheromone-diffusion

  ;; Update statistics
  set total-bees count turtles with [breed != flowers and breed != larvae]
  set total-larvae count larvae
  update-specialization-counts

  ;; Every 1000 ticks, potentially manipulate colony (experimental perturbations)
  if ticks > 0 and ticks mod 1000 = 0 [
    if perturbation-type = "remove-brood" and random-float 1 < 0.3 [
      ask n-of (count larvae * perturbation-strength / 100) larvae [ die ]
    ]
    if perturbation-type = "add-brood" and random-float 1 < 0.3 [
      create-larvae (count larvae * perturbation-strength / 100) [
        set shape "circle"
        set color pink
        set size 0.5
        move-to one-of patches with [
          pxcor >= hive-left and pxcor <= hive-right and
          pycor >= hive-bottom and pycor <= hive-top and
          is-brood-cell?
        ]
        set nectar-load random-float 0.1  ; New larvae start hungry
      ]
    ]
    if perturbation-type = "remove-workers" and random-float 1 < 0.3 [
      ask n-of (count turtles with [breed != flowers and breed != larvae] * perturbation-strength / 100)
        turtles with [breed != flowers and breed != larvae] [ die ]
    ]
  ]

  tick
end

to ensure-flower-exists
  if flower = nobody or not is-turtle? flower [
    setup-flower
  ]
end

to update-specialization-counts
  set nurse-specialists count turtles with [breed = nurses and theta-nursing <= 0.2]
  set storer-specialists count turtles with [breed = storers and theta-storing <= 0.2]
  set forager-specialists count turtles with [breed = foragers and theta-foraging <= 0.2]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; STIMULI UPDATE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-stimuli
  ask patches [
    ;; Reduce old stimuli values over time
    set foraging-stimulus foraging-stimulus * (1 - pheromone-decay)
    set storing-stimulus storing-stimulus * (1 - pheromone-decay)
    set nursing-stimulus nursing-stimulus * (1 - pheromone-decay)

    ;; Reset colors for patches that are not actively stimulated
    if foraging-stimulus < 0.1 and storing-stimulus < 0.1 and nursing-stimulus < 0.1 [
      ifelse (pxcor >= hive-left and pxcor <= hive-right and
              pycor >= hive-bottom and pycor <= hive-top) [
        ifelse is-brood-cell? [
          set pcolor brown - 2
        ] [
          ifelse is-storage-cell? [
            update-cell-color
          ] [
            set pcolor brown + 3
          ]
        ]
      ] [
        set pcolor black
      ]
    ]
  ]

  ;; Larval hunger signals (based on Schmickl & Crailsheim's equations)
  ask larvae [
    if nectar-load < 0.25 [  ; Hunger threshold
      let hunger-intensity (0.25 - nectar-load) / 0.25  ; Scales from 0 to 1
      ask patch-here [
        set nursing-stimulus nursing-stimulus + hunger-intensity
      ]
    ]
  ]

  ;; Forager dances (waggle or tremble)
  ask foragers [
    if activity-state = "waggle" [
      ask patches in-radius 3 [
        set foraging-stimulus foraging-stimulus + 1 / (distance myself + 1)
        set pcolor blue
      ]
    ]
    if activity-state = "tremble" [
      ask patches in-radius 3 [
        set storing-stimulus storing-stimulus + 1 / (distance myself + 1)
        set pcolor violet
      ]
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; BEE ACTIVITIES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to perform-activity
  ;; First handle mortality
  if random-float 1 < 0.0001 or nectar-load <= 0 [
    if breed != larvae [ set total-bees total-bees - 1 ]
    die
  ]

  ;; Then perform task-specific activities
  ifelse task-state = "no-task" [
    handle-no-task
  ] [
    if task-state = "foraging" [ handle-foraging ]
    if task-state = "storing" [ handle-storing ]
    if task-state = "nursing" [ handle-nursing ]
  ]

  ;; All bees consume nectar and may need to refill
  consume-nectar
  check-refill
  prevent-wrap
end

to handle-foraging
  let hive-entrance-x hive-left
  let hive-entrance-y hive-bottom

  if activity-state = "leave-hive" [
    if not inside-hive? [
      facexy (hive-left + hive-right) / 2 (hive-bottom + hive-top) / 2
      fd 0.2
      stop
    ]

    facexy hive-entrance-x hive-entrance-y
    fd 0.2

    if at-hive-entrance? [
      set activity-state "fly-out"
      set xcor hive-entrance-x - 1
    ]
    stop
  ]

  if activity-state = "fly-out" [
    if at-hive-entrance? [
      set heading 270
      fd 1
      stop
    ]

    if flower != nobody and is-turtle? flower [
      face flower
      fd 0.5
      if distance flower < 1 [
        set nectar-load 1.0
        set activity-state "fly-home"
      ]
    ]
  ]

  if activity-state = "fly-home" [
    if ycor < hive-bottom [ set ycor hive-bottom ]
    facexy hive-entrance-x hive-entrance-y
    fd 0.5

    if at-hive-entrance? [
      set xcor hive-entrance-x + 1
      set activity-state "seek-storer"
      set search-time 0
    ]
  ]

  if activity-state = "seek-storer" [
    set xcor xcor + 0.5

    let nearby-storer one-of storers in-radius 2
    ifelse nearby-storer != nobody [
      set activity-state "unload-nectar"
      ask nearby-storer [ set activity-state "receive-nectar" ]
    ] [
      set search-time search-time + 1
      if search-time > 20 [  ; After long search, signal need for storers
        set activity-state "tremble"
        move-to-dance-floor
      ]
    ]
  ]

  if activity-state = "unload-nectar" [
    set nectar-load 0.1
    set activity-state "waggle"
    move-to-dance-floor
  ]

  if activity-state = "waggle" [
    rt random 30 - 15
    fd 0.1

    if random-float 1 < 0.05 [
      set activity-state "leave-hive"
      ;; Threshold reinforcement for foraging
      set theta-foraging max (list 0 (theta-foraging - 0.1))
      set specialization min (list 1 (specialization + 0.05))
      set last-task "foraging"
    ]
  ]

  if activity-state = "tremble" [
    rt random 40 - 20
    fd 0.05

    if random-float 1 < 0.1 [
      set activity-state "leave-hive"
      ;; Threshold reinforcement for foraging
      set theta-foraging max (list 0 (theta-foraging - 0.05))
      set specialization min (list 1 (specialization + 0.02))
      set last-task "foraging"
    ]
  ]
end

to handle-storing
  if not inside-hive? [
    facexy (hive-left + hive-right) / 2 (hive-bottom + hive-top) / 2
    fd 0.2
    stop
  ]

  if activity-state = "start" [
    set activity-state "wait-for-nectar"
  ]

  if activity-state = "wait-for-nectar" [
    rt random 20 - 10
    fd 0.05

    ;; Also respond to tremble dances
    if [storing-stimulus] of patch-here > theta-storing and random-float 1 < 0.1 [
      set theta-storing max (list 0 (theta-storing - 0.05))
      set specialization min (list 1 (specialization + 0.05))
      set last-task "storing"
    ]
  ]

  if activity-state = "receive-nectar" [
    set nectar-load nectar-load + 0.9
    set activity-state "find-storage"
  ]

  if activity-state = "find-storage" [
    let target-cell min-one-of (patches with [is-storage-cell? and nectar-stored < 1.0]) [distance myself]
    if target-cell != nobody [
      face target-cell
      fd 0.2
      if distance target-cell < 1 [
        set activity-state "store-nectar"
      ]
    ]
  ]

  if activity-state = "store-nectar" [
    let available-space 1.0 - [nectar-stored] of patch-here
    let amount-to-store min (list nectar-load available-space)

    ask patch-here [
      set nectar-stored nectar-stored + amount-to-store
      update-cell-color
    ]

    set nectar-load nectar-load - amount-to-store
    set total-nectar total-nectar + amount-to-store
    set activity-state "wait-for-nectar"

    ;; Threshold reinforcement for storing
    set theta-storing max (list 0 (theta-storing - 0.1))
    set specialization min (list 1 (specialization + 0.1))
    set last-task "storing"
  ]
end

to handle-nursing
  if not inside-hive? [
    facexy (hive-left + hive-right) / 2 (hive-bottom + hive-top) / 2
    fd 0.2
    stop
  ]

  if activity-state = "start" [
    set activity-state "find-hungry-larva"
  ]

  if activity-state = "find-hungry-larva" [
    ;; Follow chemical gradient to hungry larvae
    let max-stimulus max [nursing-stimulus] of patches in-radius 3
    if max-stimulus > 0 [
      let target max-one-of patches in-radius 3 [nursing-stimulus]
      face target
      fd 0.2

      if distance target < 1 and [nursing-stimulus] of patch-here > theta-nursing [
        set activity-state "feed-larva"
      ]
    ]
  ]

  if activity-state = "feed-larva" [
    let hungry-larva one-of larvae-here with [nectar-load < 0.25]
    if hungry-larva != nobody and nectar-load > 0.1 [
      let feed-amount 0.05
      set nectar-load nectar-load - feed-amount
      ask hungry-larva [
        set nectar-load nectar-load + feed-amount
        ;; Reduce hunger signal after feeding
        ask patch-here [ set nursing-stimulus nursing-stimulus * 0.5 ]
      ]

      ;; Threshold reinforcement for nursing
      set theta-nursing max (list 0 (theta-nursing - 0.15))
      set specialization min (list 1 (specialization + 0.15))
      set last-task "nursing"
    ]
    set activity-state "find-hungry-larva"
  ]
end

to handle-no-task
  if not inside-hive? [
    facexy (hive-left + hive-right) / 2 (hive-bottom + hive-top) / 2
    fd 0.2
    stop
  ]

  ;; Random movement
  rt random 20 - 10
  fd 0.1

  ;; Age-based task predisposition (older bees more likely to forage)
  let age-bias ifelse-value (age > 1000) [ 0.2 ] [ -0.1 ]

  ;; Calculate task probabilities with threshold model
  let p-foraging (task-probability "foraging") + age-bias
  let p-storing (task-probability "storing")
  let p-nursing (task-probability "nursing")

  ;; Normalize probabilities
  let total-p p-foraging + p-storing + p-nursing
  if total-p > 0 [
    set p-foraging p-foraging / total-p
    set p-storing p-storing / total-p
    set p-nursing p-nursing / total-p

    ;; Select task based on probabilities
    let r random-float 1
    if r < p-foraging [ switch-to-task "foraging" ]
    if r < p-foraging + p-storing [ switch-to-task "storing" ]
    if r < p-foraging + p-storing + p-nursing [ switch-to-task "nursing" ]
  ]

  ;; If no task selected, increase thresholds slightly (forgetting)
  if task-state = "no-task" [
    if last-task != "foraging" [ set theta-foraging min (list 1 (theta-foraging + 0.001)) ]
    if last-task != "storing" [ set theta-storing min (list 1 (theta-storing + 0.001)) ]
    if last-task != "nursing" [ set theta-nursing min (list 1 (theta-nursing + 0.001)) ]
    set specialization max (list 0 (specialization - 0.001))
  ]
end

to-report task-probability [task-type]
  let s 0
  let threshold 0

  if task-type = "foraging" [
    set s [foraging-stimulus] of patch-here
    set threshold theta-foraging
  ]
  if task-type = "storing" [
    set s [storing-stimulus] of patch-here
    set threshold theta-storing
  ]
  if task-type = "nursing" [
    set s [nursing-stimulus] of patch-here
    set threshold theta-nursing
  ]

  ;; Response threshold function (from Schmickl & Crailsheim)
  ifelse s > 0 [
    report (s ^ 2) / (s ^ 2 + (threshold ^ 2))
  ][
    report 0
  ]
end

to switch-to-task [new-task]
  if new-task = "foraging" [
    set breed foragers
    set color blue
    set theta-foraging max (list 0 (theta-foraging - 0.05))
  ]
  if new-task = "storing" [
    set breed storers
    set color green
    set theta-storing max (list 0 (theta-storing - 0.05))
  ]
  if new-task = "nursing" [
    set breed nurses
    set color yellow
    set theta-nursing max (list 0 (theta-nursing - 0.05))
  ]

  set task-state new-task
  set activity-state "start"
  set size 1.5
  set last-task new-task
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; UTILITY PROCEDURES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to move-to-dance-floor
  let dance-x hive-left + random (hive-right - hive-left - 2) + 1
  let dance-y hive-bottom + random 3 + 1
  setxy dance-x dance-y

  if not inside-hive? [
    move-to one-of patches with [
      pxcor > hive-left and pxcor < hive-right and
      pycor > hive-bottom and pycor < hive-bottom + 4
    ]
  ]
end

to update-cell-color
  if is-storage-cell? [
    let base-color yellow - 2
    let red-component 2.5 * nectar-stored

    ifelse nectar-stored > 0 [
      set pcolor base-color + red-component
      if nectar-stored > 0.7 [ set pcolor pcolor + 0.5 ]
    ][
      set pcolor yellow - 2
    ]
  ]
end

to check-refill
  if nectar-load < 0.2 and (task-state != "foraging" or
      (task-state = "foraging" and (activity-state = "waggle" or activity-state = "tremble"))) [

    if not inside-hive? [
      facexy (hive-left + hive-right) / 2 (hive-bottom + hive-top) / 2
      fd 0.3
      stop
    ]

    let nectar-cells patches with [is-storage-cell? and nectar-stored > 0.1]
    ifelse any? nectar-cells [
      let nectar-cell max-one-of nectar-cells [nectar-stored]
      ifelse distance nectar-cell > 1 [
        face nectar-cell
        fd 0.3
      ][
        let amount-to-take min (list 0.5 [nectar-stored] of nectar-cell)
        set nectar-load nectar-load + amount-to-take
        ask patch-here [
          set nectar-stored nectar-stored - amount-to-take
          update-cell-color
        ]
        set size size + 0.2
        set size size - 0.2
      ]
    ][
      let nearby-bee one-of other turtles in-radius 2 with [nectar-load > 0.4 and breed != larvae]
      if nearby-bee != nobody [
        let amount-to-share 0.2
        ask nearby-bee [ set nectar-load nectar-load - amount-to-share ]
        set nectar-load nectar-load + amount-to-share
      ]
    ]
  ]
end

to consume-nectar
  ifelse activity-state = "fly-out" or activity-state = "fly-home" [
    set nectar-load nectar-load - 0.001
  ][
    set nectar-load nectar-load - 0.0002
  ]

  if nectar-load < 0.1 [ set color color - 1 ]

  if nectar-load <= 0 [
    ifelse inside-hive? [
      set nectar-load 0.01
    ][
      die
    ]
  ]
end

to prevent-wrap
  if xcor < min-pxcor [ set xcor min-pxcor ]
  if xcor > max-pxcor [ set xcor max-pxcor ]
  if ycor < min-pycor [ set ycor min-pycor ]
  if ycor > max-pycor [ set ycor max-pycor ]
end

to-report inside-hive?
  report (xcor > hive-left and xcor < hive-right and
          ycor > hive-bottom and ycor < hive-top)
end

to-report at-hive-entrance?
  report (distancexy hive-left hive-bottom < 1)
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; EXPERIMENTAL PERTURBATIONS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to remove-brood
  ask n-of (count larvae * perturbation-strength / 100) larvae [ die ]
end

to add-brood
  create-larvae (count larvae * perturbation-strength / 100) [
    set shape "circle"
    set color pink
    set size 0.5
    move-to one-of patches with [
      pxcor >= hive-left and pxcor <= hive-right and
      pycor >= hive-bottom and pycor <= hive-top and
      is-brood-cell?
    ]
    set nectar-load random-float 0.1
  ]
end

to remove-workers
  ask n-of (count turtles with [breed != flowers and breed != larvae] * perturbation-strength / 100)
    turtles with [breed != flowers and breed != larvae] [ die ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
63
92
129
125
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
67
194
130
227
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

SLIDER
48
490
220
523
initial-unemployed
initial-unemployed
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
57
553
229
586
initial-foragers
initial-foragers
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
59
643
231
676
initial-larvae
initial-larvae
0
100
50.0
1
1
NIL
HORIZONTAL

CHOOSER
388
615
528
660
perturbation-type
perturbation-type
"remove-brood" "add-brood"
0

SLIDER
76
715
268
748
perturbation-strength
perturbation-strength
0
100
50.0
1
1
NIL
HORIZONTAL

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
