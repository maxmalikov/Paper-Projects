breed [ bugs bug ] ;; agents

turtles-own [
  energy
  age
  strategy
  choice
]  ;; agents's attributes

globals [
  conflict-total-value
  conflict-fraction
] ;; used for Hawk-Dove

patches-own [ grass-amount ]  ;; patches have grass

;; this procedures sets up the model
to setup
  clear-all
  ;; setup Hawk-Dove values
  set conflict-total-value (-1 * energy-gain-from-grass) ;; we can change this value. This governs the punishment that the hawks get from fighting
  set conflict-fraction energy-gain-from-grass - (2 * conflict-total-value) ;; conflict-fraction C must be larger than energy-gain-from-grass V
  ask patches [
    ;; give grass to the patches, color it shades of green
    set grass-amount random-float 10.0
    recolor-grass ;; change the world green
  ]

    let choices []         ;; used to store selection of strategies for agents

    if hawk ;; add hawks to the selection
    [
      set choices sentence choices "hawk"
    ]
        if dove ;; add dove to the selection
    [
      set choices sentence choices "dove"
    ]
        if nash ;; add nash to the selection
    [
      set choices sentence choices "nash"
    ]
        if berge ;; add berge to the selection
    [
      set choices sentence choices "berge"
    ]
        if trust ;; add trust to the selection
    [
      set choices sentence choices "trust"
    ]

  create-bugs number-of-bugs [  ;; create the initial bugs
    setxy random-xcor random-ycor

    set shape "bug"


    ;; populate strategies randomly throughout the simulation, with roughly equal proportions.

    ifelse length choices > 0
    [
      set strategy item random length choices choices
    ]
    [
      set strategy "nash"
    ]

    recolor-bug
    set energy random 20  ;; set the initial energy between 0 and 20 (max)
    set age random 100
  ]
  reset-ticks
end

;; make the model run
to go
  if not any? turtles [  ;; now check for any bugs
    stop
  ]
  ask turtles [
    rotate         ;; turn in a random direction
    move           ;; move forward
    check-if-dead  ;; check to see if agent should die
    interact       ;; either propagate or perform social interaction with other agents
    set age age + 1 ;; grow older
  ]
  regrow-grass ;; regrow the grass
  tick
  set-current-plot "Population over Time"
  my-update-plots  ;; plot the population counts
end


to interact
  if ( grass-amount >= energy-gain-from-grass )
  [
    ifelse any? other bugs-here [  ;; if there are others, interact
      let target one-of other bugs-here
      ifelse energy > 20 and [energy] of target > 20 ;; if both agents have enough energy, reproduce
      [
        reproduce self target
      ]
      [ ;; otherwise, randomly select one of the game theory scenarios with a defined probability
        let random-temp random (number-of-PD + number-of-HD + number-of-SH)

        (ifelse random-temp < number-of-PD
        [ prisoners-dilemma self target ]
          random-temp < (number-of-PD + number-of-HD)
        [ hawk-dove self target ]
        [ stag-hunt self target ])
      ]

    ]
  [  eat-grass ]     ;; if no other bugs, simply eat grass
  ]
end

to set-choice-hd  ;; determine the agents choice in an interaction based on its strategy in hawk-dove
  ;; --- Need to update this section when adding strategies ---
  (ifelse strategy = "dove"
    [
      set choice 1
    ]
    strategy = "hawk"
    [
      set choice 0
    ]
     strategy = "trust"
    [
      set choice 1
    ]
    strategy = "nash"
    [
      ifelse random-float 1 < (energy-gain-from-grass / conflict-fraction)
      [
        set choice 0
      ]
      [
        set choice 1
      ]

    ]
        strategy = "berge"
    [
      set choice 1
    ]
  )
end

;; hawk-dove interaction
to hawk-dove [agent-self agent-other]
  ask agent-self [set-choice-hd]
  ask agent-other [set-choice-hd]
     (ifelse
    [choice] of agent-self = 1 ;; increment score routine
      [
        (ifelse
          [choice] of agent-other = 1
          [
          ask agent-self [set energy energy + (energy-gain-from-grass / 2)] ;; adjust value for hawk-dove cooperation
          ask agent-other [set energy energy + (energy-gain-from-grass / 2)]
          set grass-amount grass-amount - energy-gain-from-grass
          recolor-grass
        ]
        [choice] of agent-other = 0
        [
          ask agent-other [set energy energy + energy-gain-from-grass] ;; other agent eats all the grass
          set grass-amount grass-amount - energy-gain-from-grass
          recolor-grass
      ])
    ]
    [choice] of agent-self = 0
    [
      (ifelse
        [choice] of agent-other = 1
        [
          ask agent-self [set energy energy + energy-gain-from-grass] ;; original agent eats all the grass
          set grass-amount grass-amount - energy-gain-from-grass
          recolor-grass
        ]
        [choice] of agent-other = 0
        [
          ask agent-self [set energy energy + conflict-total-value ] ;; both fight and lose energy. no grass is eaten.
          ask agent-other [set energy energy + conflict-total-value ]
        ])
      ]
      )

end

to set-choice-sh  ;; determine the agent's choice in an interaction based on its strategy in Stag Hunt
  ;; --- Need to update this section when adding strategies ---
  (ifelse strategy = "dove"
    [
      set choice 1
    ]
    strategy = "hawk"
    [
      set choice 0
    ]
    strategy = "nash"
    [
      ifelse random-float 1 < (2 / 3) ;; nash
      [
        set choice 1
      ]
      [
        set choice 0
      ]

    ]
        strategy = "trust"
    [
      ifelse random-float 1 < (1 / 6) ;; trust
      [
        set choice 1
      ]
      [
        set choice 0
      ]

    ]
        strategy = "berge"
    [
      set choice 1
    ]
  )
end

;; stag hunt scenario
to stag-hunt [agent-self agent-other]
  ask agent-self [set-choice-sh]
  ask agent-other [set-choice-sh]
     (ifelse
    [choice] of agent-self = 1 ;; increment score routine
      [
        (ifelse
          [choice] of agent-other = 1
          [
          ask agent-self [set energy energy + (energy-gain-from-grass)] ;; together, agents can extract additional value out of grass
          ask agent-other [set energy energy + (energy-gain-from-grass)]
          set grass-amount grass-amount - energy-gain-from-grass
          recolor-grass
        ]
        [choice] of agent-other = 0
        [
          ask agent-other [set energy energy + 0.75 * energy-gain-from-grass] ;; other agent eats all the grass
          set grass-amount grass-amount - 0.75 * energy-gain-from-grass
          recolor-grass
      ])
    ]
    [choice] of agent-self = 0
    [
      (ifelse
        [choice] of agent-other = 1
        [
          ask agent-self [set energy energy + 0.75 * energy-gain-from-grass] ;; original agent eats all the grass
          set grass-amount grass-amount - 0.75 * energy-gain-from-grass
          recolor-grass
        ]
        [choice] of agent-other = 0
        [
          ask agent-self [set energy energy + 0.5 * energy-gain-from-grass ] ;; both leave each other alone. grass is split between them.
          ask agent-other [set energy energy + 0.5 * energy-gain-from-grass ]
          set grass-amount grass-amount - energy-gain-from-grass
          recolor-grass
        ])
      ]
      )
end

to set-choice-pd  ;; determine the agents choice in an interaction based on its strategy in Prisoner's Dillemma
  ;; --- Need to update this section when adding strategies ---
  (ifelse strategy = "dove"
    [
      set choice 1
    ]
    strategy = "hawk"
    [
      set choice 0
    ]
    strategy = "nash"
    [
      set choice 0
    ]
    strategy = "trust"
    [
      set choice 1
    ]
    strategy = "berge"
    [
      set choice 1
    ]
  )
end

;; prisoner's dilemma scenario
to prisoners-dilemma [agent-self agent-other]
  ask agent-self [set-choice-pd]
  ask agent-other [set-choice-pd]
     (ifelse
    [choice] of agent-self = 1 ;; increment score routine
      [
        (ifelse
          [choice] of agent-other = 1
          [
          ask agent-self [set energy energy + (energy-gain-from-grass / 2)] ;; when cooperating, agents split the grass
          ask agent-other [set energy energy + (energy-gain-from-grass / 2)]
          set grass-amount grass-amount - energy-gain-from-grass
          recolor-grass
        ]
        [choice] of agent-other = 0
        [
          ask agent-other [set energy energy + energy-gain-from-grass] ;; other agent eats all the grass and steal from the first agent
          ask agent-self [set energy energy - (energy-gain-from-grass / 2)] ;; lose energy
          set grass-amount grass-amount - energy-gain-from-grass
          recolor-grass
      ])
    ]
    [choice] of agent-self = 0
    [
      (ifelse
        [choice] of agent-other = 1
        [
          ask agent-self [set energy energy + energy-gain-from-grass] ;; first agent eats all the grass and steal from the other
          ask agent-other [set energy energy - (energy-gain-from-grass / 2)] ;; lose energy
          set grass-amount grass-amount - energy-gain-from-grass
          recolor-grass
        ]
        [choice] of agent-other = 0 ;; try to steal from each other and gain no grass
        [
        ])
      ]
      )
end

to reproduce [agent-self agent-other]

  ask agent-self [set energy energy - 10]  ;; reproduction transfers energy
  ask agent-other [set energy energy - 10]  ;; reproduction transfers energy
  hatch-bugs 1 [
    set energy 20
    set age 0
    recolor-bug
  ifelse random 2 = 0 ;; set new agent's strategy to one of their parents'
    [ set strategy [strategy] of agent-self ]
    [ set strategy [strategy] of agent-other ]
  ] ;; to the new agent
end

;; recolor the grass to indicate how much has been eaten
to recolor-grass
;;  set pcolor scale-color green grass 0 20
set pcolor scale-color green (10 - grass-amount) -20 10
end

;; recolor the agent to indicate its strategy
to recolor-bug
    (ifelse
    strategy = "dove"
    [ set color 104 ]
    strategy = "hawk"
    [ set color 24]
    strategy = "nash"
    [ set color 114]
    strategy = "trust"
    [ set color 134]
    strategy = "berge"
    [ set color 54]
    )
end

;; regrow the grass
to regrow-grass
  ask patches [
    set grass-amount grass-amount + grass-regrowth-rate
    if grass-amount > 10.0 [
      set grass-amount 10.0
    ]
    recolor-grass
  ]
end


;; consume grass to replenish energy
to eat-grass
  ;; check to make sure there is grass here
  if ( grass-amount >= energy-gain-from-grass ) [
    ;; increment the agent's energy
    set energy energy + energy-gain-from-grass
    ;; decrement the grass
    set grass-amount grass-amount - energy-gain-from-grass
    recolor-grass
  ]
end

;; check if the agent should die from starvation or old age
to check-if-dead
 if energy < 0 [ die ]
 if age > 100 [ die ]
end

;; update the plots
to my-update-plots
  set-current-plot-pen "doves"
  plot count bugs with [strategy = "dove"]

  set-current-plot-pen "hawks"
  plot count bugs with [strategy = "hawk"]

  set-current-plot-pen "nash"
  plot count bugs with [strategy = "nash"]

  set-current-plot-pen "trust"
  plot count bugs with [strategy = "trust"]

  set-current-plot-pen "berge"
  plot count bugs with [strategy = "berge"]

end

to rotate
  ;; rotate a random amount
  rt random 360
end


to move
  forward random 10 ;; move a random distance up to 10
  set energy energy - step-cost ;; reduce the energy by the cost of movement
end
@#$#@#$#@
GRAPHICS-WINDOW
300
15
818
534
-1
-1
10.0
1
10
1
1
1
0
1
1
1
-25
25
-25
25
1
1
1
ticks
30.0

BUTTON
35
185
101
218
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
215
185
278
218
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
0

PLOT
35
365
280
530
Population over Time
Time
Population
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"nash" 1.0 0 -10141563 true "" ""
"hawks" 1.0 0 -955883 true "" ""
"doves" 1.0 0 -13345367 true "" ""
"trust" 1.0 0 -4757638 true "" ""
"berge" 1.0 0 -8732573 true "" ""

SLIDER
35
100
280
133
grass-regrowth-rate
grass-regrowth-rate
0
3
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
35
140
280
173
energy-gain-from-grass
energy-gain-from-grass
0
5
4.0
0.2
1
NIL
HORIZONTAL

SLIDER
35
20
280
53
number-of-bugs
number-of-bugs
0
2000
1500.0
10
1
NIL
HORIZONTAL

SLIDER
35
60
280
93
step-cost
step-cost
0
5
2.0
0.2
1
NIL
HORIZONTAL

BUTTON
125
185
195
218
go once
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

MONITOR
840
55
945
100
hawks
count bugs with [strategy = \"hawk\"]
17
1
11

MONITOR
840
165
945
210
doves
count bugs with [strategy = \"dove\"]
17
1
11

MONITOR
840
275
945
320
nash
count bugs with [strategy = \"nash\"]
17
1
11

MONITOR
840
380
945
425
trust
count bugs with [strategy = \"trust\"]
17
1
11

MONITOR
840
490
945
535
berge
count bugs with [strategy = \"berge\"]
17
1
11

SLIDER
35
230
280
263
number-of-PD
number-of-PD
0
30
1.0
1
1
NIL
HORIZONTAL

SLIDER
35
275
280
308
number-of-HD
number-of-HD
0
30
6.0
1
1
NIL
HORIZONTAL

SLIDER
35
320
280
353
number-of-SH
number-of-SH
0
30
23.0
1
1
NIL
HORIZONTAL

SWITCH
840
15
943
48
hawk
hawk
1
1
-1000

SWITCH
840
125
943
158
dove
dove
1
1
-1000

SWITCH
840
235
943
268
nash
nash
0
1
-1000

SWITCH
840
450
943
483
berge
berge
0
1
-1000

SWITCH
840
340
943
373
trust
trust
0
1
-1000

TEXTBOX
925
241
940
261
█
16
114.0
1

TEXTBOX
925
23
940
43
█
16
24.0
1

TEXTBOX
925
132
940
152
█
16
104.0
1

TEXTBOX
925
347
945
367
█
16
134.0
1

TEXTBOX
925
456
940
476
█
16
54.0
1

@#$#@#$#@
## WHAT IS IT?

The purpose of this NetLogo model is to simulate the interactions of large scale populations of agents with different strategies and utility functions in a mixed scenario environment with additional realistic aspects. The research question that is being examined is whether non-standard utility functions (not maximizing individual’s payoff) survive and perform well in certain environments, despite performing suboptimally in some of them. 

## HOW IT WORKS

This simulation explores an iterated environment that contains multiple scenarios. Rather than exploring one specific game theory scenario, the agents have to perform well in a variety of scenarios instead. Because the agents are in a mixed-scenario environment, the strategy approaches that are seen in one scenario cannot be easily translated to other scenarios. Instead, the simulation explores different types of utility functions that agents may wish to maximize, along with the corresponding overall strategy, such as using the Nash equilibrium approach to calculate the optimum strategy for each scenario. 
By populating the simulation with agents of different strategies and letting them interact, we can explore which social behaviors perform better in which mix of social interaction types.


## HOW TO USE IT

Enable different strategies/utaility functions by using the corresponding toggle. Make sure to use at least one strategy, as without any strategies enabled, the simulation will default to using "nash" strategy.

The available choices are:

Nash - maximizes its own payoff
Berge - maximizes the opponent's payoff
Trust - maximizes the combined payoff for both players
Hawk and Dove - pure strategies that always choose Hawk or Dove in the Hawk-Dove scenario. Do not use in other scenarios.

The environment can contain specified proportions of scenarios - select different ratios of of Prisoner's Dilemma, Stag Hunt and Hawk-Dove scenarios.

Alter the properties of grass by adjusting the corresponding energy-related values.

Finally, press the GO button to start.


## THINGS TO TRY

Enable Trust and Nash strategies. Choose mainly Stag Hunt, with some Hawk-Dove scenarios. Compare the performance of the strategies to choosing mainly Hawk-Dove and some Stag Hunt instead.



## CREDITS AND REFERENCES

Created by Maxim Malikov

Special thank you to:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.
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

link
true
0
Line -7500403 true 150 0 150 300

link direction
true
0
Line -7500403 true 150 150 30 225
Line -7500403 true 150 150 270 225

moose
false
0
Polygon -7500403 true true 196 228 198 297 180 297 178 244 166 213 136 213 106 213 79 227 73 259 50 257 49 229 38 197 26 168 26 137 46 120 101 122 147 102 181 111 217 121 256 136 294 151 286 169 256 169 241 198 211 188
Polygon -7500403 true true 74 258 87 299 63 297 49 256
Polygon -7500403 true true 25 135 15 186 10 200 23 217 25 188 35 141
Polygon -7500403 true true 270 150 253 100 231 94 213 100 208 135
Polygon -7500403 true true 225 120 204 66 207 29 185 56 178 27 171 59 150 45 165 90
Polygon -7500403 true true 225 120 249 61 241 31 265 56 272 27 280 59 300 45 285 90

moose-face
false
0
Circle -7566196 true true 101 110 95
Circle -7566196 true true 111 170 77
Polygon -7566196 true true 135 243 140 267 144 253 150 272 156 250 158 258 161 241
Circle -16777216 true false 127 222 9
Circle -16777216 true false 157 222 8
Circle -1 true false 118 143 16
Circle -1 true false 159 143 16
Polygon -7566196 true true 106 135 88 135 71 111 79 95 86 110 111 121
Polygon -7566196 true true 205 134 190 135 185 122 209 115 212 99 218 118
Polygon -7566196 true true 118 118 95 98 69 84 23 76 8 35 27 19 27 40 38 47 48 16 55 23 58 41 71 35 75 15 90 19 86 38 100 49 111 76 117 99
Polygon -7566196 true true 167 112 190 96 221 84 263 74 276 30 258 13 258 35 244 38 240 11 230 11 226 35 212 39 200 15 192 18 195 43 169 64 165 92

newwolf
false
0
Polygon -7500403 true true 20 205 26 181 45 154 54 144 70 135 80 135 98 133 132 132 128 129 161 126 178 123 191 123 212 122 225 111 226 122 224 123 234 120 247 113 243 124 258 131 261 135 281 138 276 152 254 155 246 169 235 174 219 182 198 189 194 213 194 228 196 239 204 246 190 248 187 232 184 217 185 198 183 225 190 248 193 255 182 255 174 226 173 200 135 208 117 204 101 205 80 207 77 177 80 216 67 231 52 238 54 249 61 259 65 263 55 265 45 245 54 265 46 264 38 254 34 235 39 225 46 218 46 201 41 209 35 218 24 220 21 211 21 216
Line -16777216 false 275 153 259 150
Polygon -16777216 true false 253 133 245 131 245 133

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
NetLogo 6.2.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Hawk vs Dove" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat 10 [ go ]</go>
    <timeLimit steps="1000"/>
    <metric>ticks</metric>
    <metric>count bugs with [strategy = "hawk"]</metric>
    <metric>count bugs with [strategy = "dove"]</metric>
    <enumeratedValueSet variable="step-cost">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-bugs">
      <value value="1200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="energy-gain-from-grass">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-regrowth-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hawk">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dove">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nash">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="berge">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trust">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Nash vs Dove" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat 10 [ go ]</go>
    <timeLimit steps="1000"/>
    <metric>ticks</metric>
    <metric>count bugs with [strategy = "nash"]</metric>
    <metric>count bugs with [strategy = "dove"]</metric>
    <enumeratedValueSet variable="step-cost">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-bugs">
      <value value="1200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="energy-gain-from-grass">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-regrowth-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hawk">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dove">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nash">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="berge">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trust">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Hawk-Dove ALL" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat 10 [ go ]</go>
    <timeLimit steps="2000"/>
    <metric>ticks</metric>
    <metric>count bugs with [strategy = "nash"]</metric>
    <metric>count bugs with [strategy = "dove"]</metric>
    <metric>count bugs with [strategy = "hawk"]</metric>
    <enumeratedValueSet variable="step-cost">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-bugs">
      <value value="1200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="energy-gain-from-grass">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-regrowth-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hawk">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dove">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nash">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="berge">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trust">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ENV ALL" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>repeat 10 [ go ]</go>
    <timeLimit steps="1000"/>
    <metric>ticks</metric>
    <metric>count bugs with [strategy = "nash"]</metric>
    <metric>count bugs with [strategy = "berge"]</metric>
    <metric>count bugs with [strategy = "trust"]</metric>
    <enumeratedValueSet variable="step-cost">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-bugs">
      <value value="1200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="energy-gain-from-grass">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="grass-regrowth-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="hawk">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dove">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nash">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="berge">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trust">
      <value value="true"/>
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
1
@#$#@#$#@
