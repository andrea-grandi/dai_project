globals [
  total-nectar
  light-gradient
  hive-left
  hive-right
  hive-bottom
  hive-top
  flower
  show-debug-info?
  ; Add initial-storers to control number of storer bees
  initial-storers       ; Number of initial storer bees (for slider)
  ; You may also want to add these other commented variables
  ;initial-unemployed    ; Number of initial unemployed bees (for slider)
  ;initial-foragers      ; Number of initial forager bees (for slider)
  ;initial-larvae        ; Number of initial larvae (for slider)
  ;brood-area-radius     ; Radius of the brood area (for slider)
]

breed [ foragers forager ]
breed [ storers storer ]
breed [ nurses nurse ]
breed [ unemployeds unemployed ]  ; Only define unemployed breed once
breed [ larvae larva ]
breed [ flowers flower-agent ]   ; Add a new breed for flowers

patches-own [
  nursing-stimulus   ; Chemical hunger signal from larvae
  foraging-stimulus  ; Waggle dance stimulus
  storing-stimulus   ; Tremble dance/storing stimulus
  nectar-stored      ; Nectar in this cell
  is-brood-cell?     ; True if cell contains larva
  is-storage-cell?    ; True if storage area
]

turtles-own [
  task-state         ; Current task: "foraging", "storing", "nursing", "no-task"
  activity-state     ; Current activity (e.g., "fly-out", "unload")
  nectar-load        ; Current nectar carried (0-1.0)
  theta-foraging     ; Threshold for foraging task
  theta-storing      ; Threshold for storing task
  theta-nursing      ; Threshold for nursing task
  search-time        ; Time spent searching for storers (foragers)
]

larvae-own [
  ;hunger   ; Renamed from nectar-load for clarity
  age
  immobile?  ; Explicit flag to prevent movement
]

;;; SETUP PROCEDURES ;;;
to setup
  clear-all
  set show-debug-info? false

  ; Set default values if sliders don't exist
  if initial-storers = 0 [ set initial-storers 15 ]      ; Default: 15 storers
  if initial-unemployed = 0 [ set initial-unemployed 10 ] ; Default: 10 unemployed
  if initial-foragers = 0 [ set initial-foragers 5 ]     ; Default: 5 foragers
  if initial-larvae = 0 [ set initial-larvae 8 ]         ; Default: 8 larvae
  if brood-area-radius = 0 [ set brood-area-radius 5 ]   ; Default: radius 5

  setup-hive
  setup-flower
  setup-patches
  setup-bees
  setup-larvae
  reset-ticks
  set total-nectar 0
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
      set heading 0    ; Make sure it's upright
      ;set label "Flower"  ; Optional: add label for clarity
      ;set label-color violet

      ;; Store this turtle in the global variable for future reference
      set flower self
    ]
  ]

  ;; Optional: Mark the path from hive to flower for better visualization
  ask patches with [pxcor = flower-x and pycor >= flower-y - 1 and pycor <= flower-y + 1] [
    set pcolor green - 2
  ]
end

; Add to setup-patches to initialize cell colors
to setup-patches
  ask patches [
    ;; Initialize all patches first
    set is-brood-cell? false
    set is-storage-cell? false
    set nectar-stored 1
    set nursing-stimulus 0    ; Initialize stimuli values
    set foraging-stimulus 0
    set storing-stimulus 0
    set pcolor black  ;; Default color outside hive

    ;; Only set hive properties for patches inside hive
    if (pxcor >= hive-left and pxcor <= hive-right and
        pycor >= hive-bottom and pycor <= hive-top) [
      set is-brood-cell? (distancexy (hive-left + (hive-right - hive-left) / 3)
                                   (hive-bottom + (hive-top - hive-bottom) / 2) < brood-area-radius)
      set is-storage-cell? (pycor > hive-top - 20)
      set light-gradient 3.0 / (distancexy hive-left hive-bottom + 1)

      ;; Basic visualization
      ifelse is-brood-cell?
      [ set pcolor brown - 2 ]
      [ ifelse is-storage-cell?
        [ set pcolor yellow - 2 ]  ; Base color for empty storage
        [ set pcolor brown + 3 ]
      ]
    ]
  ]

  ; Apply the cell coloring to any storage cells that start with nectar
  ask patches with [is-storage-cell? and nectar-stored > 0] [
    update-cell-color
  ]
end

to setup-bees
  ; Create unemployed bees
  create-unemployeds initial-unemployed [
    set shape "bee"
    set color white
    set size 0.8
    set task-state "no-task"
    set theta-foraging 0.5
    set theta-storing 0.5
    set theta-nursing 0.5
    set nectar-load random-float 1

    move-to one-of patches with [
      pxcor >= hive-left and pxcor <= hive-right and
      pycor >= hive-bottom and pycor <= hive-top
    ]
  ]

  ; Create forager bees
  create-foragers initial-foragers [
    set shape "bee"
    set color blue
    set size 0.8
    set task-state "foraging"
    set activity-state "start"
    set theta-foraging 0.1
    set nectar-load 0.9
    move-to one-of patches with [
      pxcor >= hive-left and pxcor <= hive-right and
      pycor >= hive-bottom and pycor <= hive-top
    ]
  ]

  ; Create storer bees - NEW!
  create-storers initial-storers [
    set shape "bee"
    set color green           ; Green color for storers
    set size 0.8
    set task-state "storing"
    set activity-state "start"
    set theta-storing 0.1     ; Low threshold - they're dedicated storers
    set theta-foraging 0.7    ; High threshold - less likely to switch to foraging
    set theta-nursing 0.6     ; Medium threshold for nursing
    set nectar-load 0.5       ; Start with some nectar

    ; Position them near the storage area
    move-to one-of patches with [
      pxcor >= hive-left and pxcor <= hive-right and
      pycor >= hive-bottom and pycor <= hive-top and
      is-storage-cell?
    ]
  ]
end

to setup-larvae
  create-larvae initial-larvae [
    set shape "bug"  ; Consider using a non-bee shape
    set color pink
    set size 0.8
    ;set hunger random-float 0.
    set nectar-load random-float 0.33
    set age 0
    set immobile? true  ; Critical - prevents all movement

    ; Move to brood cell and stay there permanently
    move-to one-of patches with [
      pxcor >= hive-left and pxcor <= hive-right and
      pycor >= hive-bottom and pycor <= hive-top and
      is-brood-cell?
    ]

    ; Lock position by remembering the cell
    setxy pxcor pycor  ; Explicitly set position
  ]
end

;;; CHECK FUNCTIONS ;;;
to-report inside-hive?
  ;; More precise boundary checking that excludes the border patches
  report (xcor > hive-left and xcor < hive-right and
          ycor > hive-bottom and ycor < hive-top)
end

to-report at-hive-entrance?
  report (distancexy hive-left hive-bottom < 1)
end

to stay-in-hive-until-exit
  if inside-hive? and not at-hive-entrance? and activity-state = "leave-hive" [
    ;; Create a strong attraction toward the entrance
    facexy hive-left hive-bottom
    fd 0.4
  ]
end

to prevent-wrap
  ;; Only prevent world edge wrapping
  if xcor < min-pxcor [ set xcor min-pxcor ]
  if xcor > max-pxcor [ set xcor max-pxcor ]
  if ycor < min-pycor [ set ycor min-pycor ]
  if ycor > max-pycor [ set ycor max-pycor ]
end

;;; MAIN SIMULATION LOOP ;;;
to go
  ;if ticks >= 10000 [ stop ]  ; Stop condition for demonstration

  ;; Make sure flower exists - create it if missing
  ensure-flower-exists
  prevent-larvae-movement

  update-stimuli
  ask turtles with [breed != flowers] [ perform-activity ]  ; Skip flower agents
  diffuse nursing-stimulus 0.05  ; Chemical signal diffusion (observer context)

  ; Update plots (automatically adds data to plots)
  update-plots

  tick
end

;; New procedure to ensure flower exists
to ensure-flower-exists
  ;; If flower doesn't exist or is invalid, recreate it
  if flower = nobody or not is-turtle? flower [
    setup-flower
  ]
end

;;; STIMULI UPDATE ;;;
;; Update for the update-stimuli procedure to remove old dance effects
to update-stimuli
  ask patches [
    ;; Reduce old stimuli values over time
    set foraging-stimulus foraging-stimulus * 0.95  ;; Decay factor
    set storing-stimulus storing-stimulus * 0.95
    set nursing-stimulus 0

    ;; Reset colors for patches that are not actively stimulated
    if foraging-stimulus < 0.1 and storing-stimulus < 0.1 [
      ;; Only reset color for non-hive patches or normal hive floor
      if pcolor = blue or pcolor = violet [
        ;; Inside hive, restore to appropriate color based on type
        ifelse (pxcor >= hive-left and pxcor <= hive-right and
                pycor >= hive-bottom and pycor <= hive-top) [
          ifelse is-brood-cell? [
            set pcolor brown - 2
          ][
            ifelse is-storage-cell? [
              update-cell-color  ; Preserve nectar levels in storage cells
            ][
              set pcolor brown + 3
            ]
          ]
        ][
          set pcolor black  ;; Outside hive, restore to black
        ]
      ]
    ]
  ]

  ;; Larval hunger signals
  ask larvae [
    ;print nectar-load
    if nectar-load < 0.25 [ ; hunger threshold
      let my-load nectar-load  ;; Store the nectar load in a local variable
      ask patch-here [
        set nursing-stimulus nursing-stimulus + (1 - (my-load / 0.33))
      ]
    ]
  ]
end

;;; BEE ACTIVITIES ;;;
to perform-activity

  ;check-refill

  ifelse task-state = "no-task" [ handle-no-task ]
  [
    if task-state = "foraging" [
      stay-in-hive-until-exit
      handle-foraging
      check-refill
      consume-nectar
      prevent-wrap

    ]
    if task-state = "storing" [
      handle-storing
      check-refill
      consume-nectar
      prevent-wrap
    ]
    if task-state = "nursing" [
      handle-nursing
      check-refill
      consume-nectar
      prevent-wrap
    ]
  ]

  ;consume-nectar
  ;prevent-wrap
end

to handle-foraging  ; forager procedure
  let hive-entrance-x hive-left
  let hive-entrance-y hive-bottom

  if activity-state = "start" [
    set activity-state "leave-hive"
  ]

  if activity-state = "leave-hive" [
    ;; First ensure we're inside the hive
    if not inside-hive? [
      facexy (hive-left + hive-right) / 2 (hive-bottom + hive-top) / 2
      fd 0.2
      stop
    ]

    ;; Move directly toward the entrance
    facexy hive-entrance-x hive-entrance-y
    fd 0.2

    ;; Only proceed to fly-out when at entrance
    if at-hive-entrance? [
      set activity-state "fly-out"
      ;; Move outside the hive entrance to avoid immediately re-entering
      set xcor hive-entrance-x - 1
    ]
    stop  ; Don't proceed further this tick
  ]

  if activity-state = "fly-out" [
    ;; If we're still at the entrance, move away first
    if at-hive-entrance? [
      set heading 270  ; Face left/west to move away from hive
      fd 0.5
      stop
    ]

    ;; Fly to food source - use the flower agent directly
    if flower != nobody and is-turtle? flower [
      face flower
      fd 0.5
      if distance flower < 1 [
        set nectar-load 1.0  ; Fill with nectar
        set activity-state "fly-home"
      ]
    ]
  ]

  if activity-state = "fly-home" [
    ;; Must approach from the entrance
    if ycor < hive-bottom [  ;; If below entrance, move up to it
      set ycor hive-bottom
      facexy hive-entrance-x hive-entrance-y
    ]
    facexy hive-entrance-x hive-entrance-y
    fd 0.5

    ;; Only enter hive when at entrance
    if at-hive-entrance? [
      ;; Actually move inside the hive before changing state
      set xcor hive-entrance-x + 1  ; Move inside the hive
      set activity-state "seek-storer"
      set search-time 0
    ]
  ]

  if activity-state = "seek-storer" [
    ;; Move deeper into the hive
    set xcor xcor + 0.5

    ;; Find a storer or start looking for one
    let nearby-storer one-of storers in-radius 2
    ifelse nearby-storer != nobody [
      set activity-state "unload-nectar"
      ask nearby-storer [
        set activity-state "receive-nectar"
      ]
    ] [
      ;; Increment search time and check if too long
      set search-time search-time + 1
      if search-time > 10 [
        set activity-state "tremble" ; Signal need for storers

        ;; Move to a random position in the bottom area of the hive for dancing
        move-to-dance-floor
      ]
    ]
  ]

  if activity-state = "collect-nectar" [
    ;; This is now handled in the fly-out section
    set activity-state "fly-home"
  ]

  if activity-state = "unload-nectar" [
    ; Transfer nectar to storer
    set nectar-load 0.5  ; Keep some for self
    set activity-state "waggle"

    ;; Move to a random position in the bottom area of the hive for dancing
    move-to-dance-floor
  ]

  if activity-state = "waggle" [
    ; Perform waggle dance to recruit foragers - smaller area
    rt random 30 - 15
    fd 0.1

    ; Perform the waggle dance effect in a smaller radius (1.2 instead of 3)
    ask patches in-radius 1.2 [
      set foraging-stimulus foraging-stimulus + 1 / (distance myself + 1)
      set pcolor blue
    ]

    ; Finish dance after some time
    if random-float 1 < 0.05 [
      set activity-state "leave-hive"
    ]
  ]

  if activity-state = "tremble" [
    ; Perform tremble dance to recruit storers - smaller area
    rt random 40 - 20
    fd 0.05

    ; Perform the tremble dance effect in a smaller radius (1.0 instead of 3)
    ask patches in-radius 1.0 [
      set storing-stimulus storing-stimulus + 1 / (distance myself + 1)
      set pcolor violet
    ]

    ; Finish dance after some time
    if random-float 1 < 0.1 [
      set activity-state "leave-hive"
    ]
  ]
end

;; New procedure to move bee to dance floor area
to move-to-dance-floor
  ;; Calculate random position in bottom area of hive
  let dance-x hive-left + random (hive-right - hive-left - 2) + 1
  let dance-y hive-bottom + random 3 + 1   ; Stay in bottom area, 1-3 patches up from bottom

  ;; Move to that position
  setxy dance-x dance-y

  ;; Make sure we're still inside the hive (safety check)
  if not inside-hive? [
    move-to one-of patches with [
      pxcor > hive-left and pxcor < hive-right and
      pycor > hive-bottom and pycor < hive-bottom + 4
    ]
  ]
end

to handle-storing  ; storer procedure
  ; First ensure the bee stays in the hive
  if not inside-hive? [
    facexy (hive-left + hive-right) / 2 (hive-bottom + hive-top) / 2
    fd 0.2
    stop
  ]

  if activity-state = "start" [
    set activity-state "wait-for-nectar"
    let target-x random-float (hive-right - hive-left - 2) + hive-left + 1
    let target-y hive-bottom + 1
    setxy target-x target-y
  ]

  if activity-state = "wait-for-nectar" [
    ; Wait for foragers with nectar
    if ycor > (hive-bottom + 3) [
      facexy pxcor (hive-bottom + 1)  ; Stay toward the bottom
      fd 0.2
    ]
    ; Small random movement while waiting
    rt random 30 - 15
    fd 0.1
    set activity-state "receive-nectar"
  ]

  if activity-state = "receive-nectar" [
    ; Get nectar from forager
    set nectar-load nectar-load + 0.9  ; Get 0.9 from forager
    set activity-state "find-storage"
  ]

  if activity-state = "find-storage" [
    ; Only look for storage if we have more than the minimum reserve (0.5)
    ifelse nectar-load > 0.5 [
      ; Find storage cell
      let target-cell min-one-of (patches with [is-storage-cell? and nectar-stored < 1.0]) [distance myself]

      ifelse target-cell != nobody [
        face target-cell
        fd 0.2
        if distance target-cell < 0.1 [
          set activity-state "store-nectar"
        ]
      ] [
        ; If no storage cells available, wander a bit
        rt random 45 - 22
        fd 0.1
      ]
    ] [
      ; We don't have enough nectar to store (below reserve), so go back to waiting
      set activity-state "wait-for-nectar"
    ]
  ]

  if activity-state = "store-nectar" [
    ; Calculate how much nectar we can store while maintaining our 0.5 reserve
    let excess-nectar max (list 0 (nectar-load - 0.5))

    if excess-nectar > 0 [
      ; Calculate available space in the cell
      let available-space 1.0 - [nectar-stored] of patch-here
      let amount-to-store min (list excess-nectar available-space)

      ; Ask the patch to update its stored nectar and color
      ask patch-here [
        set nectar-stored nectar-stored + amount-to-store
        update-cell-color  ; Update the cell color based on new nectar level
      ]

      ; Update bee's nectar load, maintaining the 0.5 minimum
      set nectar-load nectar-load - amount-to-store

      ; Update total nectar count
      set total-nectar total-nectar + amount-to-store
    ]

    ; Go back to waiting for nectar
    set activity-state "wait-for-nectar"
  ]
end

; New procedure to update cell color based on nectar content
to update-cell-color  ; patch procedure
  ;print "Updating cell color"  ; Debug output
  ;if is-storage-cell? [
    ;print "This is a storage cell"  ; More debug
    ; Create a more distinctive color gradient based on nectar level
    ifelse nectar-stored > 0 [
      ; Empty to full: yellow → gold → orange → red
      ifelse nectar-stored > 0.75 [
        set pcolor red        ; Very full (more than 75%)
      ][
        ifelse nectar-stored > 0.5 [
          set pcolor orange   ; Half full (50-75%)
        ][
          ifelse nectar-stored > 0.25 [
            set pcolor yellow + 1  ; Quarter full (25-50%)
          ][
            set pcolor yellow  ; Just starting to fill (0-25%)
          ]
        ]
      ]
    ][
      ; Empty storage cell - light yellow
      set pcolor yellow - 2
    ]

end

to handle-nursing  ; nurse procedure
  ; First ensure the bee stays in the hive
  if not inside-hive? [
    facexy (hive-left + hive-right) / 2 (hive-bottom + hive-top) / 2
    fd 0.2
    stop
  ]

  ; Check nectar levels and refill if needed
  if nectar-load < 0.3 [  ; Lower threshold to check more frequently
    set activity-state "refill-nectar"
  ]

  if activity-state = "start" [
    set activity-state "find-hungry-larva"
  ]

  if activity-state = "refill-nectar" [
    ; Find storage cell with nectar
    let target-cells patches with [is-storage-cell? and nectar-stored > 0.1]

    ifelse any? target-cells [
      let target-cell min-one-of target-cells [distance myself]

      ; Move toward storage
      face target-cell
      fd 0.2  ; Move slower for more precise positioning

      ; When reached, take some nectar
      if distance target-cell < 0.5 [  ; Reduced distance threshold
        let amount-to-take min (list 0.7 [nectar-stored] of target-cell)
        set nectar-load nectar-load + amount-to-take
        ask target-cell [
          set nectar-stored nectar-stored - amount-to-take
          update-cell-color
        ]
        set activity-state "find-hungry-larva"
      ]
    ] [
      ; No nectar available - try to find another nurse to share
      let donors other nurses in-radius 3 with [nectar-load > 0.5]

      ifelse any? donors [
        let donor min-one-of donors [distance myself]
        face donor
        fd 0.2

        if distance donor < 0.5 [
          ask donor [
            set nectar-load nectar-load - 0.3
          ]
          set nectar-load nectar-load + 0.3
          set activity-state "find-hungry-larva"
        ]
      ] [
        ; Wander randomly if no nectar source found
        rt random 90 - 45
        fd 0.1
      ]
    ]
  ]

  if activity-state = "find-hungry-larva" [
    ; Find hungry larvae - look for larvae with low nectar
    let hungry-larvae larvae with [nectar-load < 0.7]  ; Increased threshold

    ifelse any? hungry-larvae [
      let target-larva min-one-of hungry-larvae [distance myself]
      face target-larva
      fd 0.2  ; Move slower for more precise positioning

      ; When reached, feed the larva
      if distance target-larva < 0.5 [  ; Reduced distance threshold
        let feed-amount min (list 0.2 nectar-load)  ; Feed smaller amounts
        if feed-amount > 0 [  ; Only feed if we have nectar
          ask target-larva [
            set nectar-load nectar-load + feed-amount
          ]
          set nectar-load nectar-load - feed-amount
        ]

        ; If we still have nectar, keep feeding others
        ifelse nectar-load > 0.2 [
          set activity-state "find-hungry-larva"  ; Look for more larvae to feed
        ] [
          set activity-state "refill-nectar"  ; Need to refill
        ]
      ]
    ] [
      ; No hungry larvae nearby, wander around the brood area
      rt random 90 - 45
      fd 0.1
    ]
  ]

  ; Add debugging output if needed
  ; if ticks mod 100 = 0 [
  ;   show (word "Nurse " who " state: " activity-state " nectar: " nectar-load)
  ; ]
end

to prevent-larvae-movement
  ask larvae [
    if immobile? [
      setxy pxcor pycor  ; Force staying in place
    ]
  ]
end

to handle-no-task  ; unemployed procedure
  ; First ensure the bee stays in the hive
  if not inside-hive? [
    facexy (hive-left + hive-right) / 2 (hive-bottom + hive-top) / 2
    fd 0.2
    stop
  ]
  ; Emergency refill if critically low
  ;if nectar-load < 0.2 [
  ;  let target-cell nearest-storage-cell  ; Use your existing reporter
  ;  if target-cell != nobody [
  ;    face target-cell
  ;    fd 0.3
  ;    if distance target-cell < 1 [
  ;      ask target-cell [
  ;        let take-amount min (list 0.3 nectar-stored)
  ;        set nectar-stored nectar-stored - take-amount
  ;        update-cell-color
  ;      ]
  ;      set nectar-load nectar-load + 0.3
  ;    ]
  ;  ]
  ;]
  let p-foraging (task-probability "foraging")
  let p-storing (task-probability "storing")
  let p-nursing (task-probability "nursing")

  ; Threshold-based task selection
  if random-float 1 < p-foraging [ switch-to-task "foraging" ]
  if random-float 1 < p-storing [ switch-to-task "storing" ]
  if random-float 1 < p-nursing [ switch-to-task "nursing" ]

  ; Random movement
  rt random 30 - 10
  fd 0.1
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

  ; Response threshold function (Equation 12 from literature)
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
  ]
  if new-task = "storing" [
    set breed storers
    set color green
  ]
  if new-task = "nursing" [
    set breed nurses
    set color yellow
  ]

  set task-state new-task
  set activity-state "start"
  set shape "bee"
  set size 0.8
end

;;; UTILITIES ;;;
to check-refill  ; turtle procedure
  ; Only try to refill if nectar is low and we're not currently foraging
  if nectar-load < 0.3 [;and (task-state != "foraging" or
      ;(task-state = "foraging" and (activity-state = "waggle" or activity-state = "tremble"))) [

    ; First make sure we're inside the hive
    if not inside-hive? [
      facexy (hive-left + hive-right) / 2 (hive-bottom + hive-top) / 2
      fd 0.3
      stop
    ]

    ; Find storage cell with nectar - prefer cells with more nectar
    let nectar-cells patches with [is-storage-cell? and nectar-stored > 0.2]

    ifelse any? nectar-cells [
      let target-cell max-one-of nectar-cells [nectar-stored]

      ; If we're not already at the nectar cell, move toward it
      ifelse distance target-cell > 1 [
        face target-cell
        fd 0.3
      ][
        ; We're at the cell, take some nectar
        let amount-to-take min (list 0.5 [nectar-stored] of patch-here)
        set nectar-load nectar-load + amount-to-take

        ; Update cell's nectar and color
        ask patch-here [
          set nectar-stored nectar-stored - amount-to-take
          update-cell-color  ; Important: update color after taking nectar
        ]

        ; Visually show the refill by temporarily changing the bee's size
        ;set size size + 0.2
        ;set size size - 0.2
      ]
    ][
      ; No storage cells with nectar, look for other bees with nectar to share
      let nearby-bee one-of other turtles in-radius 2 with [nectar-load > 0.4 and breed != larvae]
      if nearby-bee != nobody [
        let amount-to-share 0.2
        ask nearby-bee [
          set nectar-load nectar-load - amount-to-share
        ]
        set nectar-load nectar-load + amount-to-share
      ]
    ]
  ]
end

to consume-nectar
  ifelse activity-state = "fly-out" or activity-state = "fly-home" [
    set nectar-load nectar-load - 0.0004  ; High metabolic rate when flying
  ][
    set nectar-load nectar-load - 0.001  ; Lower metabolic rate when in hive
  ]

  set nectar-load nectar-load - 0.0004

  if nectar-load <= 0 [
      die
  ]
end




;to consume-nectar  ; turtle procedure
  ;if breed = larvae [
    ;print nectar-load
 ;   if nectar-load <= 0 [
  ;    die
   ; ]
  ;]
  ; Different consumption rates based on activity
;  ifelse activity-state = "fly-out" or activity-state = "fly-home" [
;    set nectar-load nectar-load - 0.001  ; High metabolic rate when flying
;  ][
;    set nectar-load nectar-load - 0.002  ; Lower metabolic rate when in hive
;  ]

  ; Instead of dying immediately, give bees chance to refill
;  if nectar-load <= 0 [
    ;ifelse inside-hive? [
      ; Emergency protocol - move toward storage area
    ;  let storage-area one-of patches with [is-storage-cell?]
    ;  if storage-area != nobody [
    ;    face storage-area
    ;    fd 0.5
    ;  ]
      ; Give a tiny bit of nectar to prevent immediate death
    ;  set nectar-load 0.1
    ;][
      ; If outside and completely out of nectar, die
 ;     die
    ;]
 ; ]
;end

to-report storage-cells-colored-correctly?
  let problem-cells patches with [
    is-storage-cell? and (
      (nectar-stored > 0.75 and pcolor != red) or
      (nectar-stored > 0.5 and nectar-stored <= 0.75 and pcolor != orange) or
      (nectar-stored > 0.25 and nectar-stored <= 0.5 and pcolor != yellow + 1) or
      (nectar-stored > 0 and nectar-stored <= 0.25 and pcolor != yellow) or
      (nectar-stored = 0 and pcolor != yellow - 2)
    )
  ]

  report count problem-cells = 0
end

to-report nearest-storage-cell
  report min-one-of (patches with [is-storage-cell? and nectar-stored > 0.1]) [distance myself]
end
@#$#@#$#@
GRAPHICS-WINDOW
384
48
1202
867
-1
-1
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
-40
40
-40
40
0
0
1
ticks
30.0

BUTTON
31
30
97
63
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
122
31
185
64
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
31
82
203
115
brood-area-radius
brood-area-radius
1
10
6.0
1
1
NIL
HORIZONTAL

SLIDER
32
126
204
159
initial-unemployed
initial-unemployed
500
800
685.0
1
1
NIL
HORIZONTAL

SLIDER
32
172
204
205
initial-foragers
initial-foragers
0
50
15.0
1
1
NIL
HORIZONTAL

SLIDER
32
218
204
251
initial-larvae
initial-larvae
0
100
100.0
1
1
NIL
HORIZONTAL

PLOT
28
266
348
570
Bee Population 
time
bees
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Foragers" 1.0 0 -14070903 true "" "plot count foragers"
"Nurses" 1.0 0 -1184463 true "" "plot count nurses"
"Storers" 1.0 0 -15040220 true "" "plot count storers"
"Larvae" 1.0 0 -2064490 true "" "plot count larvae"
"Unemployed" 1.0 0 -9276814 true "" "plot count unemployeds"

PLOT
38
613
238
763
Nectar Load
time
load 
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Nectar Load" 1.0 0 -16777216 true "" "plot sum [nectar-stored] of patches with [is-storage-cell?]"

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
