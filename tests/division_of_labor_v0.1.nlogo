; TaskSelSim: A Multi-agent Model of Honeybee Division of Labor
; Based on Schmickl & Crailsheim (2008)

breed [adults adult]
breed [larvae larva]

adults-own [
  task                   ; Current task: "no-task", "foraging", "storing", "nursing"
  crop-load              ; Amount of nectar currently carried
  theta-nursing          ; Individual thresholds for tasks
  theta-storing
  theta-foraging
  search-time            ; Time spent searching for a storer bee
  busy-time              ; Time spent on current activity
]

larvae-own [
  nectar-reserve         ; Nectar reserves of larva
  hungry?                ; Is the larva hungry?
]

patches-own [
  honey-amount           ; Amount of honey stored in this cell
  is-brood-cell?         ; Is this a brood cell?
  is-honey-cell?         ; Is this a honey storage cell?
  is-entrance?           ; Is this the hive entrance?
  dance-waggle           ; Intensity of waggle dance stimulus
  dance-tremble          ; Intensity of tremble dance stimulus
  contact-stimulus       ; Intensity of contact stimulus
  chemical-stimulus      ; Intensity of chemical stimulus (from hungry larvae)
  light-intensity        ; Light intensity (decreasing from entrance)
]

globals [
  entrance-xcor          ; X coordinate of entrance
  entrance-ycor          ; Y coordinate of entrance
  broodnest-xcor         ; Center X of broodnest
  broodnest-ycor         ; Center Y of broodnest
  honey-area-xcor        ; Center X of honey storage area
  honey-area-ycor        ; Center Y of honey storage area

  ; Constants
  capacity-larva         ; Max nectar capacity of larva
  cr-low                 ; Low consumption rate
  cr-high                ; High consumption rate (for flying bees)
  cr-larva               ; Larva consumption rate

  ; Task transition parameters
  lambda-nursing         ; Rate at which nursing bees become unemployed
  lambda-storing         ; Rate at which storing bees become unemployed
  lambda-foraging        ; Rate at which foraging bees become unemployed

  ; Threshold adaptation parameters
  xi                     ; Decrease rate for thresholds when task is performed
  phi                    ; Increase rate for thresholds when task is not performed

  ; Stimuli parameters
  decay-rate             ; Decay rate of chemical stimulus

  ; Counters and statistics
  num-foragers           ; Number of foraging bees
  num-storers            ; Number of storing bees
  num-nurses             ; Number of nursing bees
  num-unemployed         ; Number of unemployed bees
  nectar-income          ; Net nectar income
  nectar-colony-total    ; Total nectar in colony

  ; Cage experiment variables
  cage-present?          ; Is the virtual cage present?
  cage-radius            ; Radius of the virtual cage
]

; Setup procedures
to setup
  clear-all
  setup-constants
  setup-patches
  setup-bees
  setup-larvae
  reset-ticks
end

to setup-constants
  set capacity-larva 0.33

  set cr-low 0.0004
  set cr-high 0.001
  set cr-larva 0.0004

  set lambda-nursing 0.005
  set lambda-storing 0.005
  set lambda-foraging 0.001

  set xi 0.1
  set phi 0.001

  set decay-rate 0.05

  set entrance-xcor 0
  set entrance-ycor 0
  set broodnest-xcor 0
  set broodnest-ycor 0
  set honey-area-xcor 10
  set honey-area-ycor 10

  set cage-present? false
  set cage-radius 5
end

to setup-patches
  ; Set up the hive space
  ask patches [
    set is-brood-cell? false
    set is-honey-cell? false
    set is-entrance? false
    set dance-waggle 0
    set dance-tremble 0
    set contact-stimulus 0
    set chemical-stimulus 0
    set honey-amount 0
  ]

  ; Set up entrance area
  ask patch entrance-xcor entrance-ycor [
    set is-entrance? true
    set pcolor yellow
  ]

  ; Set up broodnest area
  ask patches with [distance (patch broodnest-xcor broodnest-ycor) < 8] [
    set is-brood-cell? true
    set pcolor brown
  ]

  ; Set up honey storage area
  ask patches with [distance (patch honey-area-xcor honey-area-ycor) < 6] [
    set is-honey-cell? true
    set pcolor orange
    set honey-amount random-float 1.0  ; Initial honey stores
  ]

  ; Set up light gradient
  ask patches [
    set light-intensity 1 - (distance (patch entrance-xcor entrance-ycor) / max-pxcor)
    if light-intensity < 0 [set light-intensity 0]
  ]
end

to setup-bees
  create-adults 300 [
    setxy random-xcor random-ycor
    set shape "bee"
    set color white
    set size 1
    set task "no-task"
    set crop-load random-float 1.0
    set theta-nursing random-float 0.01
    set theta-storing random-float 0.01
    set theta-foraging random-float 0.01
    set search-time 0
    set busy-time 0
  ]
end

to setup-larvae
  create-larvae 100 [
    move-to one-of patches with [is-brood-cell?]
    set shape "dot"
    set color yellow
    set size 0.5
    set nectar-reserve random-float capacity-larva
    set hungry? nectar-reserve < (capacity-larva / 4)
  ]
end

; Main procedure
to go
  if not any? adults [stop]  ; Stop if all bees died

  ; Update patches (chemical decay, etc.)
  update-patches

  ; Emit stimuli
  emit-stimuli
  diffuse-chemicals

  ; Consume nectar
  consume-nectar

  ; Update tasks
  task-decisions

  ; Perform behavior according to task
  perform-tasks

  ; Update statistics
  update-stats

  tick
end

to update-patches
  ; Decay of chemicals
  ask patches [
    set chemical-stimulus chemical-stimulus * (1 - decay-rate)
  ]
end

to emit-stimuli
  ; Larvae emit chemical hunger stimulus
  ask larvae with [hungry?] [
    let hunger-level 1 - (nectar-reserve / (capacity-larva / 4))
    ask patch-here [
      set chemical-stimulus chemical-stimulus + hunger-level
      if chemical-stimulus > 1 [set chemical-stimulus 1]
    ]
  ]

  ; Foragers emit contact stimulus and dances
  ask adults with [task = "foraging" and search-time > 0] [
    if search-time > 50 [  ; Tremble dance
      ask patches in-radius 3 [
        set dance-tremble dance-tremble + (1 / (1 + distance myself))
        if dance-tremble > 1 [set dance-tremble 1]
      ]
    ]
    if search-time <= 20 and search-time > 0 [  ; Waggle dance
      ask patches in-radius 3 [
        set dance-waggle dance-waggle + (1 / (1 + distance myself))
        if dance-waggle > 1 [set dance-waggle 1]
      ]
    ]

    ; Contact stimulus
    ask patches in-radius 1 [
      set contact-stimulus 1
    ]
  ]
end

to diffuse-chemicals
  diffuse chemical-stimulus 0.5
end

to consume-nectar
  ; Adults consume nectar
  ask adults [
    ifelse task = "foraging" and (distance (patch entrance-xcor entrance-ycor) > 10) [
      set crop-load crop-load - cr-high  ; Higher consumption for flying foragers
    ] [
      set crop-load crop-load - cr-low   ; Regular consumption
    ]

    if crop-load <= 0 [
      set crop-load 0
      die  ; Bee dies if out of nectar
    ]
  ]

  ; Larvae consume nectar
  ask larvae [
    set nectar-reserve nectar-reserve - cr-larva
    set hungry? nectar-reserve < (capacity-larva / 4)

    if nectar-reserve <= 0 [
      set nectar-reserve 0
      die  ; Larva dies if out of nectar
    ]
  ]
end

to task-decisions
  ; Employed bees might become unemployed
  ask adults with [task = "nursing"] [
    if random-float 1 < lambda-nursing [
      set task "no-task"
      set color white
    ]
  ]

  ask adults with [task = "storing"] [
    if random-float 1 < lambda-storing [
      set task "no-task"
      set color white
    ]
  ]

  ask adults with [task = "foraging"] [
    if random-float 1 < lambda-foraging [
      set task "no-task"
      set color white
    ]
  ]

  ; Unemployed bees may engage in a task
  ask adults with [task = "no-task"] [
    let stimuli-present? false
    let local-chem [chemical-stimulus] of patch-here
    let local-waggle [dance-waggle] of patch-here
    let local-tremble [dance-tremble] of patch-here
    let local-contact [contact-stimulus] of patch-here

    ; Check nursing stimulus (chemicals from hungry larvae)
    if local-chem > 0 [
      set stimuli-present? true
      let prob-nursing (local-chem ^ 2) / (local-chem ^ 2 + theta-nursing ^ 2)
      if random-float 1 < prob-nursing [
        set task "nursing"
        set color red
        set theta-nursing theta-nursing - xi  ; Threshold reinforcement
      ]
    ]

    ; Check storing stimulus (tremble dance or contact)
    if local-tremble > 0 or local-contact > 0 [
      set stimuli-present? true
      let max-storing-stimulus max (list local-tremble local-contact)
      let prob-storing (max-storing-stimulus ^ 2) / (max-storing-stimulus ^ 2 + theta-storing ^ 2)
      if random-float 1 < prob-storing [
        set task "storing"
        set color blue
        set theta-storing theta-storing - xi  ; Threshold reinforcement
      ]
    ]

    ; Check foraging stimulus (waggle dance)
    if local-waggle > 0 [
      set stimuli-present? true
      let prob-foraging (local-waggle ^ 2) / (local-waggle ^ 2 + theta-foraging ^ 2)
      if random-float 1 < prob-foraging [
        set task "foraging"
        set color green
        set theta-foraging theta-foraging - xi  ; Threshold reinforcement
      ]
    ]

    ; If any stimuli were present but no task was chosen, increase thresholds
    if stimuli-present? [
      if local-chem > 0 [set theta-nursing theta-nursing + phi]
      if local-tremble > 0 or local-contact > 0 [set theta-storing theta-storing + phi]
      if local-waggle > 0 [set theta-foraging theta-foraging + phi]
    ]

    ; Ensure thresholds stay within bounds
    set theta-nursing max (list 0 (min (list theta-nursing 1)))
    set theta-storing max (list 0 (min (list theta-storing 1)))
    set theta-foraging max (list 0 (min (list theta-foraging 1)))
  ]
end

to perform-tasks
  ; Unemployed bees move randomly
  ask adults with [task = "no-task"] [
    rt random 30 - 15
    fd 0.1
  ]

  ; Forager behavior
  ask adults with [task = "foraging"] [
    ifelse distance (patch entrance-xcor entrance-ycor) > 10 [
      ; Outside the hive - fly to/from food source
      ifelse crop-load < 0.5 [
        ; Fly to food source
        fd 1
        if random 20 = 0 [
          ; Found food
          set crop-load 1
          rt 180  ; Turn back to hive
        ]
      ] [
        ; Return to hive with food
        face patch entrance-xcor entrance-ycor
        fd 1
      ]
    ] [
      ; Inside the hive
      ifelse crop-load > 0.5 [
        ; Look for storer bee
        set search-time search-time + 1
        face patch entrance-xcor entrance-ycor
        fd 0.1

        ; Try to unload
        let nearby-storer one-of (adults-on neighbors) with [task = "storing" and crop-load < 0.8]
        if nearby-storer != nobody [
          ask nearby-storer [
            set crop-load min (list 1 (crop-load + [crop-load] of myself))
          ]
          set crop-load 0.1  ; Keep a small amount
          set search-time 0
          rt 180
        ]
      ] [
        ; Head out to forage again
        face patch entrance-xcor entrance-ycor
        fd 0.2
      ]
    ]
  ]

  ; Storer behavior
  ask adults with [task = "storing"] [
    ifelse crop-load > 0.5 [
      ; Head to storage area
      face patch honey-area-xcor honey-area-ycor
      fd 0.2

      ; Store honey
      if [is-honey-cell?] of patch-here [
        ask patch-here [
          set honey-amount honey-amount + [crop-load] of myself * 0.5
        ]
        set crop-load crop-load * 0.5  ; Keep some for self
      ]
    ] [
      ; Head to entrance to receive more nectar
      face patch entrance-xcor entrance-ycor
      fd 0.2
    ]
  ]

  ; Nurse behavior
  ask adults with [task = "nursing"] [
    ifelse crop-load < 0.3 [
      ; Need to refill - go to honey storage
      uphill honey-amount
      fd 0.1

      ; Take honey from cells
      if [is-honey-cell? and honey-amount > 0.1] of patch-here [
        let amount-taken min (list 0.2 [honey-amount] of patch-here)
        set crop-load crop-load + amount-taken
        ask patch-here [
          set honey-amount honey-amount - amount-taken
        ]
      ]
    ] [
      ; Look for hungry larvae - follow chemical gradient
      uphill chemical-stimulus
      fd 0.1

      ; Check for cage when active
      if cage-present? and distance (patch broodnest-xcor broodnest-ycor) < cage-radius [
        ; Can't enter cage area
        rt 180
        fd 0.3
      ]

      ; Feed larvae
      let hungry-larva one-of larvae-here with [hungry?]
      if hungry-larva != nobody and crop-load > 0.1 [
        let transfer-amount min (list 0.1 (capacity-larva - [nectar-reserve] of hungry-larva))
        if transfer-amount > 0 [
          ask hungry-larva [
            set nectar-reserve nectar-reserve + transfer-amount
            set hungry? nectar-reserve < (capacity-larva / 4)
          ]
          set crop-load crop-load - transfer-amount
        ]
      ]
    ]
  ]

  ; Make dances disappear
  ask patches [
    set dance-waggle 0
    set dance-tremble 0
    set contact-stimulus 0
  ]
end

to update-stats
  set num-foragers count adults with [task = "foraging"]
  set num-storers count adults with [task = "storing"]
  set num-nurses count adults with [task = "nursing"]
  set num-unemployed count adults with [task = "no-task"]

  set nectar-colony-total (sum [crop-load] of adults +
                          sum [nectar-reserve] of larvae +
                          sum [honey-amount] of patches)
end

; Experiment procedures
to cage-experiment
  set cage-present? true
end

to remove-cage
  set cage-present? false
end

to add-larvae [num]
  create-larvae num [
    move-to one-of patches with [is-brood-cell?]
    set shape "dot"
    set color yellow
    set size 0.5
    set nectar-reserve random-float capacity-larva
    set hungry? nectar-reserve < (capacity-larva / 4)
  ]
end

to remove-larvae [num]
  ask up-to-n-of num larvae [
    die
  ]
end

to add-adults [num]
  create-adults num [
    setxy random-xcor random-ycor
    set shape "bee"
    set color white
    set size 1
    set task "no-task"
    set crop-load random-float 1.0
    set theta-nursing random-float 0.01
    set theta-storing random-float 0.01
    set theta-foraging random-float 0.01
    set search-time 0
    set busy-time 0
  ]
end

to remove-adults [num]
  ask up-to-n-of num adults [
    die
  ]
end

; Utility procedures
to-report up-to-n-of-2 [n agentset]
  ifelse count agentset <= n
    [ report agentset ]
    [ report n-of n agentset ]
end
@#$#@#$#@
GRAPHICS-WINDOW
344
10
1128
711
-1
-1
20.973
1
10
1
1
1
0
1
1
1
-18
18
-16
16
0
0
1
ticks
30.0

BUTTON
39
62
105
95
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
43
128
106
161
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
