; Bee Division of Labor Simulation
; Based on BeeSmart Hive Finding model and incorporating division of labor mechanics

breed [bees bee]
breed [scouts scout]
breed [hives hive]
breed [food-sources food-source]

bees-own [
  age               ; age in days
  caste             ; 0=young nurse, 1=middle-aged processor, 2=forager, 3=scout
  task              ; specific current task
  my-hive           ; the bee's home hive
  target            ; target location (food source or dance location)
  nectar-carried    ; amount of nectar being carried
  pollen-carried    ; amount of pollen being carried
  danced-for        ; the site a bee is dancing for
  dance-time        ; how long to dance
  watching-dance?   ; whether bee is watching a dance
  scouting?         ; whether bee is actively scouting
  commitment        ; commitment to a site (0-1)
  time-on-task      ; time spent on current task
  energy            ; energy level
  know-good-site?   ; whether the bee knows of a good site or not
]

hives-own [
  quality           ; quality of the hive (1-100)
  population        ; number of bees in the hive
  nectar-stored     ; amount of nectar stored
  pollen-stored     ; amount of pollen stored
  brood-count       ; number of developing larvae
  inactive-dancers  ; list of scouts not currently dancing but know of a good site
]

food-sources-own [
  quality           ; quality of food source (1-100)
  nectar-amount     ; amount of nectar available
  pollen-amount     ; amount of pollen available
  visitors          ; count of bees currently visiting
]

patches-own [
  nest?             ; is this patch part of a nest?
  nest-scent        ; strength of nest scent
  food-scent        ; strength of food scent
]

globals [
  forager-count     ; count of forager bees
  nurse-count       ; count of nurse bees
  processor-count   ; count of processor bees
  scout-count       ; count of scout bees
  total-nectar      ; total nectar collected
  total-pollen      ; total pollen collected
  day-count         ; simulation day counter
  current-season    ; 0=spring, 1=summer, 2=fall, 3=winter
  max-age           ; maximum age for bees (varies by season)
  colony-health     ; overall health of the colony (0-100)
]

;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup Procedures    ;;
;;;;;;;;;;;;;;;;;;;;;;;;;

to setup
  clear-all

  ; Initialize global variables
  set day-count 0
  set current-season 0
  set max-age 40  ; default max age
  set colony-health 100  ; start with healthy colony

  ; Create the main hive
  create-hives 1 [
    set shape "square"
    set color yellow
    set size 5
    setxy 0 0
    set quality 80 + random 20  ; high quality main hive
    set population initial-population
    set nectar-stored 50
    set pollen-stored 50
    set brood-count 20
    set inactive-dancers []
    ; Create nest area around hive
    ask patches in-radius 8 [
      set nest? true
      set pcolor yellow - 1
      set nest-scent 100
    ]
  ]

  ; Create food sources
  create-food-sources num-food-sources [
    set shape "box"
    set color pink - 1 + random 3
    set size 3
    ; Position food sources away from hive
    move-to one-of patches with [distance one-of hives > 20 and distance one-of hives < 40]
    set quality 20 + random 80
    set nectar-amount 50 + random 50
    set pollen-amount 50 + random 50
    set visitors 0
    ; Set scent in surrounding area
    ask patches in-radius 5 [
      set food-scent 50
      set pcolor green - 1
    ]
  ]

  ; Create initial bee population with age distribution
  create-bees initial-population [
    set shape "bee"
    set color gray
    set size 1.2
    move-to one-of hives
    set my-hive one-of hives
    set nectar-carried 0
    set pollen-carried 0
    set dance-time 0
    set watching-dance? false
    set scouting? false
    set commitment 0
    set energy 100
    set know-good-site? false

    ; Age distribution and caste assignment
    set age random max-age
    assign-caste

    ; Initial task assignment based on caste
    assign-task
  ]

  update-globals
  reset-ticks
end

to assign-caste
  ; Assign caste based on age
  ifelse age < 10 [
    set caste 0  ; young nurse
    set color blue
  ][
    ifelse age < 20 [
      set caste 1  ; middle-aged processor
      set color green
    ][
      ifelse random-float 1 < scout-chance [
        set caste 3  ; scout
        set color orange
      ][
        set caste 2  ; forager
        set color red
      ]
    ]
  ]
end

to assign-task
  ; Assign specific task based on caste
  if caste = 0 [  ; nurse
    ifelse random-float 1 < 0.7
      [ set task "feeding brood" ]
      [ set task "cleaning" ]
  ]

  if caste = 1 [  ; processor
    ifelse random-float 1 < 0.6
      [ set task "nectar processing" ]
      [ set task "pollen packing" ]
  ]

  if caste = 2 [  ; forager
    ifelse random-float 1 < 0.5
      [ set task "nectar foraging" ]
      [ set task "pollen foraging" ]
  ]

  if caste = 3 [  ; scout
    set task "scouting"
    set scouting? true
  ]

  set time-on-task 0
end

;;;;;;;;;;;;;;;;;;;;;;;;;
;; Runtime Procedures  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  if not any? bees [ stop ]  ; Stop if colony died

  ; Advance day count and check for seasonal changes
  if ticks mod day-length = 0 [
    set day-count day-count + 1
    check-seasonal-changes
    update-colony-health
  ]

  ; Update all agents
  ask bees [
    if random-float 1 < 0.8 [ perform-task ]  ; 80% chance to perform task each tick
    consume-energy
    age-and-die
    maybe-change-task
  ]

  ; Update environmental features
  diffuse nest-scent 0.1
  diffuse food-scent 0.1
  ask patches [
    set nest-scent nest-scent * 0.99  ; scent evaporation
    set food-scent food-scent * 0.99
  ]

  ; Update food sources
  ask food-sources [
    if ticks mod day-length = 0 [ regenerate-resources ]
  ]

  ; Update hives
  ask hives [
    hive-dynamics
  ]

  ; Potentially spawn new bees
  spawn-new-bees

  update-globals
  tick
end

to check-seasonal-changes
  ; Change seasons every 90 days
  if day-count mod 90 = 0 [
    set current-season (current-season + 1) mod 4

    ; Adjust max age based on season
    if current-season = 0 [ set max-age 40 ]  ; spring
    if current-season = 1 [ set max-age 35 ]  ; summer
    if current-season = 2 [ set max-age 50 ]  ; fall - preparing for winter
    if current-season = 3 [ set max-age 100 ]  ; winter - winter bees live longer

    ; Seasonal effects on food sources
    ask food-sources [
      if current-season = 0 [ set quality quality * 1.2 ]  ; spring bloom
      if current-season = 2 [ set quality quality * 0.8 ]  ; fall decline
      if current-season = 3 [ set quality quality * 0.5 ]  ; winter scarcity
    ]
  ]
end

to consume-energy
  ; Consume energy based on task
  if caste = 0 [ set energy energy - 0.2 ]  ; nurses consume less energy
  if caste = 1 [ set energy energy - 0.3 ]  ; processors
  if caste = 2 [ set energy energy - 0.5 ]  ; foragers consume more energy
  if caste = 3 [ set energy energy - 0.6 ]  ; scouts consume most energy

  ; Refill energy when at hive
  if distance my-hive < 3 and energy < 70 [
    let refill-amount min list (100 - energy) ([nectar-stored] of my-hive * 0.01)
    set energy energy + refill-amount
    ask my-hive [ set nectar-stored nectar-stored - refill-amount * 0.1 ]
  ]

  ; Die if energy depleted
  if energy <= 0 [ die ]
end

to age-and-die
  ; Age and potentially die
  if ticks mod day-length = 0 [
    set age age + 1

    ; Age-based mortality
    if age > max-age or random-float 1 < (age / max-age) ^ 2 [
      die
    ]

    ; Consider caste transition based on age and colony needs
    consider-caste-transition
  ]
end

to consider-caste-transition
  ; Normal age-based progression
  if caste = 0 and age >= 10 [
    set caste 1  ; nurse to processor
    set color green
    assign-task
  ]

  if caste = 1 and age >= 20 [
    ifelse random-float 1 < scout-chance [
      set caste 3  ; processor to scout
      set color orange
    ][
      set caste 2  ; processor to forager
      set color red
    ]
    assign-task
  ]

  ; Colony needs can accelerate or delay transitions
  let nurse-ratio nurse-count / count bees
  let forager-ratio forager-count / count bees

  ; Emergency response - colony needs more nurses
  if caste = 1 and [brood-count] of my-hive > 30 and nurse-ratio < 0.3 [
    if random-float 1 < 0.3 [
      set caste 0  ; revert to nursing if needed
      set color blue
      assign-task
    ]
  ]

  ; Emergency response - colony needs more foragers
  if current-season = 1 and caste = 1 and forager-ratio < 0.3 [
    if random-float 1 < 0.4 [
      set caste 2  ; accelerate to foraging if needed
      set color red
      assign-task
    ]
  ]
end

to maybe-change-task
  ; Potentially change task within same caste
  set time-on-task time-on-task + 1

  ; More experienced bees tend to stick with tasks longer
  let change-threshold 100 - (age * 2)
  if change-threshold < 20 [ set change-threshold 20 ]

  if time-on-task > change-threshold and random-float 1 < task-switch-chance [
    ; Reset task timer
    set time-on-task 0

    ; Switch tasks within caste
    if caste = 0 [  ; nurse
      ifelse task = "feeding brood"
        [ set task "cleaning" ]
        [ set task "feeding brood" ]
    ]

    if caste = 1 [  ; processor
      ifelse task = "nectar processing"
        [ set task "pollen packing" ]
        [ set task "nectar processing" ]
    ]

    if caste = 2 [  ; forager
      ifelse task = "nectar foraging"
        [ set task "pollen foraging" ]
        [ set task "nectar foraging" ]
    ]
  ]
end

to perform-task
  ; Perform the bee's current task

  ; NURSE TASKS
  if caste = 0 [
    ifelse task = "feeding brood" [
      ; Stay near hive and feed brood
      if distance my-hive > 5 [
        face my-hive
        fd 1
      ]
        ; Random movement in hive
        rt random 40 - 20
        fd 0.2

        ; Feed brood if there's pollen
        if [pollen-stored] of my-hive > 0 [
          ask my-hive [
            set pollen-stored pollen-stored - 0.01
            if brood-count < max-brood and pollen-stored > 10 [
              set brood-count brood-count + 0.01
            ]
          ]
        ]
    ] [
      ; Cleaning task
      if distance my-hive > 8 [
        face my-hive
        fd 1
      ]
        ; Random movement cleaning hive
        rt random 60 - 30
        fd 0.3
    ]
  ]

  ; PROCESSOR TASKS
  if caste = 1 [
    ifelse task = "nectar processing" [
      ; Stay in hive area to process nectar
      if distance my-hive > 6 [
        face my-hive
        fd 1
      ]
        ; Find foragers with nectar
        let foragers-with-nectar bees with [caste = 2 and nectar-carried > 0 and distance myself < 3]
        ifelse any? foragers-with-nectar [
          ; Take nectar from foragers and process it
          let chosen-forager-with-nectar one-of foragers-with-nectar
          face target
          fd 0.3
          if distance chosen-forager-with-nectar < 1 [
            let amount [nectar-carried] of chosen-forager-with-nectar * 0.5
            ask chosen-forager-with-nectar [
              set nectar-carried nectar-carried - amount
            ]
            ask my-hive [
              set nectar-stored nectar-stored + amount
            ]
          ]
        ] [
          ; Random movement inside hive
          rt random 40 - 20
          fd 0.3
        ]
    ] [
      ; Pollen packing task
      if distance my-hive > 6 [
        face my-hive
        fd 1
      ]
        ; Find foragers with pollen
        let foragers-with-pollen bees with [caste = 2 and pollen-carried > 0 and distance myself < 3]
        ifelse any? foragers-with-pollen [
          ; Take pollen from foragers and store it
          let chosen-forager one-of foragers-with-pollen
          face chosen-forager
          fd 0.3
          if distance chosen-forager < 1 [
            let amount [pollen-carried] of chosen-forager * 0.5
            ask chosen-forager [
              set pollen-carried pollen-carried - amount
            ]
            ask my-hive [
              set pollen-stored pollen-stored + amount
            ]
          ]
        ] [
          ; Random movement inside hive
          rt random 40 - 20
          fd 0.3
        ]
    ]
  ]

  ; FORAGER TASKS
  if caste = 2 [
    ifelse task = "nectar foraging" [
      perform-foraging "nectar"
    ] [
      perform-foraging "pollen"
    ]
  ]

  ; SCOUT TASKS
  if caste = 3 [
    if scouting? [
      ifelse dance-time > 0 [
        ; Dancing to recruit
        perform-dance
      ][
        ; Scouting for food sources
        perform-scouting
      ]
    ]
      ; Watching dances or deciding
      if not watching-dance? [
        watch-dance
      ]
        ; Already watching - potentially get convinced
        consider-food-source
  ]
end

to perform-foraging [resource-type]
  ; If carrying full load, return to hive
  if (resource-type = "nectar" and nectar-carried > 0.8) or
     (resource-type = "pollen" and pollen-carried > 0.8) [
    ifelse distance my-hive < 2 [
      ; Unload resources
      ifelse resource-type = "nectar" [
        let amount nectar-carried
        set nectar-carried 0
        ask my-hive [
          set nectar-stored nectar-stored + amount
        ]
      ][
        let amount pollen-carried
        set pollen-carried 0
        ask my-hive [
          set pollen-stored pollen-stored + amount
        ]
      ]
      ; Reset and prepare for next trip
      set target nobody
    ][
      ; Head toward hive
      face my-hive
      fd 1
    ]
    stop
  ]

  ; If no target, find one or follow a dance
  if target = nobody [
    ; First check if we can follow a dance
    ifelse random-float 1 < dance-follow-chance and any? bees with [caste = 3 and dance-time > 0] [
      let dancer one-of bees with [caste = 3 and dance-time > 0]
      set target [danced-for] of dancer
    ][
      ; Otherwise find a food source directly or follow scent
      ifelse any? food-sources in-radius 5 [
        set target one-of food-sources in-radius 5
      ][
        ; Follow food scent gradient
        let scent-ahead food-scent-at-angle 0
        let scent-right food-scent-at-angle 45
        let scent-left food-scent-at-angle -45

        ifelse (scent-right > scent-ahead) or (scent-left > scent-ahead) [
          ifelse scent-right > scent-left [
            rt 45
          ][
            lt 45
          ]
        ][
          ; If no scent, move randomly
          if scent-ahead < 0.1 [
            rt random 60 - 30
          ]
        ]
        fd 1
      ]
    ]
  ]

  ; If we have a target food source, move toward it
  ifelse target != nobody and is-food-source? target [
    ifelse distance target < 1 [
      ; Collect resources
      ifelse resource-type = "nectar" [
        let amount min list (1 - nectar-carried) ([nectar-amount] of target * 0.01)
        set nectar-carried nectar-carried + amount
        ask target [
          set nectar-amount nectar-amount - amount * 10
          set visitors visitors + 1
        ]
      ][
        let amount min list (1 - pollen-carried) ([pollen-amount] of target * 0.01)
        set pollen-carried pollen-carried + amount
        ask target [
          set pollen-amount pollen-amount - amount * 10
          set visitors visitors + 1
        ]
      ]

      ; Evaluate quality and potentially dance when returning
      if ([quality] of target > 60 or random-float 1 < ([quality] of target / 100)) [
        set dance-time 20 + random ([quality] of target / 2)
        set danced-for target
      ]
    ][
      ; Move toward target
      face target
      fd 1
    ]
  ][
    ; No valid target, move randomly
    rt random 60 - 30
    fd 1
  ]
end

to perform-scouting
  ; Scouts look for food sources
  ifelse any? food-sources in-radius 2 [
    ; Found a food source
    let found-source one-of food-sources in-radius 2

    ; Evaluate it
    if [quality] of found-source > 50 or random-float 1 < ([quality] of found-source / 100) [
      ; Good source - dance for it
      set dance-time 20 + random ([quality] of found-source / 2)
      set danced-for found-source
      set scouting? false
    ]
  ][
    ; Keep exploring
    ifelse random-float 1 < 0.1 [
      ; Occasionally return to hive
      if distance my-hive > 10 [
        face my-hive
        fd 1.5
      ]
    ][
      ; Random exploratory movement
      rt random 60 - 30
      fd 1.2
    ]
  ]
end

to perform-dance
  ; Perform waggle dance to communicate food source
  if distance my-hive > 5 [
    ; Return to hive to dance
    face my-hive
    fd 1.5
  ]
    ; Do dance movements
    rt random 180
    lt random 180

    ; Decrement dance time
    set dance-time dance-time - 1

    ; Record as inactive dancer if we're done but still know the site
    if dance-time <= 0 [
      set scouting? true
      ask my-hive [
        if not member? myself inactive-dancers [
          set inactive-dancers lput myself inactive-dancers
        ]
      ]
    ]
end

to watch-dance
  ; Scout watches dances to learn about food sources
  let dancers bees with [dance-time > 0 and distance myself < 3]

  ifelse any? dancers [
    ; Watch a dance
    let dancer one-of dancers
    face dancer
    set watching-dance? true
    set target [danced-for] of dancer
    set commitment ([quality] of [danced-for] of dancer) / 100
  ][
    ; No dancers nearby, move randomly in hive
    if distance my-hive > 5 [
      face my-hive
      fd 1
    ]
      rt random 60 - 30
      fd 0.5
    set watching-dance? false
  ]
end

to consider-food-source
  ; After watching dance, consider the food source
  if target != nobody and is-food-source? target [
    if random-float 1 < commitment [
      ; Convinced by dance, switch to foraging
      set caste 2
      set color red
      set task "nectar foraging"
      set watching-dance? false
      set scouting? false
    ]
      ; Not convinced, keep watching or find another dance
      set watching-dance? false
  ]
end

to update-colony-health
  ; Update overall colony health based on resources and population
  let resource-factor (([nectar-stored] of one-of hives + [pollen-stored] of one-of hives) / 200)
  let population-factor (count bees / initial-population)
  let brood-factor ([brood-count] of one-of hives / max-brood)

  ; Calculate weighted health
  set colony-health (resource-factor * 40) + (population-factor * 40) + (brood-factor * 20)

  ; Cap at 100
  if colony-health > 100 [ set colony-health 100 ]

  ; Additional seasonal effects
  if current-season = 3 [ ; winter
    if colony-health < 50 [
      ; Winter is harder on weak colonies
      set colony-health colony-health * 0.95
    ]
  ]
end

to regenerate-resources
  ; Regenerate flower resources based on season
  let regen-factor 1.0

  if current-season = 0 [ set regen-factor 1.5 ]  ; spring
  if current-season = 1 [ set regen-factor 1.2 ]  ; summer
  if current-season = 2 [ set regen-factor 0.8 ]  ; fall
  if current-season = 3 [ set regen-factor 0.3 ]  ; winter

  set nectar-amount nectar-amount + (1.0 * regen-factor)
  set pollen-amount pollen-amount + (0.5 * regen-factor)

  ; Cap resources
  if nectar-amount > 100 [ set nectar-amount 100 ]
  if pollen-amount > 100 [ set pollen-amount 100 ]

  ; Adjust quality based on visitors (popular sources get better)
  if visitors > 0 [
    set quality min list 100 (quality + (visitors * 0.1))
    set visitors 0
  ]
end

to hive-dynamics
  ; Process brood development
  if brood-count > 0 [
    ; Some brood develops into adult bees
    let new-bees min list 2 (brood-count * 0.01)
    set brood-count brood-count - new-bees

    ; Create the new bees
    hatch-bees new-bees [
      set shape "bee"
      set size 1.2
      set age 0
      set caste 0  ; start as nurse
      set color blue
      set my-hive myself
      set nectar-carried 0
      set pollen-carried 0
      set dance-time 0
      set watching-dance? false
      set scouting? false
      set commitment 0
      set energy 100
      set know-good-site? false
      assign-task
    ]
  ]

  ; Resource consumption
  let bee-count count bees with [my-hive = myself]
  let daily-consumption (bee-count * 0.1) + (brood-count * 0.05)

  ; Consume resources
  set nectar-stored max list 0 (nectar-stored - (daily-consumption * 0.7))
  set pollen-stored max list 0 (pollen-stored - (daily-consumption * 0.3))

  ; Update population count
  set population count bees with [my-hive = myself]
end

to spawn-new-bees
  ; Queen lays eggs based on resources and season
  let main-hive one-of hives

  ; Only spawn if there are enough resources
  if [nectar-stored] of main-hive > 20 and [pollen-stored] of main-hive > 10 [
    let spawn-rate 0.1

    ; Seasonal adjustments
    if current-season = 0 [ set spawn-rate 0.2 ]  ; spring - higher reproduction
    if current-season = 3 [ set spawn-rate 0.01 ] ; winter - minimal reproduction

    ; Resource-based adjustments
    if [nectar-stored] of main-hive < 30 [ set spawn-rate spawn-rate * 0.5 ]
    if [pollen-stored] of main-hive < 20 [ set spawn-rate spawn-rate * 0.5 ]

    ; Spawn new brood
    if random-float 1 < spawn-rate and [brood-count] of main-hive < max-brood [
      ask main-hive [
        set brood-count brood-count + 1
        ; Use resources for egg production
        set nectar-stored nectar-stored - 0.2
        set pollen-stored pollen-stored - 0.3
      ]
    ]
  ]
end

to-report food-scent-at-angle [angle]
  ; Report the scent in the direction of the given angle
  let p patch-right-and-ahead angle 1
  ifelse p != nobody
    [ report [food-scent] of p ]
    [ report 0 ]
end

to update-globals
  ; Update global counters
  set nurse-count count bees with [caste = 0]
  set processor-count count bees with [caste = 1]
  set forager-count count bees with [caste = 2]
  set scout-count count bees with [caste = 3]

  ; Update resource totals
  if any? hives [
    set total-nectar sum [nectar-stored] of hives
    set total-pollen sum [pollen-stored] of hives
  ]
end

; Reporter to get total number of bees
to-report total-bees
  report count bees
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
26
549
92
582
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
123
549
186
582
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
18
66
199
99
initial-population
initial-population
50
300
90.0
1
1
NIL
HORIZONTAL

SLIDER
23
151
209
184
num-food-sources
num-food-sources
5
30
10.0
1
1
NIL
HORIZONTAL

SLIDER
23
224
243
257
scout-chance
scout-chance
0.01
0.2
0.14
0.01
1
NIL
HORIZONTAL

SLIDER
26
279
268
312
task-switch-chance
task-switch-chance
0.01
0.2
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
24
340
209
373
dance-follow-chance
dance-follow-chance
0.1
0.9
0.9
0.1
1
NIL
HORIZONTAL

SLIDER
28
391
200
424
max-brood
max-brood
50
200
200.0
1
1
NIL
HORIZONTAL

SLIDER
21
465
193
498
day-length
day-length
10
50
41.0
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
