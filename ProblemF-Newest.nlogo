;     WM, CM, EM, EB, WB, AG
; 21 30 26 23 0 0
; jenn- 22 33 24 21 0 0
; sunw- 15 8 14 21 32 10
; orig-
;;set world size=200x128, patch size=2, worldwrap=false
globals [
  totalHealth
  water-patches
  ;end-patches
  routeRates ;;route rates in order of WM, CM, EM, EB, WB, AG
  mortalityRates ;;rates of dying/missing along the route
  score ;;for GA
  totalRefugees
  radius
  generation
  tournament-size
]

directed-link-breed [paths path]
breed [refugee]
breed [port]
breed [country]
breed [individuals individual]
refugee-own [time location route countriesVisited]
patches-own [safety] ;;dependent on capacity, resources, and rate of admission
country-own [quota visits]
individuals-own [chromosome fitness]

;;number of points of entry? Rate of entry (border patrol?) //second iteration?

to setup
  clear-all
  import-pcolors "SyriaMapUncolored.png"
  setup-patches
  setup-ports
  setup-countries
  set-default-shape refugee "circle"
  set radius 3
  set mortalityRates [0.0133 0.0171 0.0155 0.0125 0.0021 0.0002]
  plot-pen-up
  ;;setup-refugees
  if GA[set generation 0
    set tournament-size pool-size / 2 + 1
    setup-ga]
  reset-ticks
end

to setup-ga
  create-individuals pool-size [set chromosome randomRate]
  ;set the fitness for each individual
  calculate-population-fitnesses
  plot-pen-down
  set-current-plot-pen "pen-1"
  let best-individual min-one-of individuals [fitness]
  plotxy generation ([fitness] of best-individual)
  set-current-plot-pen "pen-2"
  plotxy generation (sum ([fitness] of individuals) / (count individuals))
  plot-pen-up
end

to go
  ifelse GA[
    create-next-generation
    ;ask individuals [show chromosome]
    ask individuals
    [
      let minRate 15
      if item 0 chromosome < minRate [set chromosome (replace-item 0 chromosome minRate)]
      ]
    calculate-population-fitnesses
    set generation (generation + 1)
    let best-individual min-one-of individuals [fitness]
    print [fitness] of best-individual
    print [chromosome] of best-individual
    plot-pen-down
    set-current-plot-pen "pen-1"
    plotxy generation ([fitness] of best-individual)
    set-current-plot-pen "pen-2"
    plotxy generation (sum ([fitness] of individuals) / (count individuals))
    plot-pen-up
  ]
  [
    let n 10
    let average 0
    let testChromosome (read-from-string test-rate);[5 33 39 61 58];[8 23 15 15 14]
    repeat n [set average (average + time-iteration testChromosome)]
    set average average / n
    print average
  ]
end

to calculate-population-fitnesses
  ;set the fitness for each individual
  let n 1
  foreach sort individuals [
    let average 0
    repeat n [set average (average + time-iteration [chromosome] of ?)]
    set average average / n
    ask ? [set fitness average]
  ]
end

to-report randomRate
  ; set 5 of the rates, the 6th is 100 - sum
  ;set routeRates [12 6 59 2 20]
  let r []
  set r lput (random 95) r
  repeat 4 [set r lput (random (100 - sum r)) r]
  ;set routeRates lput (100 - sum rates) routeRates
  ;;set routeRates [12 6 59 2 20]
  ;WM, CM, EM, EB, WB, AG
  report r
end

to-report binary-to-integer [b]
  ; input list of sentenced binary digits representing the 5 rates in x/128 format
  ; output list of 5 rates in x/100 format
  let x []
  let j 0
  repeat 5 [
    set x lput (integer (sublist b j (j + 7))) x
    set j (j + 7)
  ]
  ; x is now a list of x/128 integers
  ; convert to x/100
  set b []
  set j 0
  while [j < length x] [set b lput (get12_10 (item j x)) b set j (j + 1)]
  report b
end

to-report integer-to-binary [i]
  ;convert rates to x/128 first
  let x []
  let j 0
  while [j < length i] [set x lput get10_12 (item j i) x set j (j + 1)]
  ; convert to binary
  set i []
  set j 0
  while [j < length x] [set i (sentence i (binary (item j x))) set j (j + 1)]
  ;i now has the x/128 rates in binary
  report i
end

to-report integer [n]
  ;input list of binary digits
  let x 0
  let j 0
  while [j < length n] [set x (x + (item j n) * (2 ^ (6 - j))) set j (j + 1)]
  report x
end

to-report binary [n]
  ;number in base 10
  let x []
  let quotient n
  repeat 7 [set x lput (quotient mod 2) x set quotient floor (quotient / 2)]
  set x reverse x
  report x
end

to-report get10_12 [n]
  report floor (n * 1.28)
end

to-report get12_10 [n]
  report ceiling (n / 1.28)
end

to-report crossover [rates1 rates2]
  ;input: list of rates in x/100, output: 2 lists of rates in x/100
  let r1_2 integer-to-binary rates1
  let r2_2 integer-to-binary rates2
  let split-point 1 + random (length r1_2 - 1)
  report list (binary-to-integer sentence (sublist r1_2 0 split-point) (sublist r2_2 split-point length r2_2))
              (binary-to-integer sentence (sublist r2_2 0 split-point) (sublist r1_2 split-point length r1_2))
end

to create-next-generation
  let old-generation (turtle-set individuals)
    repeat pool-size / 2 [
    ;tournament selection
    let parent1 min-one-of (n-of tournament-size old-generation) [fitness]
    let parent2 min-one-of (n-of tournament-size old-generation) [fitness]
    ;crossover parents with chance of .7
    let child-chromosomes (list ([chromosome] of parent1) ([chromosome] of parent2))
    ;crossover rate of 1
    if random-float 1 < .85
    [set child-chromosomes crossover ([chromosome] of parent1) ([chromosome] of parent2)]
    ask parent1 [
      hatch 1 [set chromosome item 0 child-chromosomes]
      hatch 1 [set chromosome item 1 child-chromosomes]
    ]
  ]
  ask old-generation [ die ]
  ask individuals [ mutate ]
end

to mutate
  let binaryList integer-to-binary chromosome
  ;integers x/100
  ;mutation may or may not be valid
  let mutatedList (map [ifelse-value (random-float 1 < mutation-rate) [random 2] [?]] binaryList)
  set mutatedList binary-to-integer mutatedList
  let alteredList []
  foreach mutatedList [set alteredList lput floor (? * 100 / (sum mutatedList + (100 - sum chromosome))) alteredList]
  set chromosome alteredList
end

to-report time-iteration [r]
  set routeRates r
  reset-ticks
  set totalRefugees 0
  ask country [set visits 0]
  while [count refugee != 0 or (count refugee = 0 and totalRefugees + refugee-number < projected-population)]
  [;show (sort-by < [visits] of country) show (sort-on [visits] country)
   ;some bullshit
   ;dynamic methods
    if remainder ticks 10 = 0 and totalRefugees + refugee-number < projected-population [setup-refugees] ;;for every 10 ticks, spawn new refugees
    ;ask turtle 16 [show quota show visits]
    move
    tick
  ]
  ;;print routeRates
  report ticks
end


to setup-ports
  set-default-shape port "x"
  create-port 1[setxy 98 -89 set size 10] ;;israel/egypt (CM or WM or AG) 0
  create-port 1[setxy -11 -98 set size 10] ;;libya (CM or WM) 1
  create-port 1[setxy -39 8 set size 10] ;;italy (CM) ENTRY 2
  create-port 1[setxy -154 -62 set size 10] ;;morocco (WM) 3
  create-port 1[setxy -154 -48 set size 10] ;;spain (WM) ENTRY 4
  create-port 1[setxy 44 -56 set size 10] ;;greece (AG) 5
  create-port 1[setxy 26 -46 set size 10] ;;greece mainland (AG) ENTRY 6
  create-port 1[setxy 112 -43 set size 10] ;;turkey/syria (EM or WB) 7
  create-port 1[setxy 65 -11 set size 10] ;;turkey (EM or WB) 8
  create-port 1[setxy 36 -2 set size 10] ;;greece/turkey (EM) ENTRY 9
  ;create-port 1[setxy 49 -3 set size 10] ;;bulgaria/turkey (WB) 10
  create-port 1[setxy 14 32 set size 10] ;;hungary/romania (WB) ENTRY 10
  create-port 1[setxy 145 -7 set size 10] ;;hungary/georgia (EB) 11
  create-port 1[setxy 127 46 set size 10] ;;russia/ukraine (EB) 12
  create-port 1[setxy 53 52 set size 10] ;;ukraine (EB) 13
  create-port 1[setxy 22 47 set size 10] ;;hungary/ukraine (EB) ENTRY 14
  ask port[set color green]

  ;CM-italy
  ask turtle 0[create-path-to turtle 1]
  ask turtle 1[create-path-to turtle 2]

  ;WM-spain
  ask turtle 1[create-path-to turtle 3]
  ask turtle 3[create-path-to turtle 4]

  ;AG-greece mainland
  ask turtle 0[create-path-to turtle 5]
  ask turtle 5[create-path-to turtle 6]

  ;EM-greece/turkey
  ask turtle 7[create-path-to turtle 8]
  ask turtle 8[create-path-to turtle 9]

  ;WB-hungary/romania
  ask turtle 8[create-path-to turtle 10]

  ;EB-hungary/ukraine
  ask turtle 11[create-path-to turtle 12]
  ask turtle 12[create-path-to turtle 13]
  ask turtle 13[create-path-to turtle 14]
end

to setup-countries
  set-default-shape country "flag"
  ; pref = quota / (distance * # of people)
  create-country 1[setxy -39 8 set size 10 set quota 0.139 set label "Italy"] ;;italy
  create-country 1[setxy -140 -18 set size 10 set quota 0.109 set label "Spain"] ;;spain
  create-country 1[setxy -103 31 set size 10 set quota 0.166 set label "France"] ;;france
  create-country 1[setxy -70 35 set size 10 set quota 0.036 set label "Switzerland"] ;;switzerland
  create-country 1[setxy -26 41 set size 10 set quota 0.031 set label "Austria"] ;;austria
  create-country 1[setxy -55 60 set size 10 set quota 0.216 set label "Germany"]
  create-country 1[setxy 20 -26 set size 10 set quota 0.023 set label "Greece"]
  create-country 1[setxy 36 0 set size 10 set quota 0.015 set label "Bulgaria"]
  create-country 1[setxy -2 73 set size 10 set quota 0.067 set label "Poland"]
  create-country 1[setxy 2 35 set size 10 set quota 0.022 set label "Hungary"]
  create-country 1[setxy -27 121 set size 10 set quota 0.034 set label "Sweden"]
  create-country 1[setxy -90 67 set size 10 set quota 0.034 set label "Belgium"]
  create-country 1[setxy -83 80 set size 10 set quota 0.051 set label "Netherlands"]
  create-country 1[setxy -61 95 set size 10 set quota 0.024 set label "Denmark"]
  create-country 1[setxy -68 124 set size 10 set quota 0.031 set label "Norway"]
  ask country [set color red set visits 0 set label-color orange set label "" set quota (quota * (projected-population + 10))]
end

to setup-patches
  ask patches [if pcolor = 89.3 or pcolor = 89.2 or pcolor = 99.5 or pcolor = 99.1 or pcolor = 108.6 [set pcolor blue]]
  set water-patches patches with [pcolor = blue] ;;identify all water patches

end

to setup-refugees
  create-refugee refugee-number [
      set size 5
      set color black
      ;decide which route the refugee will take, and then spawn at the beginning of the route
      ;WM, CM, EM, EB, WB, AB
      let n (1 + random (100))
      ifelse n < item 0 routeRates [set location turtle 0 set route "WM"]
      [set n (n - item 0 routeRates)
        ifelse n < item 1 routeRates [set location turtle 0 set route "CM"]
        [set n (n - item 1 routeRates)
          ifelse n < item 2 routeRates [set location turtle 7 set route "EM"]
          [set n (n - item 2 routeRates)
            ifelse n < item 3 routeRates [set location turtle 11 set route "EB"]
            [set n (n - item 3 routeRates)
              ifelse n < item 4 routeRates [set location turtle 7 set route "WB"]
              [set location turtle 0 set route "AG"]]]]]
      ;;chance of dying, different n
      set n random-float 1
      if route = "WM" [if n < item 0 mortalityRates [die]]
      if route = "CM" [if n < item 1 mortalityRates [die]]
      if route = "EM" [if n < item 2 mortalityRates [die]]
      if route = "EB" [if n < item 3 mortalityRates [die]]
      if route = "WB" [if n < item 4 mortalityRates [die]]
      if route = "AG" [if n < item 5 mortalityRates [die]]
      set time -1
      ;set xy to beginning of route
      move-to location]
  set totalRefugees (totalRefugees + refugee-number)
end

to-report calcPref
  let totalNum (count refugee in-radius radius)
  if totalNum = 0 [set totalNum 1]
  report (quota - visits - totalNum) / ((distance myself) * totalNum)
end

to-report bestOtherCountry [visited]
  let bestPref 0
  let best nobody
  ask country [
    let pref calcPref
    ;___________________________________________________________________________
    if (((self = turtle 16 or self = turtle 17) and [location] of myself = turtle 21)) [set pref 0]
    if (contains visited self) = false and pref > bestPref [
      set bestPref pref
      set best self]
  ]
  report best
end

to-report contains [l i]
  foreach l [if ? = i [report true]]
  report false
end

to move
  ask country [set label (count refugee in-radius radius)]
  ask refugee[
    set label route
      if (distance location <= radius) [
          ifelse route = ""
          [
            ;wait for x amount of time
            ifelse (time - ticks) < 0
            ;just arrived to location
            [set time (1 + ticks + random (count refugee in-radius radius))]
            [if (time - ticks) = 0
              ;ready to be accepted/rejected
              [ask location [ifelse visits < quota [set visits (visits + 1) ask myself [die]]
                ;rejected, go find somewhere else
                [ask myself [set location (bestOtherCountry countriesVisited)
                  set countriesVisited lput location countriesVisited]]]
              ]
            ]]
            ;on route
          [;set new target location to next port
              let neighb [out-link-neighbors] of location
              ifelse count neighb > 1
              [ifelse location = turtle 0
                [ifelse route = "AG" [set location turtle 5][set location turtle 1]]
                [ifelse location = turtle 1
                  ;;either WM or CM
                  [ifelse route = "WM" [set location turtle 3][set location turtle 2]]
                  ;;either EM or WB
                  [ifelse route = "EM" [set location turtle 9][set location turtle 10]]]
              ]
              ;;only one port
              [set location one-of neighb]
              ;reached end of last port
              if location = nobody [set route ""
              set location min-one-of country [distance myself]
              set countriesVisited (list location)]
            ]
            face location
          ]
          ifelse pcolor = blue [forward 5]
          [forward 1]
        ]
end
@#$#@#$#@
GRAPHICS-WINDOW
205
17
1017
562
200
128
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
-200
200
-128
128
0
0
1
ticks
30.0

BUTTON
115
36
178
69
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
33
85
188
145
projected-population
3000
1
0
Number

INPUTBOX
31
233
184
293
refugee-number
41
1
0
Number

PLOT
1
295
201
445
Genetic Algorithm
generation
fitness
0.0
20.0
1000.0
1250.0
true
false
"" ""
PENS
"pen-1" 1.0 0 -2674135 true "" ""
"pen-2" 1.0 0 -13345367 true "" ""

SLIDER
22
151
194
184
pool-size
pool-size
2
30
10
2
1
NIL
HORIZONTAL

MONITOR
4
449
61
494
Best rate
[chromosome] of min-one-of individuals [fitness]
3
1
11

SLIDER
19
192
191
225
mutation-rate
mutation-rate
0
1
0.032
.001
1
NIL
HORIZONTAL

MONITOR
7
498
90
543
Best fitness
[fitness] of min-one-of individuals [fitness]
0
1
11

BUTTON
35
37
101
70
NIL
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

SWITCH
96
511
199
544
GA
GA
0
1
-1000

INPUTBOX
70
449
197
509
test-rate
[21 30 26 23 0]
1
0
String

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
NetLogo 5.2.1
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
