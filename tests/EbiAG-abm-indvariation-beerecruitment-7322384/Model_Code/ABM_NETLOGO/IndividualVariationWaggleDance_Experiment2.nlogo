globals [
  ;; MODEL PARAMETERS
  ticks-per-day
  random-val
  patch-yield                                        ; yield (in J) that an individual recieves on foraging at a patch
  patch-nectar-handling-time-mean                    ; mean time spent by an individual foraging at a patch
  patch-nectar-handling-time-error                   ; standard deviation in the time spent by an individual foraging at a patch
  nest-nectar-handling-time                          ; time spent by an individual unloading nectar on reaching the nest
  patch-quality-mean                                 ; mean patch quality
  patch-quality-error                                ; standard deviation of patch quality
  flight-speed
  cost-joules-flight                                 ; energy spent by an individual (in J) while flying
  cost-joules-resting                                ; energy spent by an individual (in J) while resting
  mortality-per-tick                                 ; probability that an indidual will die that day
  joules-per-microl
  joules-per-mol
  energy-penalty-recruit                             ; energy spent by an individual (in J) while recruiting an individual (by dancing)
  ;; MODEL VARIABLES
  day-counter
  run-number
  prob-mod-bool
  intens-mod-bool
  ;; MODEL VARIABLES FOR MONITORING
  daily-trip-returners                               ; number of trips made in a day
  total-trip-returners                               ; number of trips made in a day
  total-scout-returners                              ; number of trips made by scouts in a day
  total-forager-returners                            ; number of trips made by foragers in a day
  nest-energy                                        ; measure of energy in the nest over the experimental period
  daily-nest-energy                                  ; measure of energy in the nest in a day
  nest-energy-scouts
  nest-energy-foragers
  daily-nest-energy-scouts
  daily-nest-energy-foragers
  daily-recruits
  foraging-distances
  daily-prob-dancing-scouts
  daily-prob-dancing-foragers
  my-new-seed                                        ; specifies the seed for the model run
]

; Patch related variables
patches-own [
  patch-type                                         ; specifies the type of patch -  whether it is a foraging patch or not
  patch-quality                                      ; if a patch is a foraging patch, this specifies the quality of the food at the patch
  patch-age                                          ; this specifies the age of all food patches
]


; Setting up all the different states the individuals can be in our model
;; Scouts
breed [ idle-scouts idle-scout ]
breed [ scouts scout ]
breed [ loading-scouts loading-scout ]
breed [ returning-scouts returning-scout ]
breed [ returned-scouts returned-scout ]
breed [ disappointed-returning-scouts disappointed-returning-scout ]
breed [ dancing-scouts dancing-scout ]
;; Foragers
breed [ idle-foragers idle-forager ]
breed [ idle-dancefloor-foragers idle-dancefloor-forager ]
breed [ foragers forager ]
breed [ loading-foragers loading-forager ]
breed [ returning-foragers returning-forager ]
breed [ returned-foragers returned-forager ]
breed [ scouting-foragers scouting-forager ]
breed [ disappointed-returning-foragers disappointed-returning-forager ]
breed [ dancing-foragers dancing-forager ]


turtles-own [
  intensity-modulator              ; the intensity modulator of each individual; random variables drawn from normal distribution
  probability-modulator            ; the probability modulator of each individual; random variables drawn from normal distribution
  dance-intensity                  ; the number of dance turns an individual makes (calculated based on the intensity modulator, concentration of food source, and distance of food source from the home nest)
  id                               ; unique numeric ID of individuals
  dance-timer                      ; specifies the time spent dancing by an individual
  energy                           ; turtles own energy, which they will use in-flight, and when resting, this is basically the amount of nectar-load in joules
  visited-food-patch               ; the patch visited in previous round
  previously-visited-food-patch    ; the food patch visited prior to the current one
  quality-visited-food-patch       ; molarity that a visited patch has
  distance-visited-food-patch      ; distance of the food patch from the nest that a visited patch has
  learnt-food-patch                ; patch information that an individual learns from some other scout or forager
  moved-this-tick                  ; specifies whether an individual moved at the current tick
  flight-timer                     ; time spent flying by an individual
  daily-search-timer               ; time spent searching for food by an individual
  daily-dance-timer                ; time spent dancing by an individual
  daily-idletimer                  ; time spent idle by an individual
  loading-timer                    ; time spent handling food at food patch by an individual
  current-nectar-handling-time     ; time an individual would spend handling nectar (drawn from normal distribution with parameters specified below)
  nectar-load                      ; amount of food taken by an individual
  unloading-timer                  ; food handling time when unloading in nest; this could be probably 0
  flight-length                    ; for levi flight
  levy-mu                          ; mu for levi flight
  daily-trip-counter               ; number of trips made on a day
  daily-energy-counter             ; amount of energy collected on a day
  daily-dance-counter              ; number of trips dances made in a day
  daily-circuit-counter            ; number of trips dance circuits made in a day
  energy-per-trip                  ; daily-energy-counter / daily-trip-counter
  dance-probability                ; number of dances / number of trips
  daily-dance-intensity            ; number of circuits / number of dances
]

to setup
  ; decides whether to use pre-set seed or random seed, decided by user
  __clear-all-and-reset-ticks
  ifelse use-random-seed  [
    random-seed current-random-seed
  ][
    set my-new-seed new-seed
    random-seed my-new-seed
  ]
  set run-number new-seed
  ; Code specifying which experiment we are running (which parameters have variation)
  ifelse probability-modulator-on [
    set prob-mod-bool 1
  ]
  [
    set prob-mod-bool 0
  ]
  ifelse intensity-modulator-on [
    set intens-mod-bool 1
  ]
  [
    set intens-mod-bool 0
  ]
  ;; SET MODEL PARAMS
  ; parameters were obtained from the model built by Schurch and Gruter 2014
  set ticks-per-day 5000
  set patch-yield 50
  set patch-nectar-handling-time-mean 180
  set patch-nectar-handling-time-error 60
  set nest-nectar-handling-time 6
  set patch-quality-mean patch-mean-mol
  set patch-quality-error patch-mean-mol / 5
  set flight-speed  .7
  set cost-joules-resting 0.04861
  set cost-joules-flight cost-joules-resting * 9
  set mortality-per-tick 0.000007
  set joules-per-microl 5.819
  set joules-per-mol 5645000
  set energy-penalty-recruit 325
  ;; RESET COUNTERS
  set day-counter 0
  set daily-trip-returners 0
  set total-trip-returners 0
  set total-scout-returners 0
  set total-forager-returners 0
  set nest-energy 0
  set nest-energy-scouts 0
  set daily-nest-energy-scouts 0
  set nest-energy-foragers 0
  set daily-nest-energy-foragers 0
  set daily-nest-energy 0
  set daily-prob-dancing-scouts [ ]
  set daily-prob-dancing-foragers [ ]
  ;; SETUP PATCHES AND TURTLES
  setup-patches
  setup-turtles
end

; sets up - home patch at centre
;         - food patches that are dispersed randomly on the landscape with density and average patch quality set by the user

to setup-patches
  ask patches [
    set patch-type "blank"
  ]
  ask patches with [ distancexy 0 0 > distance-food ] [
    if random 10000 / 10000 < density-food [
      set patch-type "forage"
      set patch-quality random-normal patch-quality-mean patch-quality-error
      set pcolor scale-color red patch-quality 0 3
      set patch-age -1
      if patch-max-age > 0 [
        set patch-age (one-of n-values (patch-max-age + 1) [?])
      ]
    ]
  ]
  set-current-plot "Patch age"
  set-current-plot-pen "default"
  histogram [ patch-age ] of patches with [ patch-type = "forage" ]
  ask patches with [ pxcor = 0 and pycor = 0 ] [
    set patch-type "nest"         ; the nest, or hive patch
    set pcolor white
  ]
end

; function that outputs a random value from a bounded normal distrubution

to-report random-normal-in-bounds [mean- sd mmin mmax]
  let result random-normal mean- sd
  if result < mmin or result > mmax
    [ report random-normal-in-bounds mean- sd mmin mmax ]
  report result
end

; sets up all the agents in the model

to setup-turtles
  create-idle-dancefloor-foragers initial-recruits
  ask idle-dancefloor-foragers [ set color white ]
  create-idle-scouts initial-scouts
  ask idle-scouts [ set color yellow ]
  ask turtles [
    set id who
    set random-val random-normal-in-bounds 0.255 0.1 0.01 0.5
    ifelse probability-modulator-on [
      set probability-modulator random-val
    ]
    [
      set probability-modulator 0.255
    ]
    ifelse intensity-modulator-on [
      set intensity-modulator random-val
    ]
    [
      set intensity-modulator 0.255
    ]
    set dance-intensity 57 * intensity-modulator
    set dance-timer 0
    set daily-search-timer 0
    set daily-dance-timer 0
    set energy 0
    set flight-length 0
    set levy-mu slider-levy-mu                                 ; 2.4 should be the default (Reynolds et al) - from Schruch and Gruter 2014
    set nectar-load 0
    set daily-trip-counter 0
    set daily-dance-counter 0
    set daily-circuit-counter 0
    set daily-energy-counter 0
    set daily-idletimer 0
    set energy-per-trip 0
  ]

  set-current-plot "Distribution of probability modulator"
  set-current-plot-pen "default"
  histogram [ probability-modulator ] of turtles
  set-current-plot "Distribution of intensity modulator"
  set-current-plot-pen "default"
  histogram [ intensity-modulator ] of turtles

end

; runs the model
to go
  ask turtles [ set moved-this-tick false ]

  ; initial state of all scouts - idle in the home nest
  ; individual scouts leave the nest with a certain exit probability (we used 0.815 (Schurch and Gruter 2014))
  ask idle-scouts with [ moved-this-tick = false ] [
    set energy energy - cost-joules-resting
    set moved-this-tick true
    if ((random 1000)) / 1000 < exit-prob and flight-time [
      set flight-timer 0
      set breed scouts
    ]
  ]

  ; scouts fly out looking for food
  ; if scouts find a food source, the location of the patch is saved - they have "learned" of the food source and they start feeding
  ask scouts with [ moved-this-tick = false ] [
    set moved-this-tick true
    set flight-timer flight-timer + 1
    set daily-search-timer daily-search-timer + 1
    move-levy-flight
    if [ patch-type ] of patch-here = "forage" and patch-discovery-chance > (random 1000 / 1000) [
      set visited-food-patch patch-here
      set quality-visited-food-patch [ patch-quality ] of patch-here
      set distance-visited-food-patch [ distancexy 0 0 ] of patch-here
      set loading-timer 0
      set breed loading-scouts
      set current-nectar-handling-time random-normal patch-nectar-handling-time-mean patch-nectar-handling-time-error
    ]
    if not flight-time [
      set breed disappointed-returning-scouts
    ]
  ]

  ; scouts that have found a food patch start feeding
  ; on loading food, the individual starts to return home
  ask loading-scouts with [ moved-this-tick = false ] [
    set energy energy - cost-joules-resting
    set moved-this-tick true
    set flight-timer flight-timer + 1
    set loading-timer loading-timer + 1
    if loading-timer > current-nectar-handling-time [
      set nectar-load nectar-load + patch-yield
      set breed returning-scouts
    ]
  ]

  ; returning scouts fly home
  ask returning-scouts with [ moved-this-tick = false ] [
    set moved-this-tick true
    set flight-timer flight-timer + 1
    facexy 0 0
    set energy energy - cost-joules-flight
    fd flight-speed
    if [ patch-type ] of patch-here = "nest" [
      set unloading-timer 0
      set dance-timer 0
      set dance-intensity 0
      set breed returned-scouts
    ]
  ]

  ; returned scouts unload food at home
  ; on unloading, individuals decide to dance or not - dance probability depends on the probability modulator, quality of the visited food patch, distance of the visited food patch from the home nest and influx of foragers
  ; individuals that decide to dance become dancing scouts. Individuals that decide not to dance are idle in the nest
  ask returned-scouts with [ moved-this-tick = false ] [
    set energy energy - cost-joules-resting
    set moved-this-tick true
    set unloading-timer unloading-timer + 1
    let taught-patch visited-food-patch
    let quality-taught-patch quality-visited-food-patch
    let distance-taught-patch distance-visited-food-patch
    if unloading-timer > nest-nectar-handling-time [
      let probability-dance-yes dance-response quality-taught-patch distance-taught-patch probability-modulator
      set probability-dance-yes probability-dance-yes * dance-response-influx (count returned-scouts + count returned-foragers)
      set daily-prob-dancing-scouts sentence daily-prob-dancing-scouts probability-dance-yes
      if (probability-dance-yes > (random 1000000) / 1000000) [
        set dance-timer dance-timer + 1
        set daily-dance-timer daily-dance-timer + 1
        set dance-intensity dance-intens quality-taught-patch distance-taught-patch intensity-modulator
        set daily-dance-counter daily-dance-counter + 1
        set daily-circuit-counter daily-circuit-counter + dance-intensity
      ]
      ifelse (dance-intensity = 0) [
        set daily-trip-counter daily-trip-counter + 1
        count-trip
        ifelse flight-time [
          set breed scouts
        ][
        set breed idle-scouts
        ]
      ]
      [
       set breed dancing-scouts
      ]
    ]
  ]

  ; dancing individuals spend 3 * number of dance turns (secs) in this stage - time spent dancing depends on intensity modulator, quality of the visited food patch and distance of the visited food patch from home
  ; every 10 dance turns recruit an individual to the food source with a probablilty set by the user  (default prob is 0.25) (Seeley and Visscher 1988, Schurch and Gruter 2014)
  ask dancing-scouts with [ moved-this-tick = false ][
    if ( dance-timer mod 3 = 0 )[
      let max-num-recruits count idle-dancefloor-foragers-here
      let current-num-recruits 0
      let taught-patch visited-food-patch
      let quality-taught-patch quality-visited-food-patch
      let distance-taught-patch distance-visited-food-patch
      ifelse max-num-recruits < num-recruits-per-dance [
        set current-num-recruits max-num-recruits
      ][
      set current-num-recruits num-recruits-per-dance
      ]
      let recruits n-of current-num-recruits idle-dancefloor-foragers-here
      if ( recruits != nobody ) and flight-time [
        set daily-recruits daily-recruits + count recruits
        ask recruits [
          let proportion-dance-success 0
          set proportion-dance-success prop-dance-success
          if proportion-dance-success > random 1000 / 1000 [
            set moved-this-tick true
            set learnt-food-patch taught-patch
            set flight-timer 0
            set energy energy - energy-penalty-recruit
            set breed foragers
          ]
        ]
      ]
    ]
    ; after dancing, the scout becomes an idle scout in the nest
    if (dance-timer > (dance-intensity / 3))[
      let energy-returned energy + joules-from-nectar nectar-load quality-visited-food-patch
      set daily-energy-counter daily-energy-counter + energy-returned
      set daily-trip-counter daily-trip-counter + 1
      count-trip
      count-scout-trip energy-returned
      set nest-energy nest-energy + energy-returned
      set daily-nest-energy daily-nest-energy + energy-returned
      set energy 0
      set nectar-load 0
      ifelse flight-time [
        set breed scouts
      ][
        set breed idle-scouts
      ]
    ]
    set dance-timer dance-timer + 1
    set daily-dance-timer daily-dance-timer + 1
  ]

  ; an individual who did not find a food patch returns home
  ask disappointed-returning-scouts with [ moved-this-tick = false ] [
    set flight-timer flight-timer + 1
    facexy 0 0
    fd flight-speed
    set energy energy - cost-joules-flight
    if [ patch-type ] of patch-here = "nest" [
      let energy-returned energy + joules-from-nectar nectar-load quality-visited-food-patch
      set nest-energy nest-energy + energy-returned
      set daily-nest-energy daily-nest-energy + energy-returned
      set energy 0
      set nectar-load 0
      set breed idle-scouts
    ]
  ]

  ; initial state of all foragers - idle on the dance floor in the home nest
  ; foragers either independently leave the nest with a very low probability and scout OR are recruited to a food source by an individual who has previously foraged at a food patch
  ask idle-dancefloor-foragers with [ moved-this-tick = false ][
    set energy energy - cost-joules-resting
    set moved-this-tick true
    if flight-time [ set daily-idletimer daily-idletimer + 1 ]
    if ((random 1000000)) / 1000000 < exit-prob-idle-dancefloor-foragers and flight-time [
      set flight-timer 0
      set breed scouting-foragers
    ]
  ]

  ; these are foragers that leave the nest on being recruited to a food source by another individual
  ; these individuals leave the nest with a probability of 0.815 (Schurch and Gruter 2014)
  ask idle-foragers with [ moved-this-tick = false ] [
    set energy energy - cost-joules-resting
    set moved-this-tick true
    if ((random 1000)) / 1000 < exit-prob and flight-time [
      set flight-timer 0
      set breed foragers
    ]
  ]

  ; foragers fly directly to a learned food patch
  ; once they reach the learned food patch, they start loading nectar
  ask foragers with [ moved-this-tick = false ] [
    set moved-this-tick true
    set flight-timer flight-timer + 1
    let xTemp [ pxcor ] of learnt-food-patch
    let yTemp [ pycor ] of learnt-food-patch
    facexy xTemp yTemp
    forward flight-speed
    set daily-search-timer daily-search-timer + 1
    set energy energy - cost-joules-flight
    if patch-here = learnt-food-patch [
      ifelse [ patch-type ] of patch-here = "forage" [
        set previously-visited-food-patch visited-food-patch
        set visited-food-patch patch-here
        set quality-visited-food-patch [ patch-quality ] of patch-here
        set distance-visited-food-patch [ distancexy 0 0 ] of patch-here
        set loading-timer 0
        set breed loading-foragers
        set current-nectar-handling-time random-normal patch-nectar-handling-time-mean patch-nectar-handling-time-error
      ] [
        set breed disappointed-returning-foragers
      ]
    ]
  ]

  ; these are foragers that leave the nest independently and go scouting
  ; similar to scouts, if these foragers  find a food source, the location of the patch is saved - they have "learned" of the food source and they start feeding
  ask scouting-foragers [
    set moved-this-tick true
    set flight-timer flight-timer + 1
    move-levy-flight
    set daily-search-timer daily-search-timer + 1
    if [ patch-type ] of patch-here = "forage" and patch-discovery-chance > (random 1000 / 1000) [
      set previously-visited-food-patch visited-food-patch
      set visited-food-patch patch-here
      set quality-visited-food-patch [ patch-quality ] of patch-here
      set distance-visited-food-patch [ distancexy 0 0 ] of patch-here
      set loading-timer 0
      set breed loading-foragers
      set current-nectar-handling-time random-normal patch-nectar-handling-time-mean patch-nectar-handling-time-error
    ]
    if not flight-time [
      set breed disappointed-returning-foragers
    ]
  ]

  ; foragers, on reaching the food patch start feeding
  ; on loading food, the individual starts to return home
  ask loading-foragers with [ moved-this-tick = false ] [
    set energy energy - cost-joules-resting
    set moved-this-tick true
    set flight-timer flight-timer + 1
    set loading-timer loading-timer + 1
    if loading-timer > current-nectar-handling-time [
      set nectar-load nectar-load + patch-yield
      set breed returning-foragers
    ]
  ]

  ; returning foragers fly home
  ask returning-foragers with [ moved-this-tick = false ] [
    set moved-this-tick true
    set flight-timer flight-timer + 1
    facexy 0 0
    fd flight-speed
    set energy energy - cost-joules-flight
    if [ patch-type ] of patch-here = "nest" [
      set unloading-timer 0
      set dance-timer 0
      set dance-intensity 0
      set breed returned-foragers
    ]
  ]

  ; returned foragers unload food at home
  ; on unloading, individuals decide to dance or not - dance probability depends on the probability modulator, quality of the visited food patch, distance of the visited food patch from the home nest and influx of foragers
  ; individuals that decide to dance become dancing foragers. Individuals thar decide not to dance are idle in the nest
  ask returned-foragers with [ moved-this-tick = false ] [
    set energy energy - cost-joules-resting
    set moved-this-tick true
    set unloading-timer unloading-timer + 1
    let taught-patch visited-food-patch
    let quality-taught-patch quality-visited-food-patch
    let distance-taught-patch distance-visited-food-patch
    if unloading-timer > nest-nectar-handling-time [
      let probability-dance-yes dance-response quality-taught-patch distance-taught-patch probability-modulator ; distance here is in patches, will be in km later
      set probability-dance-yes probability-dance-yes * dance-response-influx (count returned-scouts + count returned-foragers)
      set daily-prob-dancing-foragers sentence daily-prob-dancing-foragers probability-dance-yes
      if (probability-dance-yes > (random 1000000) / 1000000) [
        set dance-timer dance-timer + 1
        set daily-dance-timer daily-dance-timer + 1
        set dance-intensity dance-intens quality-taught-patch distance-taught-patch intensity-modulator
        set daily-dance-counter daily-dance-counter + 1
        set daily-circuit-counter daily-circuit-counter + dance-intensity
      ]
      ifelse (dance-intensity = 0) [
        let energy-returned energy + joules-from-nectar nectar-load quality-visited-food-patch
        set daily-energy-counter daily-energy-counter + energy-returned
        set daily-trip-counter daily-trip-counter + 1                                                   ;;changed on Dec 19
        count-trip
        count-forager-trip energy-returned
        set nest-energy nest-energy + energy-returned
        set daily-nest-energy daily-nest-energy + energy-returned
        set energy 0
        set nectar-load 0
        set learnt-food-patch visited-food-patch
        set breed idle-foragers
      ]
      [
       set breed dancing-foragers
      ]
    ]
  ]

  ; an individual that decides to dance dances for 3 * number of dance turns (secs) - time spent dancing depends on intensity modulator, quality of the visited food patch and distance of the visited food patch from home
  ; every 10 dance turns recruit an individual to the food source with a probablilty set of 0.25 (Schurch and Gruter 2014)
  ask dancing-foragers with [ moved-this-tick = false ][
    if ( dance-timer mod 3 = 0)[
      let taught-patch visited-food-patch
      let quality-taught-patch quality-visited-food-patch
      let distance-taught-patch distance-visited-food-patch
      let max-num-recruits count idle-dancefloor-foragers-here
      let current-num-recruits 0
      ifelse max-num-recruits < num-recruits-per-dance [
        set current-num-recruits max-num-recruits
      ][
      set current-num-recruits num-recruits-per-dance
      ]
      let recruits n-of current-num-recruits idle-dancefloor-foragers-here
      if ( recruits != nobody ) and flight-time [
        set daily-recruits daily-recruits + count recruits
        ask recruits [
          let proportion-dance-success 0
          set proportion-dance-success prop-dance-success
          if proportion-dance-success > random 1000 / 1000  [
            set moved-this-tick true
            set learnt-food-patch taught-patch
            set energy energy - energy-penalty-recruit
            set breed foragers
          ]
        ]
      ]
    ]
    ; after dancing an individual becomes an idle forager in the nest
    if (dance-timer > (dance-intensity / 3))[
      let energy-returned energy + joules-from-nectar nectar-load quality-visited-food-patch
      set daily-energy-counter daily-energy-counter + energy-returned
      set daily-trip-counter daily-trip-counter + 1
      count-trip
      count-forager-trip energy-returned
      set nest-energy nest-energy + energy-returned
      set daily-nest-energy daily-nest-energy + energy-returned
      set energy 0
      set nectar-load 0
      set learnt-food-patch visited-food-patch
      set breed idle-foragers
    ]
    set dance-timer dance-timer + 1
    set daily-dance-timer daily-dance-timer + 1
  ]

  ; a scouting forager who did not find a food patch returns home
  ask disappointed-returning-foragers with [ moved-this-tick = false ] [
    set flight-timer flight-timer + 1
    facexy 0 0
    fd flight-speed
    set energy energy - cost-joules-flight
    if [ patch-type ] of patch-here = "nest" [
      let energy-returned energy + joules-from-nectar nectar-load quality-visited-food-patch
      set nest-energy nest-energy + energy-returned
      set daily-nest-energy daily-nest-energy + energy-returned
      set energy 0
      set nectar-load 0
      set breed idle-dancefloor-foragers
    ]
  ]

  ; updating the energy-per-trip, dance probability and dance intensity for each turtle
  ask turtles [
    turn-wiggle
    ifelse daily-trip-counter > 0 [
        set energy-per-trip daily-energy-counter / daily-trip-counter
      ][
        set energy-per-trip 0
      ]
    ifelse daily-trip-counter > 0 [
        set dance-probability daily-dance-counter / daily-trip-counter
      ][
        set dance-probability 0
      ]
    ifelse daily-dance-counter > 0 [
        set daily-dance-intensity daily-circuit-counter / daily-dance-counter
      ][
        set daily-dance-intensity 0
      ]
  ]

  if ticks mod ticks-per-day = 0 [
    ; reset the daily counters
    set daily-recruits 0
    set daily-trip-returners 0
    set daily-nest-energy 0
    set daily-nest-energy-scouts 0
    set daily-nest-energy-foragers 0
    set daily-prob-dancing-scouts [ ]
    set daily-prob-dancing-foragers [ ]
    set foraging-distances [ ]
    set day-counter day-counter + 1
    ask turtles [
      set daily-energy-counter 0
      set daily-trip-counter 0
      set daily-dance-counter 0
      set daily-circuit-counter 0
      set daily-dance-timer 0
      set daily-search-timer 0
      set daily-idletimer 0
    ]

    ; submodel to decide whether food patches stay food and if non food patches become food sources?
    ask patches with [ patch-type = "forage" and distancexy 0 0 > distance-food ] [
      set patch-age patch-age + 1
      if patch-age > patch-max-age [
        set patch-type "blank"
        set patch-quality 0
        set patch-age 0
        set pcolor black
        ask one-of patches with  [ patch-type = "blank"  and distancexy 0 0 > distance-food ] [
          set patch-type "forage"
          set patch-quality random-normal patch-quality-mean patch-quality-error
          set pcolor scale-color red patch-quality 0 3
        ]
      ]
    ]

    ; foragers that have learnt the location of a food source can also abandon it with probability depending on quality and distance from home
    ask idle-foragers [
      let probability-abandon-current-patch probability-abandoning quality-visited-food-patch distance-visited-food-patch probability-modulator
      if probability-abandon-current-patch > random 1000000 / 1000000 [
        set breed idle-dancefloor-foragers
      ]
    ]
  ]

  ; get the foraging distances of the returned foragers
  let new-foraging-distances [( distancexy [ pxcor ] of visited-food-patch [ pycor ] of visited-food-patch) * 0.1 ] of returned-foragers
  if not empty? new-foraging-distances [
    set foraging-distances sentence new-foraging-distances foraging-distances
  ]

  tick

  do-plotting
end

;; the submodels used in this model are adapted from Schurch and Gruter 2014
;; Levy flight submodel was created by Schurch and Gruter 2014 on following Viswanathan et al. Nature 1999
to move-levy-flight
  set energy energy - cost-joules-flight
  if flight-length <= 0 [
    rt random 360
    set flight-length levy levy-mu
  ]
  ifelse flight-length < flight-speed [
    fd flight-length
    set flight-length 0
  ][
    fd flight-speed
    set flight-length flight-length - flight-speed
  ]
end

to-report levy [ p-mu ]
  let result 0
  ifelse p-mu <= 1 [
    set result random-float 100000000000
  ][
    ifelse p-mu >= 3 [
      set result abs random-normal 5 1;0 1
    ][
      let a random-float 1
      set result exp ( ln (a) * (1 / 1 - p-mu)) ; this might need to be changed according to Reynolds. Mu should be alright now.
    ]
  ]
  report result
end

to turn-wiggle
  right random 40
  left random 40
end

to count-trip
  set daily-trip-returners daily-trip-returners + 1
  set total-trip-returners total-trip-returners + 1
end

to count-scout-trip [ p-joules ]
  set total-scout-returners total-scout-returners + 1
  set nest-energy-scouts nest-energy-scouts + p-joules
  set daily-nest-energy-scouts daily-nest-energy-scouts + p-joules
end

to count-forager-trip [ p-joules ]
  set total-forager-returners total-forager-returners + 1
  set nest-energy-foragers nest-energy-foragers + p-joules
  set daily-nest-energy-foragers daily-nest-energy-foragers + p-joules
end

to-report flight-time
  let result false
  if (ticks mod 5000) < 4001 [
    set result true
  ]
  report result
end

to-report num-scouts
  let result 0
  set result count idle-scouts + count scouts + count loading-scouts + count returning-scouts + count returned-scouts + count disappointed-returning-scouts
  report result
end

; All dance and abandoning thresholds based on data from Bosch and Seeley
; dance probability is calculated as a function of probability modulator and patch reward
to-report dance-response [ pMol pDistance prob-mod ]
  let result 0
  let deval-mol pMol + 1.02 - distance-factor pDistance
  if deval-mol <= 0.00001 [ set deval-mol 0.00001 ]
  set result 0.956937 / (1 + exp ((prob-mod - ln deval-mol) / 0.2624014))
  report result
end

to-report distance-factor [ pDistance ]
  let result 0
  let tempDist pDistance * 100
  set result 0.04915919 - 0.00002851457 * tempDist + 0.00000003174098 * (tempDist * tempDist)
  report result
end

; dance intensity is calculated as a function of intensity modulator and patch reward
to-report dance-intens [ pMol pDistance inten-mod ]
  let result 0
  let deval-mol pMol + 1.02 - distance-factor pDistance
  if deval-mol <= 0.00001 [ set deval-mol 0.00001 ]
  set result 57 * inten-mod * deval-mol
  report floor result
end

; compute the probability of dance depending on the influx of bees
to-report dance-response-influx [ pInflux ]
  let result 0
  ifelse pInflux <= 20 [
    set result 1 - 0.035 * pInflux
  ][
  set result 0.3
  ]
  report result
end

; compute probability of an individual abandoning a food source
to-report probability-abandoning [ pMol pDistance prob-mod ]
  let result 0
  let deval-mol pMol + 1.02 - distance-factor pDistance
  if deval-mol <= 0.00001 [ set deval-mol 0.00001 ]
  set result (1 - (0.956937 / (1 + exp ((prob-mod - ln (deval-mol + 0.6687)) / 0.2624014))))
  report result
end

; provide volume in microlitre and the molarity
to-report joules-from-nectar [ pVolume pMolarity ]
  let reslt 0
  let volume-litre pVolume / 1000000
  let mol-sugar volume-litre * pMolarity
  set reslt mol-sugar * joules-per-mol
  report reslt
end


to-report num-foragers
  let result 0
  set result count idle-dancefloor-foragers + count idle-foragers + count foragers + count loading-foragers + count returning-foragers + count returned-foragers + count scouting-foragers + count disappointed-returning-foragers
  report result
end

;The following functions allow us to get median, mean and standard deviations of the individual scout/forager measurements

to-report get-median-foraging-distance
  let result 0
  if is-list? foraging-distances [ set result median foraging-distances ]
  report result
end

to-report get-mean-scout-yield
  let result 0
  if count idle-scouts > 0 [
    set result mean [ energy-per-trip ] of idle-scouts
  ]
  report result
end

to-report get-mean-forager-yield
  let result 0
  let current-idle-foragers (turtle-set idle-foragers idle-dancefloor-foragers)
  if count current-idle-foragers > 0 [
    set result mean [ energy-per-trip ] of current-idle-foragers
  ]
  report result
end

to-report get-mean-search-timer-for-new
  let result 0
  let current-idle-foragers (turtle-set idle-foragers idle-dancefloor-foragers)
  if count current-idle-foragers > 0 [
    set result mean [ daily-search-timer ] of current-idle-foragers
  ]
  report result
end

to-report get-mean-search-timer-sc-new
  let result 0
  if count idle-scouts > 0 [
    set result mean [ daily-search-timer ] of idle-scouts
  ]
  report result
end

to-report get-mean-dance-timer-for-new
  let result 0
  let current-idle-foragers (turtle-set idle-foragers idle-dancefloor-foragers)
  if count current-idle-foragers > 0 [
    set result mean [ daily-dance-timer ] of current-idle-foragers
  ]
  report result
end

to-report get-mean-dance-timer-sc-new
  let result 0
  if count idle-scouts > 0 [
    set result mean [ daily-dance-timer ] of idle-scouts
  ]
  report result
end

to-report get-mean-idle-timer-for-new
  let result 0
  let current-idle-foragers (turtle-set idle-foragers idle-dancefloor-foragers)
  if count current-idle-foragers > 0 [
    set result mean [ daily-idletimer ] of current-idle-foragers
  ]
  report result
end

to-report get-sum-idle-timer-for-new
  let result 0
  let current-idle-foragers (turtle-set idle-foragers idle-dancefloor-foragers)
  if count current-idle-foragers > 0 [
    set result sum [ daily-idletimer ] of current-idle-foragers
  ]
  report result
end


to-report get-sd-search-timer-for-new
  let result 0
  let current-idle-foragers (turtle-set idle-foragers idle-dancefloor-foragers)
  if count current-idle-foragers > 0 [
    set result standard-deviation [ daily-search-timer ] of current-idle-foragers
  ]
  report result
end

to-report get-sd-search-timer-sc-new
  let result 0
  if count idle-scouts > 0 [
    set result standard-deviation [ daily-search-timer ] of idle-scouts
  ]
  report result
end

to-report get-sd-dance-timer-for-new
  let result 0
  let current-idle-foragers (turtle-set idle-foragers idle-dancefloor-foragers)
  if count current-idle-foragers > 0 [
    set result standard-deviation [ daily-dance-timer ] of current-idle-foragers
  ]
  report result
end

to-report get-sd-dance-timer-sc-new
  let result 0
  if count idle-scouts > 0 [
    set result standard-deviation [ daily-dance-timer ] of idle-scouts
  ]
  report result
end

to-report get-sd-idle-timer-for-new
  let result 0
  let current-idle-foragers (turtle-set idle-foragers idle-dancefloor-foragers)
  if count current-idle-foragers > 0 [
    set result standard-deviation [ daily-idletimer ] of current-idle-foragers
  ]
  report result
end

to-report get-mean-danceprob-for-new
  let result 0
  let current-idle-foragers (turtle-set idle-foragers idle-dancefloor-foragers)
  if count current-idle-foragers > 0 [
    set result mean [ dance-probability ] of current-idle-foragers
  ]
  report result
end

to-report get-mean-danceprob-sc-new
  let result 0
  if count idle-scouts > 0 [
    set result mean [ dance-probability ] of idle-scouts
  ]
  report result
end

to-report get-mean-danceinten-for-new
  let result 0
  let current-idle-foragers (turtle-set idle-foragers idle-dancefloor-foragers)
  if count current-idle-foragers > 0 [
    set result mean [ daily-dance-intensity ] of current-idle-foragers
  ]
  report result
end

to-report get-mean-danceinten-sc-new
  let result 0
  if count idle-scouts > 0 [
    set result mean [ daily-dance-intensity ] of idle-scouts
  ]
  report result
end


to-report get-sd-danceprob-for-new
  let result 0
  let current-idle-foragers (turtle-set idle-foragers idle-dancefloor-foragers)
  if count current-idle-foragers > 0 [
    set result standard-deviation [ dance-probability ] of current-idle-foragers
  ]
  report result
end

to-report get-sd-danceprob-sc-new
  let result 0
  if count idle-scouts > 0 [
    set result standard-deviation [ dance-probability ] of idle-scouts
  ]
  report result
end

to-report get-sd-danceinten-for-new
  let result 0
  let current-idle-foragers (turtle-set idle-foragers idle-dancefloor-foragers)
  if count current-idle-foragers > 0 [
    set result standard-deviation [ daily-dance-intensity ] of current-idle-foragers
  ]
  report result
end

to-report get-sd-danceinten-sc-new
  let result 0
  if count idle-scouts > 0 [
    set result standard-deviation [ daily-dance-intensity ] of idle-scouts
  ]
  report result
end


to-report get-mean-scout-dance-prob
  let result 0
  if not empty? daily-prob-dancing-scouts [
    set result mean daily-prob-dancing-scouts
  ]
  report result
end

to-report get-mean-forager-dance-prob
  let result 0
  if not empty? daily-prob-dancing-foragers [
    set result mean daily-prob-dancing-foragers
  ]
  report result
end

;;__________________________________________________________________________


to do-plotting
  set-current-plot "unloading-agents"
  let num-unloading-agents count returned-scouts + count returned-foragers
  set-current-plot-pen "default"
  plotxy ticks num-unloading-agents

  if ticks mod ticks-per-day = 0 [
    set-current-plot "Daily returned foragers"
    set-current-plot-pen "default"
    plotxy day-counter daily-trip-returners

    set-current-plot "Daily honey gain"
    set-current-plot-pen "default"
    plotxy day-counter daily-nest-energy / 12719360

    set-current-plot "Patch age"
    set-current-plot-pen "default"
    histogram [ patch-age ] of patches with [ patch-type = "forage" ]

    set-current-plot "Daily Energy Per Forager"
    set-current-plot-pen "recruit"
    plotxy ticks get-mean-forager-yield
    set-current-plot-pen "scout"
    plotxy ticks get-mean-scout-yield


    set-current-plot "Probability of Dances"
    set-current-plot-pen "scouts"
    plotxy ticks get-mean-scout-dance-prob
    set-current-plot-pen "foragers"
    plotxy ticks get-mean-forager-dance-prob
  ]

  set-current-plot "Energy brought in foragers / scouts"
  let load-foragers-plot 0
  if total-forager-returners > 0 [
    set load-foragers-plot nest-energy-foragers / total-forager-returners
  ]
  let load-scouts-plot 0
  if total-scout-returners > 0 [
    set load-scouts-plot nest-energy-scouts / total-scout-returners
  ]
  let load-total-plot 0
  if total-forager-returners > 0 and total-scout-returners > 0 [
    set load-total-plot (nest-energy-foragers + nest-energy-scouts) / (total-forager-returners + total-scout-returners); load-foragers-plot + load-scouts-plot
  ]
  set-current-plot-pen "foragers"
  plotxy ticks load-foragers-plot
  set-current-plot-pen "scouts"
  plotxy ticks load-scouts-plot
  set-current-plot-pen "total"
  plotxy ticks load-total-plot

  set-current-plot "Energy (kJ) stored in the hive"
  set-current-plot-pen "default"
  plotxy ticks nest-energy / 1000


  set-current-plot "Foraging distances"
  set-current-plot-pen "default"
  histogram foraging-distances

end
@#$#@#$#@
GRAPHICS-WINDOW
724
50
1136
483
100
100
2.0
1
10
1
1
1
0
0
0
1
-100
100
-100
100
0
0
1
ticks
30.0

SLIDER
47
32
219
65
initial-scouts
initial-scouts
0
500
30
1
1
NIL
HORIZONTAL

SLIDER
11
468
183
501
density-food
density-food
0
0.20
0.1
0.0001
1
NIL
HORIZONTAL

BUTTON
260
11
323
44
setup
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
360
10
423
43
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
438
10
515
43
Go once
go
NIL
1
T
OBSERVER
NIL
G
NIL
NIL
1

SLIDER
43
175
215
208
exit-prob
exit-prob
0
1
0.815
0.001
1
NIL
HORIZONTAL

PLOT
377
59
537
179
unloading-agents
ticks
no. unloading agents
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

SLIDER
11
432
183
465
distance-food
distance-food
1
150
1
1
1
NIL
HORIZONTAL

TEXTBOX
49
14
199
32
Number of agents in the hive
11
0.0
1

TEXTBOX
45
138
247
166
The probability with which idle scouts leave the hive
11
0.0
1

TEXTBOX
20
346
385
449
Parameters regarding the food source:\n- the distance of food from the hive\n- the density of the food (probability that any given patch bears forage)\n- whether food lasts for several days or perishes quickly (1)
11
0.0
1

MONITOR
241
60
355
105
Proportion of scouts
num-scouts / (num-scouts + num-foragers)
2
1
11

MONITOR
242
115
357
160
NIL
daily-trip-returners
17
1
11

SLIDER
11
505
183
538
patch-max-age
patch-max-age
0
51
14
1
1
NIL
HORIZONTAL

PLOT
542
62
702
182
Daily returned foragers
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""
"stores" 1.0 0 -11221820 true "" ""

MONITOR
734
642
894
687
Energy (kJ) stored in the nest
nest-energy / 1000
2
1
11

MONITOR
1149
211
1372
256
Daily accumulation of energy (kJ) in the nest
daily-nest-energy / 1000
2
1
11

MONITOR
1155
274
1373
319
mean energy borught back by scouts
mean [ energy + joules-from-nectar nectar-load quality-visited-food-patch ] of returned-scouts
2
1
11

MONITOR
1150
332
1379
377
mean energy brought back by foragers
mean [ energy + joules-from-nectar nectar-load quality-visited-food-patch ] of returned-foragers
2
1
11

TEXTBOX
52
75
202
93
Number of recruits
11
0.0
1

SLIDER
46
94
218
127
initial-recruits
initial-recruits
0
1080
270
1
1
NIL
HORIZONTAL

MONITOR
1157
387
1238
432
NIL
day-counter
0
1
11

SLIDER
221
572
401
605
num-recruits-per-dance
num-recruits-per-dance
0
10
1
1
1
NIL
HORIZONTAL

SLIDER
222
610
401
643
prop-dance-success
prop-dance-success
0
1
0.25
0.01
1
NIL
HORIZONTAL

PLOT
902
511
1146
631
Energy brought in foragers / scouts
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"foragers" 1.0 0 -955883 true "" ""
"scouts" 1.0 0 -8630108 true "" ""
"total" 1.0 0 -16777216 true "" ""

SLIDER
11
583
184
616
patch-discovery-chance
patch-discovery-chance
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
46
287
285
320
exit-prob-idle-dancefloor-foragers
exit-prob-idle-dancefloor-foragers
0
0.0001
9.0E-5
0.00001
1
NIL
HORIZONTAL

TEXTBOX
44
263
393
283
The probability that idle recruits will leave the hive and scout
11
0.0
1

PLOT
734
511
894
631
Energy (kJ) stored in the hive
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

MONITOR
903
642
1065
687
~ Honey (kg)
nest-energy / 12719360
3
1
11

MONITOR
1246
388
1380
433
NIL
daily-recruits
17
1
11

PLOT
377
189
701
400
Probability of Dances
time
prob
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"scouts" 0.01 0 -8630108 true "" ""
"foragers" 1.0 0 -955883 true "" ""

PLOT
736
692
1145
812
Daily honey gain
NIL
NIL
0.0
10.0
0.0
0.25
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
193
432
373
552
Patch age
NIL
NIL
0.0
28.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

SLIDER
11
544
183
577
patch-mean-mol
patch-mean-mol
0
2.5
1
0.1
1
NIL
HORIZONTAL

PLOT
1172
450
1372
600
Foraging distances
NIL
NIL
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 0.1 1 -16777216 true "" ""

SLIDER
43
217
215
250
slider-levy-mu
slider-levy-mu
0
4
2.4
0.1
1
NIL
HORIZONTAL

PLOT
1168
42
1368
192
Daily Energy Per Forager
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"recruit" 1.0 0 -955883 true "" ""
"scout" 1.0 0 -8630108 true "" ""

INPUTBOX
403
454
558
514
current-random-seed
3770773560223156
1
0
Number

SWITCH
402
416
558
449
use-random-seed
use-random-seed
1
1
-1000

SWITCH
1400
95
1592
128
probability-modulator-on
probability-modulator-on
0
1
-1000

SWITCH
1399
142
1594
175
intensity-modulator-on
intensity-modulator-on
0
1
-1000

TEXTBOX
1406
16
1556
72
These switches control whether the bees have individual specific probabilty and intensity curves or not.
11
0.0
1

BUTTON
525
10
619
43
Go 51 days
repeat 51 * ticks-per-day [ go ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1385
209
1655
359
Distribution of probability modulator
NIL
NIL
0.0
0.5
0.0
20.0
true
false
"" ""
PENS
"default" 0.01 1 -7500403 true "" ""

PLOT
1385
364
1658
514
Distribution of intensity modulator
NIL
NIL
0.0
0.5
0.0
20.0
true
false
"" ""
PENS
"default" 0.01 1 -7500403 true "" ""

@#$#@#$#@
Model for Rajagopal, S., Brockmann, A., and George, E. A. (2021). Environment dependent benefits of individual differences in the recruitment behaviour of honey bees.

The overall purpose of the study was to explore the role of individual variation in the probability and intensity of recruitment behaviour amongst honey bee foragers in the colony’s foraging activity and the benefits provided by this individual variation during the collective foraging process of honey bee colonies. The agent based models (ABMs) used in this study are based on a previously published ABM on honey bee foraging.
(see Schürch, R., & Grüter, C. (2014). Dancing bees improve colony foraging success as long-term benefits outweigh short-term costs. PloS One, 9(8), e104660. https://doi.org/10.1371/journal.pone.0104660)

This model is used to run simulations of Experiment 2 in the current study.

Experiment 2: Individual variation in recruitment behaviour and colony foraging activity
Environmental conditions can affect the benefits of information transfer through the recruitment process in social insects, with the greatest benefit often seen in low food density conditions. In this experiment, we explored how inter-individual variation in the recruitment behaviour further benefits the colony’s foraging activity. We hypothesise that the benefits of inter-individual variation in recruitment behaviour will be dependent on the environmental conditions. Inter-individual variation in the recruitment behaviour was implemented as a function of individual variation in both response probability and intensity, which we obtained from the previous experiment (Experiment 1, see manuscript and NETLOGO code for Experiment 1). We tested the colony’s foraging activity under three different environmental conditions: low, medium, and high food density (dpatch values corresponding to 0.01, 0.05 and 0.1 respectively).

We use the behaviourspace tool to run 4 different versions of the ABM (referred to as model 1 to 4). The versions are as follows:
Model 1 - No inter-individual variation in probability and intensity of recruitment amongst agents
Model 2 - Agents vary in the probability but not in the intensity of recruitment
Model 3 - Agents vary in the intensity but not in the probability of recruitment
Model 4 - Agents vary in both the probability and intensity of recruitment
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
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

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
<experiments>
  <experiment name="Exp2_4Models_3FoodDens_20Runs" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat ticks-per-day [ go ]</go>
    <timeLimit steps="51"/>
    <metric>nest-energy</metric>
    <metric>day-counter</metric>
    <metric>get-median-foraging-distance</metric>
    <metric>get-mean-scout-yield</metric>
    <metric>get-mean-forager-yield</metric>
    <metric>get-mean-scout-dance-prob</metric>
    <metric>get-mean-forager-dance-prob</metric>
    <metric>my-new-seed</metric>
    <metric>get-mean-search-timer-for-new</metric>
    <metric>get-mean-search-timer-sc-new</metric>
    <metric>get-mean-dance-timer-for-new</metric>
    <metric>get-mean-dance-timer-sc-new</metric>
    <metric>get-mean-idle-timer-for-new</metric>
    <metric>get-sum-idle-timer-for-new</metric>
    <metric>get-sd-search-timer-for-new</metric>
    <metric>get-sd-search-timer-sc-new</metric>
    <metric>get-sd-dance-timer-for-new</metric>
    <metric>get-sd-dance-timer-sc-new</metric>
    <metric>get-sd-idle-timer-for-new</metric>
    <metric>get-mean-danceprob-for-new</metric>
    <metric>get-mean-danceprob-sc-new</metric>
    <metric>get-mean-danceinten-for-new</metric>
    <metric>get-mean-danceinten-sc-new</metric>
    <metric>get-sd-danceprob-for-new</metric>
    <metric>get-sd-danceprob-sc-new</metric>
    <metric>get-sd-danceinten-for-new</metric>
    <metric>get-sd-danceinten-sc-new</metric>
    <enumeratedValueSet variable="probability-modulator-on">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="intensity-modulator-on">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-scouts">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="distance-food">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-mean-mol">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prop-dance-success">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-max-age">
      <value value="14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="density-food">
      <value value="0.01"/>
      <value value="0.05"/>
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="slider-levy-mu">
      <value value="2.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exit-prob-idle-dancefloor-foragers">
      <value value="9.0E-5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initial-recruits">
      <value value="270"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="exit-prob">
      <value value="0.815"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="patch-discovery-chance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-recruits-per-dance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-random-seed">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="current-random-seed">
      <value value="3770773560223156"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
