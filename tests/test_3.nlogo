globals [
  ; Simulation parameters
  max-patches-x
  max-patches-y

  ; Hive layout boundaries (now relative)
  hive-width
  hive-height
  hive-left
  hive-right
  hive-top
  hive-bottom
  entrance-x
  entrance-y
  storage-top
  storage-bottom
  broodnest-center-x
  broodnest-center-y
  broodnest-radius

  ; Nectar source location (relative to hive)
  flower-x
  flower-y

  ; Counters for analysis
  total-foragers
  total-storers
  total-nurses
  total-unemployed
]

breed [bees bee]
breed [larvae larva]

patches-own [
  ; Patch types: "outside", "entrance", "storage", "broodnest", "hive-other"
  patch-type

  ; Chemical concentrations
  hunger-pheromone

  ; Visual cues
  light-level

  ; Stimuli
  waggle-dance-signal
  tremble-dance-signal
  contact-signal

  ; Original patch color (for restoring after dance)
  original-color
]

bees-own [
  ; Current task: "unemployed", "foraging", "storing", "nursing"
  current-task

  ; Individual thresholds for task switching
  theta-foraging
  theta-storing
  theta-nursing

  ; Physiological state
  crop-load
  energy

  ; Behavioral state
  target-x
  target-y
  search-time
  feeding-time

  ; Foraging state management
  foraging-state  ; "going-to-flower", "at-flower", "returning", "at-entrance", "dancing"
  dance-duration
  unloading-time

  ; Dance type tracking
  dance-type  ; "waggle" or "tremble"
]

larvae-own [
  nectar-reserve
  hunger-level
  is-hungry?
]

to setup
  clear-all

  ; Set world dimensions
  set max-patches-x world-width
  set max-patches-y world-height

  ; Define hive dimensions as percentages of world size
  set hive-width round (max-patches-x * 0.4)  ; 40% of world width
  set hive-height round (max-patches-y * 0.6) ; 60% of world height

  ; Position hive in the right portion of the world
  set hive-right max-pxcor
  set hive-left hive-right - hive-width
  set hive-bottom min-pycor + round (max-patches-y * 0.2) ; 20% from bottom
  set hive-top hive-bottom + hive-height

  ; Define entrance location (bottom-left of hive, relative)
  set entrance-x hive-left + round (hive-width * 0.1)  ; 10% from left edge of hive
  set entrance-y hive-bottom + round (hive-height * 0.1) ; 10% from bottom of hive

  ; Define storage area (top portion of hive, relative)
  set storage-top hive-top - round (hive-height * 0.3)  ; Top 30% of hive
  set storage-bottom hive-top

  ; Define broodnest center (center of hive, relative)
  set broodnest-center-x hive-left + round (hive-width * 0.5)   ; Center horizontally
  set broodnest-center-y hive-bottom + round (hive-height * 0.4) ; 40% up from bottom
  set broodnest-radius round (min list hive-width hive-height * 0.25) ; 25% of smaller dimension

  ; Define flower location (relative to hive entrance)
  set flower-x entrance-x - round (hive-width * 0.8)  ; 80% of hive width away from entrance
  set flower-y entrance-y + round (hive-height * 0.1) ; Slightly above entrance level

  ; Ensure flower is within world bounds
  if flower-x < min-pxcor [ set flower-x min-pxcor ]
  if flower-x > max-pxcor [ set flower-x max-pxcor ]
  if flower-y < min-pycor [ set flower-y min-pycor ]
  if flower-y > max-pycor [ set flower-y max-pycor ]

  setup-patches
  setup-larvae
  setup-bees

  reset-ticks
end

to setup-patches
  ask patches [
    ; Initialize all patches
    set patch-type "outside"
    set hunger-pheromone 0
    set light-level 0
    set waggle-dance-signal 0
    set tremble-dance-signal 0
    set contact-signal 0

    ; Color outside patches
    set pcolor black
    set original-color black

    ; Set up hive structure
    if (pxcor >= hive-left and pxcor <= hive-right and
        pycor >= hive-bottom and pycor <= hive-top) [

      ; Default hive color
      set patch-type "hive-other"
      set pcolor gray
      set original-color gray

      ; Storage area (top of hive)
      if (pycor >= storage-top and pycor <= storage-bottom) [
        set patch-type "storage"
        set pcolor orange
        set original-color orange
      ]

      ; Broodnest area (center of hive)
      let dist-to-broodnest distance (patch broodnest-center-x broodnest-center-y)
      if (dist-to-broodnest <= broodnest-radius) [
        set patch-type "broodnest"
        set pcolor brown
        set original-color brown
      ]

      ; Entrance area (overrides other areas if they overlap)
      let dist-to-entrance distance (patch entrance-x entrance-y)
      if (dist-to-entrance <= 2) [  ; Entrance is a small area around the entrance point
        set patch-type "entrance"
        set pcolor yellow
        set original-color yellow
        set light-level 1.0
      ]
    ]

    ; Set up light gradient from entrance (only for hive patches)
    if (patch-type != "outside") [
      let dist-to-entrance distance (patch entrance-x entrance-y)
      let max-hive-distance sqrt ((hive-width ^ 2) + (hive-height ^ 2))
      set light-level (1.0 - (dist-to-entrance / max-hive-distance))
      if light-level < 0 [ set light-level 0 ]
    ]
  ]

  ; Mark flower location
  ask patch flower-x flower-y [
    set pcolor pink
    set original-color pink
  ]
end

to setup-larvae
  ; Create larvae proportional to broodnest area
  let broodnest-area (pi * broodnest-radius ^ 2)
  let larvae-density 0.8  ; larvae per patch
  let larvae-count round (broodnest-area * larvae-density)
  let placed 0

  while [placed < larvae-count] [
    ; Generate random position within broodnest circle
    let angle random 360
    let radius random-float broodnest-radius
    let x broodnest-center-x + (radius * cos angle)
    let y broodnest-center-y + (radius * sin angle)

    ; Round to nearest patch coordinates
    set x round x
    set y round y

    ; Ensure larvae are within world bounds and broodnest
    if (x >= min-pxcor and x <= max-pxcor and
        y >= min-pycor and y <= max-pycor) [

      ask patch x y [
        if patch-type = "broodnest" and not any? larvae-here [
          sprout-larvae 1 [
            set shape "circle"
            set color white
            set size 0.8
            set nectar-reserve random-float 0.33
            set hunger-level 0
            set is-hungry? false
            update-larva-hunger
          ]
          set placed placed + 1
        ]
      ]
    ]
  ]
end

to setup-bees
  ; Create bees proportional to hive size
  let hive-area (hive-width * hive-height)
  let bee-density 0.5  ; bees per patch
  let bee-count round (hive-area * bee-density)

  create-bees bee-count [
    ; Random position in hive
    setxy (hive-left + random hive-width)
          (hive-bottom + random hive-height)

    set shape "bee"
    set size 1.0
    set color black

    ; Initialize task and thresholds
    set current-task "unemployed"
    set theta-foraging 0.001
    set theta-storing 0.001
    set theta-nursing 0.001

    ; Initialize physiological state
    set crop-load random-float 1.0
    set energy 1.0

    ; Initialize behavioral state
    set target-x 0
    set target-y 0
    set search-time 0
    set feeding-time 0
    set foraging-state "going-to-flower"
    set dance-duration 0
    set unloading-time 0
    set dance-type ""
  ]

  ; Assign 100 bees as initial foragers
  let initial-foragers min list 100 count bees
  ask n-of initial-foragers bees [
    set current-task "foraging"
    set color red
    set crop-load random-float 0.5  ; Start with low crop load so they go foraging
    set foraging-state "going-to-flower"
    set dance-duration 0
    set unloading-time 0
    set dance-type ""
  ]
end

to go
  ; Main simulation loop following paper's structure

  ; 1. Update patches (decay chemicals and restore colors)
  update-patches

  ; 2. Emit stimuli and diffuse chemicals
  emit-stimuli
  diffuse-chemicals

  ; 3. Visualize dance areas
  visualize-dances

  ; 4. All agents consume nectar
  consume-nectar

  ; 5. Adult agents decide task engagement
  ask bees [ decide-current-task ]

  ; 6. Perform behaviors according to task
  ask bees [ perform-behavior ]

  ; Update larvae
  ask larvae [ update-larva-behavior ]

  ; Update counters
  update-counters

  tick
end

to update-patches
  ask patches [
    ; Decay chemical signals
    set hunger-pheromone hunger-pheromone * 0.95

    ; Clear dance signals (they disappear when dancer stops)
    if waggle-dance-signal > 0 [
      set waggle-dance-signal waggle-dance-signal - 0.1
      if waggle-dance-signal < 0 [ set waggle-dance-signal 0 ]
    ]

    if tremble-dance-signal > 0 [
      set tremble-dance-signal tremble-dance-signal - 0.1
      if tremble-dance-signal < 0 [ set tremble-dance-signal 0 ]
    ]

    if contact-signal > 0 [
      set contact-signal contact-signal - 0.2
      if contact-signal < 0 [ set contact-signal 0 ]
    ]

    ; Restore original color if no dance signals
    if waggle-dance-signal = 0 and tremble-dance-signal = 0 [
      set pcolor original-color
    ]
  ]
end

to emit-stimuli
  ; Stimuli are now emitted directly in the foraging behavior
  ; This procedure can be used for other stimulus emissions if needed
end

to diffuse-chemicals
  ; Diffuse hunger pheromones from larvae
  ask larvae [
    if is-hungry? [
      let alpha 1 - (nectar-reserve / 0.25)
      if alpha < 0 [ set alpha 0 ]

      ask patch-here [
        set hunger-pheromone hunger-pheromone + alpha
      ]
    ]
  ]

  ; Diffuse pheromones to neighboring patches
  diffuse hunger-pheromone 0.1
end

to visualize-dances
  ask patches [
    ; Color patches based on dance signals
    if waggle-dance-signal > 0.1 [
      ; Waggle dance in bright cyan/turquoise
      let intensity waggle-dance-signal / 3  ; Normalize intensity
      if intensity > 1 [ set intensity 1 ]
      set pcolor scale-color cyan intensity 0 1
    ]

    if tremble-dance-signal > 0.1 [
      ; Tremble dance in bright magenta/purple
      let intensity tremble-dance-signal / 3  ; Normalize intensity
      if intensity > 1 [ set intensity 1 ]
      set pcolor scale-color magenta intensity 0 1
    ]

    ; If both signals present, show mixed color (rare but possible)
    if waggle-dance-signal > 0.1 and tremble-dance-signal > 0.1 [
      set pcolor violet
    ]
  ]
end

to consume-nectar
  ask bees [
    let consumption-rate 0.0004
    if current-task = "foraging" [ set consumption-rate 0.001 ]

    set crop-load crop-load - consumption-rate
    if crop-load < 0 [
      ; Bee dies if out of nectar
      die
    ]
  ]

  ask larvae [
    set nectar-reserve nectar-reserve - 0.0004
    if nectar-reserve < 0 [
      ; Larva dies if out of nectar
      die
    ]
    update-larva-hunger
  ]
end

to decide-current-task
  ; Only unemployed bees can switch tasks
  if current-task != "unemployed" [
    ; Check for task abandonment
    let abandon-prob 0
    if current-task = "nursing" [ set abandon-prob 0.005 ]
    if current-task = "storing" [ set abandon-prob 0.005 ]
    if current-task = "foraging" [ set abandon-prob 0.001 ]

    if random-float 1.0 < abandon-prob [
      set current-task "unemployed"
      set color black
    ]
    stop
  ]

  ; Calculate probabilities for each task
  let p-foraging calculate-task-probability "foraging"
  let p-storing calculate-task-probability "storing"
  let p-nursing calculate-task-probability "nursing"

  ; Decide on task based on probabilities
  let rand random-float 1.0

  if rand < p-foraging [
    set current-task "foraging"
    set color red
    set theta-foraging theta-foraging - 0.1
    if theta-foraging < 0 [ set theta-foraging 0 ]
    stop
  ]

  set rand rand - p-foraging
  if rand < p-storing [
    set current-task "storing"
    set color blue
    set theta-storing theta-storing - 0.1
    if theta-storing < 0 [ set theta-storing 0 ]
    stop
  ]

  set rand rand - p-nursing
  if rand < p-nursing [
    set current-task "nursing"
    set color green
    set theta-nursing theta-nursing - 0.1
    if theta-nursing < 0 [ set theta-nursing 0 ]
    stop
  ]

  ; If no task selected, increase thresholds
  set theta-foraging theta-foraging + 0.001
  set theta-storing theta-storing + 0.001
  set theta-nursing theta-nursing + 0.001

  ; Constrain thresholds
  if theta-foraging > 1 [ set theta-foraging 1 ]
  if theta-storing > 1 [ set theta-storing 1 ]
  if theta-nursing > 1 [ set theta-nursing 1 ]
end

to-report calculate-task-probability [task-name]
  let stimulus-strength 0
  let theta-value 0

  if task-name = "foraging" [
    set stimulus-strength [waggle-dance-signal] of patch-here
    set theta-value theta-foraging
  ]

  if task-name = "storing" [
    set stimulus-strength [contact-signal + tremble-dance-signal] of patch-here
    set theta-value theta-storing
  ]

  if task-name = "nursing" [
    set stimulus-strength [hunger-pheromone] of patch-here
    set theta-value theta-nursing
  ]

  ; Calculate probability using equation from paper: p = s^n / (s^n + theta^n)
  let n 2
  let numerator stimulus-strength ^ n
  let denominator numerator + (theta-value ^ n)

  if denominator = 0 [ report 0 ]
  report numerator / denominator
end

to perform-behavior
  if current-task = "unemployed" [
    ; Random movement within hive
    rt random 60 - 30
    fd 0.5
    stay-in-hive
  ]

  if current-task = "foraging" [
    perform-foraging
    ; Don't call stay-in-hive for foragers - they need to go outside!
  ]

  if current-task = "storing" [
    perform-storing
    stay-in-hive
  ]

  if current-task = "nursing" [
    perform-nursing
    stay-in-hive
  ]
end

to perform-foraging
  ; State-based foraging behavior

  if foraging-state = "going-to-flower" [
    ; Go to flower to collect nectar
    face patch flower-x flower-y
    fd 1

    ; Check if reached flower
    if distance patch flower-x flower-y < 2 [
      set foraging-state "at-flower"
      set feeding-time 0
    ]
  ]

  if foraging-state = "at-flower" [
    ; Spend time collecting nectar at flower
    set feeding-time feeding-time + 1
    set crop-load min list 1.0 (crop-load + 0.1)  ; Gradually fill crop

    ; After collecting enough, return to hive
    if crop-load >= 0.8 or feeding-time > 10 [
      set foraging-state "returning"
      set search-time random 100  ; Random search time affects dance type
    ]
  ]

  if foraging-state = "returning" [
    ; Return to hive entrance
    face patch entrance-x entrance-y
    fd 1

    ; Check if reached entrance area
    if distance patch entrance-x entrance-y < 3 [
      set foraging-state "at-entrance"
      set unloading-time 0
    ]
  ]

  if foraging-state = "at-entrance" [
    ; Try to unload nectar and decide on dancing
    set unloading-time unloading-time + 1

    ; Look for storers to transfer nectar
    let nearby-storers bees in-radius 2 with [current-task = "storing"]
    if any? nearby-storers and crop-load > 0.3 [
      ; Transfer nectar to storer
      let storer one-of nearby-storers
      ask storer [
        set crop-load min list 1.0 (crop-load + [crop-load] of myself * 0.5)
      ]
      set crop-load crop-load * 0.5
    ]

    ; After some time at entrance, decide whether to dance
    if unloading-time > 5 [
      ifelse crop-load < 0.3 [
        ; Successfully unloaded, start dancing
        set foraging-state "dancing"
        set dance-duration 0

        ; Determine dance type based on search time
        ifelse search-time <= 20 [
          set dance-type "waggle"
        ] [
          set dance-type "tremble"
        ]
      ] [
        ; Still have nectar, keep trying to unload
        if unloading-time > 15 [
          ; Give up and go back to flower
          set foraging-state "going-to-flower"
        ]
      ]
    ]

    ; Random movement while at entrance
    rt random 60 - 30
    fd 0.3
  ]

  if foraging-state = "dancing" [
    ; Perform dance behavior with enhanced visualization
    set dance-duration dance-duration + 1

    ; Make dancing bee more visible
    ifelse dance-type = "waggle" [
      set color sky  ; Bright blue for waggle dancers
    ] [
      set color violet  ; Purple for tremble dancers
    ]

    ; Dance type depends on search time at flower
    if dance-type = "waggle" [
  ask patches in-radius 3 [
    set waggle-dance-signal waggle-dance-signal + (2 / (1 + distance myself))
  ]
  ; Figure-8 pattern
  rt (sin (dance-duration * 20)) * 30
  fd 0.4
]

    if dance-type = "tremble" [
      ; Tremble dance - long search time means need more storers
      ask patches in-radius 3 [
        set tremble-dance-signal tremble-dance-signal + (2 / (1 + distance myself))
      ]
    ]

    ; Enhanced dance movement pattern
    ifelse dance-type = "waggle" [
      ; Figure-8 waggle dance pattern
      rt (sin (dance-duration * 20)) * 30
      fd 0.4
    ] [
      ; Tremble dance - more erratic movement
      rt random 120 - 60
      fd 0.2
    ]

    ; Finish dancing after some time
    if dance-duration > (15 + random 15) [
      set foraging-state "going-to-flower"
      set dance-duration 0
      set dance-type ""
      set color red  ; Return to normal forager color
    ]
  ]
end

to perform-storing
  ; Move towards entrance or storage area
  ifelse crop-load < 0.1 [
    ; Go to entrance to collect from foragers
    face patch entrance-x entrance-y
    fd 1

    ; Generate contact signals when near entrance (for tremble dance response)
    if distance patch entrance-x entrance-y < 5 [
      ask patches in-radius 2 [
        set contact-signal contact-signal + 0.5
      ]
    ]
  ] [
    ; Go to storage area
    let storage-patches patches with [patch-type = "storage"]
    if any? storage-patches [
      face min-one-of storage-patches [distance myself]
      fd 1

      ; Store nectar if in storage area
      if [patch-type] of patch-here = "storage" [
        set crop-load 0.1
      ]
    ]
  ]
end

to perform-nursing
  ; Navigate towards hunger pheromones
  ifelse crop-load < 0.1 [
    ; Go get honey from storage
    let storage-patches patches with [patch-type = "storage"]
    if any? storage-patches [
      face min-one-of storage-patches [distance myself]
      fd 1

      if [patch-type] of patch-here = "storage" [
        set crop-load 0.8
      ]
    ]
  ] [
    ; Find hungry larvae
    let max-pheromone max [hunger-pheromone] of patches in-radius 5
    ifelse max-pheromone > 0 [
      let target-patch max-one-of patches in-radius 5 [hunger-pheromone]
      face target-patch
      fd 1

      ; Feed larva if on same patch
      let hungry-larva one-of larvae-here with [is-hungry?]
      if hungry-larva != nobody [
        set feeding-time feeding-time + 1
        ask hungry-larva [
          set nectar-reserve nectar-reserve + 0.1
          if nectar-reserve > 0.33 [ set nectar-reserve 0.33 ]
          update-larva-hunger
        ]
        set crop-load crop-load - 0.1
        if crop-load < 0 [ set crop-load 0 ]
      ]
    ] [
      ; Random movement in broodnest
      rt random 60 - 30
      fd 0.5
    ]
  ]
end

to update-larva-behavior
  update-larva-hunger
end

to update-larva-hunger
  set hunger-level 0.25 - nectar-reserve
  if hunger-level < 0 [ set hunger-level 0 ]
  set is-hungry? hunger-level > 0.1

  ; Visual feedback
  ifelse is-hungry? [
    set color red
  ] [
    set color white
  ]
end

to stay-in-hive
  ; Keep bees within hive boundaries
  if xcor < hive-left [ setxy hive-left ycor ]
  if xcor > hive-right [ setxy hive-right ycor ]
  if ycor < hive-bottom [ setxy xcor hive-bottom ]
  if ycor > hive-top [ setxy xcor hive-top ]
end

to update-counters
  set total-foragers count bees with [current-task = "foraging"]
  set total-storers count bees with [current-task = "storing"]
  set total-nurses count bees with [current-task = "nursing"]
  set total-unemployed count bees with [current-task = "unemployed"]
end

; Additional procedures for experiments (as described in paper)

to remove-brood [amount]
  let larvae-to-remove min list amount count larvae
  ask n-of larvae-to-remove larvae [ die ]
end

to add-brood [amount]
  let added 0
  while [added < amount] [
    ; Generate random position within broodnest circle
    let angle random 360
    let radius random-float broodnest-radius
    let x round (broodnest-center-x + (radius * cos angle))
    let y round (broodnest-center-y + (radius * sin angle))

    if (x >= min-pxcor and x <= max-pxcor and
        y >= min-pycor and y <= max-pycor) [

      ask patch x y [
        if patch-type = "broodnest" and not any? larvae-here [
          sprout-larvae 1 [
            set shape "circle"
            set color white
            set size 0.8
            set nectar-reserve random-float 0.33
            set hunger-level 0
            set is-hungry? false
            update-larva-hunger
          ]
          set added added + 1
        ]
      ]
    ]
  ]
end

to remove-workers [amount]
  let workers-to-remove min list amount count bees
  ask n-of workers-to-remove bees [ die ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
830
651
30
30
10.0
1
10
1
1
1
0
0
0
1
-30
30
-30
30
0
0
1
ticks
30.0

BUTTON
33
122
96
155
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

BUTTON
37
81
103
114
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
NetLogo 5.3.1
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
