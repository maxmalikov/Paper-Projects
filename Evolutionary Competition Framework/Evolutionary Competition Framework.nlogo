patches-own [
  strategy         ;; strategy of the patch
  choice           ;; voting choice of the patch each interaction. 0 = defect, 1 = cooperate
  score            ;; score resulting from interaction of neighboring patches
  color-class      ;; used to keep track of group membership
  id               ;; patch ID
  hitlist          ;; array of IDs of patches with which to defect next turn
  goodlist         ;; array of IDs of patches with which to cooperate next turn
]

globals [
  id-sequence      ;; used to generate unique IDs when patches are born
  coopavg          ;; used to store a value for BehaviorSpace reporter
  defectavg        ;; used to store a value for BehaviorSpace reporter
  randomavg        ;; used to store a value for BehaviorSpace reporter
  tftavg           ;; used to store a value for BehaviorSpace reporter
  pavlovavg        ;; used to store a value for BehaviorSpace reporter
]

to setup          ;; initial setup of agents

  set id-sequence 1
  clear-all
  ask patches [


    let choices []         ;; used to store selection of strategies

    ;; --- Need to update this section when adding strategies ---
    ;; If a switch is set to on, it will report true. Then we can
    ;; concatenate that strategy to the selection of strategies.

    if Cooperate_Strategy ;; Always cooperate
    [
      set choices sentence choices "coop"
    ]
    if Defect_Strategy ;; Always defect
    [
      set choices sentence choices "defect"
    ]
    if Random_Strategy ;; Cooperate and Defect with 50/50 probability
    [
      set choices sentence choices "random"
    ]
    if Tit-for-tat_Strategy ;; Repeat the previous action of the opponent
    [
      set choices sentence choices "tft"
    ]
    if Pavlov_Strategy  ;; Stay with previous choice if opponent cooperated, Shift choice if opponent defected
    [
      set choices sentence choices "pavlov"
    ]
    if IN-C-OUT-D_Strategy ;; In-group is cooperate, out-group is defect
    [
      set choices sentence choices "cd"
    ]
    if IN-C-OUT-R_Strategy;; In-group is cooperate, out-group is random
    [
      set choices sentence choices "cr"
    ]
    if IN-R-OUT-D_Strategy ;; In-group is random, out-group is defect
    [
      set choices sentence choices "rd"
    ]
    if CD_Pretender_Strategy ;; Pretend to be CD strategy. Only used for testing purposes.
    [
      set choices sentence choices "fakecd"
    ]
    ;; ----------------------------------------------------------

    ;; randomly choose one of the strategies in the list.
    if length choices > 0
    [
      setup-patch item random length choices choices
    ]
    establish-color



  ]
  reset-ticks

end

to setup-patch [value]      ;; Individual patch setup


  set id id-sequence ;; generate ID from a unique ID sequence
  set id-sequence id-sequence + 1 ;; increment sequence
  set hitlist []
  set goodlist []
  ;; --- Need to update this section when adding strategies ---
  (ifelse value = "coop"
    [
      set strategy value
    ]
    value = "defect"
    [
      set strategy value
    ]
    value = "tft"
    [
      set strategy value
    ]
    value = "random"
    [
      set strategy value
    ]
    value = "pavlov"
    [
      set strategy value
    ]
    value = "cd"
    [
      set strategy value
    ]
    value = "cr"
    [
      set strategy value
    ]
    value = "rd"
    [
      set strategy value
    ]
    value = "fakecd"
    [
      set strategy value
    ]
  )
  ;; ----------------------------------------------------------
end

to go ;; changed to interact and select strategy at the same time to keep it asynchronous. -MM

  ;; This section stores some of the reporters in global variables, so that they can be used in behavior space output.
  ifelse count patches with [strategy = "coop"] > 0
  [set coopavg (sum [score] of patches with [strategy = "coop"] / count patches with [strategy = "coop"] )]
  [set coopavg 0]
  ifelse count patches with [strategy = "defect"] > 0
  [set defectavg (sum [score] of patches with [strategy = "defect"] / count patches with [strategy = "defect"] )]
  [set defectavg 0]
  ifelse count patches with [strategy = "random"] > 0
  [set randomavg (sum [score] of patches with [strategy = "random"] / count patches with [strategy = "random"] )]
  [set randomavg 0]
  ifelse count patches with [strategy = "tft"] > 0
  [set tftavg (sum [score] of patches with [strategy = "tft"] / count patches with [strategy = "tft"] )]
  [set tftavg 0]
  ifelse count patches with [strategy = "pavlov"] > 0
  [set pavlovavg (sum [score] of patches with [strategy = "pavlov"] / count patches with [strategy = "pavlov"] )]
  [set pavlovavg 0]
  ask patches [
    let opponents []
    (ifelse locality = "Only Local"
      [
        set opponents neighbors
      ]
      locality = "Half Local Half Random"
      [
        ;; reworked to explicitly call out random patches, not the entire agent-set
        set opponents (patch-set neighbors patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101) ;; adding "other" to filter yourself resulted in 3x performance hit
        ;;        set opponents (patch-set n-of 4 neighbors patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101) ;; adding "other" to filter yourself resulted in 3x performance hit
      ]
      locality = "Only Random"
      [
        ;; set opponents n-of 8 patches  ;; adding "other" to filter yourself resulted in 3x performance hit
        ;; reworked to explicitly call out random patches, not the entire agent-set
        set opponents (patch-set patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101 patch-at random 101 random 101)
      ]
    )
    interact opponents         ;; to play with a neighboring patch
    select-strategy opponents  ;; adopt the strategy of the neighbor (who had the highest score)
  ]
  tick

end

to interact [group]  ;; patch procedure used to interact with neighbors
  set score 0        ;; reset score
    ask group [
      set-choice myself               ;; set the neighbors choice based on my ID
      ask myself [set-choice myself]  ;; set my choice based on the neighbor's ID
      (ifelse
      choice = 1 ;; increment score routine
      [
        (ifelse
          [choice] of myself = 1
          [
            ask myself [set score score + 1]
          ]
          [choice] of myself = 0
          [
            ask myself [set score score + (defection-award)]
        ])
      ]
      choice = 0
      [
        if [choice] of myself = 0
        [
           ask myself [set score score + 0.33]
        ]
      ]
      )

    ;; --- Need to update this section when adding strategies ---
      if strategy = "tft" or strategy = "pavlov"
      [
        update-hitlist myself
      ]
      ask myself [
        if strategy = "tft" or strategy = "pavlov"
        [
          update-hitlist myself
        ]
      ]
    ]

     ;; ----------------------------------------------------------
end

to set-choice [agent]  ;; determine the patch choice in an interaction based on its strategy
  ;; --- Need to update this section when adding strategies ---
  (ifelse strategy = "tft"
    [
      ifelse member? [id] of agent hitlist
      [
        set choice 0
      ]
      [
        set choice 1
      ]
    ]
    strategy = "coop"
    [
      set choice 1
    ]
    strategy = "defect"
    [
      set choice 0
    ]
    strategy = "random"
    [
      set choice random 2
    ]
    strategy = "pavlov"
    [
      (ifelse
        member? [id] of agent hitlist
        [
          set choice 0
        ]
        member? [id] of agent goodlist
        [
          set choice 1
        ]
        [
          set choice random 2
        ]
      )
  ]
    strategy = "cd" ;; in-group is cooperate, out-group is defect
    [
      ifelse color-class = [color-class] of agent
      [
        set choice 1
      ]
      [
        set choice 0
      ]

    ]
    strategy = "cr" ;; in-group is cooperate, out-group is random
    [
      ifelse color-class = [color-class] of agent
      [
        set choice 1
      ]
      [
        set choice random 2
      ]

    ]
    strategy = "rd" ;; in-group is random, out-group is defect
    [
      ifelse color-class = [color-class] of agent
      [
        set choice random 2
      ]
      [
        set choice 0
      ]

    ]
    strategy = "fakecd" ;; pretend to be a member of CD, but actually randomly select coop/defect
    [
      ifelse color-class = [color-class] of agent
      [
        ;; set choice 0 ;; can be tweaked to random?
        set choice random 2 ;; can be tweaked to random?
      ]
      [
        set choice 0 ;; defect against agents outside of the group of CD/FakeCD
      ]

    ]
  )

  ;; ----------------------------------------------------------

end

to update-hitlist [agent]  ;; used by TFT and Pavlov strategies to update their memories
  ;; --- Need to update this section when adding strategies ---
  (ifelse
    strategy = "tft"
    [
      (ifelse
        [choice] of agent = 0
        [
          if not member? [id] of agent hitlist
          [
            ifelse length hitlist < 50 ;; using Dunbar number as the cutoff for maximum list size. Can be set to other numbers.
            [
              set hitlist lput [id] of agent hitlist
            ]
            [
              set hitlist remove-item 0 hitlist
              set hitlist lput [id] of agent hitlist
            ]
          ]
        ]
        [choice] of agent = 1
        [
          if member? [id] of agent hitlist
          [
            set hitlist remove [id] of agent hitlist
          ]
      ])
    ]
    strategy = "pavlov"
    [
      (ifelse
        [choice] of agent = 0
        [
          (ifelse
            choice = 1
            [
              if member? [id] of agent goodlist
              [
                set goodlist remove [id] of agent goodlist
              ]
              if not member? [id] of agent hitlist
              [
                ifelse length hitlist < 50 ;; may use Dunbar number as the cutoff for maximum list size. Can be set to other numbers.
                [
                  set hitlist lput [id] of agent hitlist
                ]
                [
                  set hitlist remove-item 0 hitlist
                  set hitlist lput [id] of agent hitlist
                ]
              ]
            ]
            choice = 0
            [
              if member? [id] of agent hitlist
              [
                set hitlist remove [id] of agent hitlist
              ]
              if not member? [id] of agent goodlist
              [
                ifelse length goodlist < 50 ;; may use Dunbar number as the cutoff for maximum list size. Can be set to other numbers.
                [
                  set goodlist lput [id] of agent goodlist
                ]
                [
                  set goodlist remove-item 0 goodlist
                  set goodlist lput [id] of agent goodlist
                ]
              ]
          ])
        ]
        [choice] of agent = 1
        [
          (ifelse
            choice = 1
            [
              if not member? [id] of agent goodlist
              [
                ifelse length goodlist < 50 ;; may use Dunbar number as the cutoff for maximum list size. Can be set to other numbers.
                [
                  set goodlist lput [id] of agent goodlist
                ]
                [
                  set goodlist remove-item 0 goodlist
                  set goodlist lput [id] of agent goodlist
                ]
              ]
            ]
            choice = 0
            [
              if not member? [id] of agent hitlist
              [
                ifelse length hitlist < 50 ;; may use Dunbar number as the cutoff for maximum list size. Can be set to other numbers.
                [
                  set hitlist lput [id] of agent hitlist
                ]
                [
                  set hitlist remove-item 0 hitlist
                  set hitlist lput [id] of agent hitlist
                ]
              ]
            ]
          )
        ]
      )
  ])
  ;; ----------------------------------------------------------
end

to select-strategy [group] ;; compare patch score to its neighbors and if it's lowest, switch to best scoring neighbor strategy
  if score < [score] of min-one-of group [score] ;; if my score is lowest among alive neighbors, then die
  [
    let tempagent max-one-of group [score]
    setup-patch [strategy] of tempagent
    ;; inherit the memory of the successful agent
    if [strategy] of tempagent = "tft"
    [
      set hitlist [hitlist] of tempagent
    ]
    if [strategy] of tempagent = "pavlov"
    [
      set goodlist [goodlist] of tempagent
      set hitlist [hitlist] of tempagent
    ]
    interact group   ;; interact to get new score/choice values for interacting with neighbors.
  ]
  ;; need to talk about this code further - should the score be divided by number of alive agents? (multiplied by a number to avoid division?)
  if score = [score] of min-one-of group [score] and score < [score] of max-one-of group [score]
  [
    if random 2 = 1;; pick either 1 or 0, then check against it. May need to divide by number of minimum agents.
    [
      let tempagent max-one-of group [score]
      setup-patch [strategy] of tempagent
      ;; inherit the memory of the successful agent
      if [strategy] of tempagent = "tft"
      [
        set hitlist [hitlist] of tempagent
      ]
      if [strategy] of tempagent = "pavlov"
      [
        set goodlist [goodlist] of tempagent
        set hitlist [hitlist] of tempagent
      ]
      interact group   ;; interact to get new score/choice values for interacting with neighbors.
    ]
  ]

  establish-color
end


to establish-color  ;; this procedure establishes the visual colors and the color-class variable of patches.
   ;; --- Need to update this section when adding strategies ---
  (ifelse
    strategy = "defect" [
      set pcolor [255 158 187]
      set color-class 0
  ]
    strategy = "coop" [
      set pcolor [137 200 255]
            set color-class 1
  ]
    strategy = "tft" [
      set pcolor [158 255 212]
            set color-class 2
  ]
        strategy = "random" [
      set pcolor [190 190 190]
            set color-class 3
  ]
   strategy = "pavlov" [
      set pcolor [ 172 136 238]
            set color-class 4
    ]
  strategy = "cd" [
      set pcolor [ 80 24 122 ]
            set color-class 5
    ]
    strategy = "cr" [
      set pcolor [ 16 66 164 ]
            set color-class 6
    ]
            strategy = "rd" [
      set pcolor [ 141 12 42 ]
            set color-class 7
    ]
        strategy = "fakecd" [
      set pcolor [  0 0 0 ] ;; display color will be black
            set color-class 5 ;; set color class to that of CD
    ]
  )

   ;; ----------------------------------------------------------
end
@#$#@#$#@
GRAPHICS-WINDOW
429
25
841
438
-1
-1
4.0
1
10
1
1
1
0
1
1
1
-50
50
-50
50
1
1
1
ticks
8.0

BUTTON
25
25
106
58
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

BUTTON
120
25
197
58
NIL
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

SLIDER
25
572
843
605
defection-award
defection-award
0
3
1.1
0.01
1
x
HORIZONTAL

BUTTON
215
26
297
59
One step
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

PLOT
875
25
1387
295
Population over time (%)
Time
Population
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"COOP" 1.0 0 -8020277 true "" "plotxy ticks (count patches with [strategy = \"coop\"] / count patches) * 100\n"
"DEF" 1.0 0 -2064490 true "" "plotxy ticks (count patches with [strategy = \"defect\"] / count patches) * 100"
"TFT" 1.0 0 -5509967 true "" "plotxy ticks (count patches with [strategy = \"tft\"] / count patches) * 100"
"RANDOM" 1.0 0 -4539718 true "" "plotxy ticks (count patches with [strategy = \"random\"] / count patches) * 100"
"PAVLOV" 1.0 0 -5204280 true "" "plotxy ticks (count patches with [strategy = \"pavlov\"] / count patches) * 100"
"IN-C-OUT-D" 1.0 0 -11783835 true "" "plotxy ticks (count patches with [strategy = \"cd\"] / count patches) * 100"
"IN-C-OUT-R" 1.0 0 -14730904 true "" "plotxy ticks (count patches with [strategy = \"cr\"] / count patches) * 100"
"FAKE_CD" 1.0 0 -16777216 true "" "plotxy ticks (count patches with [strategy = \"fakecd\"] / count patches) * 100"
"IN-R-OUT-D" 1.0 0 -8053223 true "" "plotxy ticks (count patches with [strategy = \"rd\"] / count patches) * 100"

MONITOR
1043
304
1101
349
rand (%)
(count patches with [strategy = \"random\"] / count patches) * 100
2
1
11

MONITOR
992
304
1042
349
tft (%)
(count patches with [strategy = \"tft\"] / count patches) * 100
2
1
11

MONITOR
934
304
991
349
coop (%)
(count patches with [strategy = \"coop\"] / count patches) * 100
2
1
11

MONITOR
876
304
933
349
def (%)
(count patches with [strategy = \"defect\"] / count patches) * 100
2
1
11

SWITCH
25
122
195
155
Cooperate_Strategy
Cooperate_Strategy
0
1
-1000

SWITCH
27
187
194
220
Defect_Strategy
Defect_Strategy
0
1
-1000

SWITCH
221
122
390
155
Random_Strategy
Random_Strategy
0
1
-1000

SWITCH
220
187
391
220
Tit-For-Tat_Strategy
Tit-For-Tat_Strategy
0
1
-1000

SWITCH
29
248
193
281
Pavlov_Strategy
Pavlov_Strategy
0
1
-1000

MONITOR
1102
304
1167
349
pavlov (%)
(count patches with [strategy = \"pavlov\"] / count patches) * 100
2
1
11

PLOT
874
363
1388
603
Average score over time
Time
Average score
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"COOP" 1.0 0 -8020277 true "" "plotxy ticks coopavg"
"DEF" 1.0 0 -1664597 true "" "ifelse count patches with [strategy = \"defect\"] > 0\n[plotxy ticks (sum [score] of patches with [strategy = \"defect\"] / count patches with [strategy = \"defect\"] )]\n[plotxy ticks 0]"
"TFT" 1.0 0 -5509967 true "" "ifelse count patches with [strategy = \"tft\"] > 0\n[plotxy ticks (sum [score] of patches with [strategy = \"tft\"] / count patches with [strategy = \"tft\"])]\n[plotxy ticks 0]"
"RANDOM" 1.0 0 -4539718 true "" "ifelse count patches with [strategy = \"random\"] > 0\n[plotxy ticks (sum [score] of patches with [strategy = \"random\"] / count patches with [strategy = \"random\"])]\n[plotxy ticks 0]"
"PAVLOV" 1.0 0 -6917194 true "" "ifelse count patches with [strategy = \"pavlov\"] > 0\n[plotxy ticks (sum [score] of patches with [strategy = \"pavlov\"] / count patches with [strategy = \"pavlov\"])]\n[plotxy ticks 0]"
"IN-C-OUT-D" 1.0 0 -11783835 true "" "ifelse count patches with [strategy = \"cd\"] > 0\n[plotxy ticks (sum [score] of patches with [strategy = \"cd\"] / count patches with [strategy = \"cd\"])]\n[plotxy ticks 0]"
"IN-C-OUT-R" 1.0 0 -14730904 true "" "ifelse count patches with [strategy = \"cr\"] > 0\n[plotxy ticks (sum [score] of patches with [strategy = \"cr\"] / count patches with [strategy = \"cr\"])]\n[plotxy ticks 0]"
"FAKE_CD" 1.0 0 -16777216 true "" "ifelse count patches with [strategy = \"fakecd\"] > 0\n[plotxy ticks (sum [score] of patches with [strategy = \"fakecd\"] / count patches with [strategy = \"fakecd\"])]\n[plotxy ticks 0]"
"IN-R-OUT-D" 1.0 0 -8053223 true "" "ifelse count patches with [strategy = \"rd\"] > 0\n[plotxy ticks (sum [score] of patches with [strategy = \"rd\"] / count patches with [strategy = \"rd\"])]\n[plotxy ticks 0]"

SWITCH
28
342
206
375
IN-C-OUT-D_Strategy
IN-C-OUT-D_Strategy
0
1
-1000

TEXTBOX
32
83
182
103
Individual Strategies
16
0.0
1

TEXTBOX
33
301
183
321
Group Strategies
16
0.0
1

SWITCH
223
341
401
374
IN-C-OUT-R_Strategy
IN-C-OUT-R_Strategy
1
1
-1000

SWITCH
221
402
402
435
CD_Pretender_Strategy
CD_Pretender_Strategy
1
1
-1000

SWITCH
26
402
204
435
IN-R-OUT-D_Strategy
IN-R-OUT-D_Strategy
1
1
-1000

TEXTBOX
186
348
202
368
█
16
113.0
1

TEXTBOX
175
254
190
274
█
16
117.0
1

TEXTBOX
175
193
191
213
█
16
136.0
1

TEXTBOX
174
129
189
149
█
16
107.0
1

TEXTBOX
372
127
387
147
█
16
8.0
1

TEXTBOX
373
193
388
213
█
16
68.0
1

TEXTBOX
382
347
397
367
█
16
93.0
1

TEXTBOX
186
409
201
429
█
16
13.0
1

TEXTBOX
384
409
399
429
█
16
0.0
1

CHOOSER
23
497
198
542
locality
locality
"Only Local" "Half Local Half Random" "Only Random"
1

TEXTBOX
34
457
184
477
Parameter Setup
16
0.0
1

MONITOR
1169
304
1242
349
I-C-O-D (%)
(count patches with [strategy = \"cd\"] / count patches) * 100
2
1
11

MONITOR
1244
304
1316
349
I-C-O-R (%)
(count patches with [strategy = \"cr\"] / count patches) * 100
2
1
11

MONITOR
1317
304
1388
349
I-R-O-D (%)
(count patches with [strategy = \"rd\"] / count patches) * 100
2
1
11

@#$#@#$#@
## WHAT IS IT?

This model simulated spatial evolutionary Prisoner's Dilemma interaction between agents, utilizing different individual and group strategies. 

The payoff matrix used is as follows:

```text
                             Payoff Matrix
                             -------------
                                OPPONENT
                     Cooperate            Defect
                    -----------------------------
       Cooperate |(1, 1)            (0, alpha)
  YOU            |
       Defect    |(alpha, 0)        (0.33, 0.33)

        alpha is controlled by the Defection-Award slider and should generally be greater then 1 and less than 2.
	(x, y) = x: your score, y: your partner's score
        Note: higher the score (amount of the benefit), the better.

```

## AUTHORS
Based on the PD Basic Evolutionary model by Uri Wilenski.
Created by Maxim Malikov and Polina Prokof'yeva
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
NetLogo 6.2.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Individual HLHR" repetitions="50" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>(count patches with [strategy = "coop"] / count patches) * 100</metric>
    <metric>(count patches with [strategy = "defect"] / count patches) * 100</metric>
    <metric>(count patches with [strategy = "random"] / count patches) * 100</metric>
    <metric>(count patches with [strategy = "tft"] / count patches) * 100</metric>
    <metric>(count patches with [strategy = "pavlov"] / count patches) * 100</metric>
    <enumeratedValueSet variable="Defect_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="IN-R-OUT-D_Strategy">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="locality">
      <value value="&quot;Half Local Half Random&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="IN-C-OUT-D_Strategy">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tit-For-Tat_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defection-award">
      <value value="1.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="IN-C-OUT-R_Strategy">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Cooperate_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Pavlov_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CD_Pretender_Strategy">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Random_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Individual only" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>(count patches with [strategy = "coop"] / count patches) * 100</metric>
    <metric>(count patches with [strategy = "defect"] / count patches) * 100</metric>
    <metric>(count patches with [strategy = "random"] / count patches) * 100</metric>
    <metric>(count patches with [strategy = "tft"] / count patches) * 100</metric>
    <metric>(count patches with [strategy = "pavlov"] / count patches) * 100</metric>
    <enumeratedValueSet variable="Defect_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="IN-R-OUT-D_Strategy">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="locality">
      <value value="&quot;Only Local&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="IN-C-OUT-D_Strategy">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tit-For-Tat_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defection-award">
      <value value="1.1"/>
      <value value="1.5"/>
      <value value="1.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="IN-C-OUT-R_Strategy">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Cooperate_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Pavlov_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CD_Pretender_Strategy">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Random_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Avg Individual" repetitions="50" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>coopavg</metric>
    <metric>defectavg</metric>
    <metric>randomavg</metric>
    <metric>tftavg</metric>
    <metric>pavlovavg</metric>
    <enumeratedValueSet variable="Defect_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="IN-R-OUT-D_Strategy">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="locality">
      <value value="&quot;Only Local&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="IN-C-OUT-D_Strategy">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Tit-For-Tat_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="defection-award">
      <value value="1.1"/>
      <value value="1.5"/>
      <value value="1.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="IN-C-OUT-R_Strategy">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Cooperate_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Pavlov_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Random_Strategy">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CD_Pretender_Strategy">
      <value value="false"/>
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
