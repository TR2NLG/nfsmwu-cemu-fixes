[NFSMWU_60FPS_EU_v32]
moduleMatches = 0xfc370b5b
.origin = codecave

; ---------------------------------------------------------------------------------------------
; Need for Speed Most Wanted U - 60 FPS (EU, update v32)
;
; The engine decides once per frame how many simulation steps it runs (0x02CA22F8, called from
; 0x020C4660) and advances its timers by the step size stored in the game object (+268) for each
; of them. The step control has modes, set every frame at 0x020C0424 to 0x020C0470: while driving
; mode 0, always exactly one step per frame. With a step of 1/60 s the game therefore turns into
; slow motion as soon as the system cannot hold 60 FPS. In cutscenes and in the crash camera it is
; mode 2 with up to three steps per frame, there the engine keeps up with real time on its own.
;
; This patch presents every vblank and sets the step to 1/60 s. What happens below 60 FPS is
; selected with the "Mode" preset:
;   Variable time step, smoothed  one step per frame whose size follows the average frame time
;                       in small increments (1/60, 1/50 and 1/30 s, all native to the engine)
;   Variable time step, direct    one step per frame, doubled to 1/30 s after a late frame. The
;                       chase camera lags for one frame on every doubled step ("pumping")
;   Frame skip          the engine may run two steps per frame (its own mechanism). A step is
;                       the most expensive part of a frame, so this needs a very fast CPU
;   Fixed time step     nothing, the game runs in slow motion below 60 FPS
; Below 30 FPS the game slows down in every mode, as it does without the patch.
; ---------------------------------------------------------------------------------------------

; ---- statistics, only read by an external measuring tool (marker "TR2FPSv7") ----
statMarker:
.uint 0x54523246
.uint 0x50537637
statUpdates:
.uint 0
statSteps:
.uint 0
statLong:
.uint 0
statMulti:
.uint 0
statElapsed:
.float 0.0
statLost:
.float 0.0
statGained:
.float 0.0
timeDebt:
.float 0.0
lastStep:
.float 0.016666668
statWait:
.float 0.0
cfgMaxSteps:
.float $maxSteps
cfgAdaptive:
.float $adaptive
statUnits:
.uint 0
avgFrame:
.float 0.016666668
statCounterCalls:
.uint 0
paceTier:
.uint 0
workEnv:
.float 0.0
statLate:
.uint 0
statResync:
.uint 0
statLayout:
.uint 0x00007C02
statCutFrames:
.uint 0

; ---- data ----
timerTickSpeed:
.float 62156250

convSub:
.uint 0x43300000
.uint 0x80000000

floatConv:
.uint 0
.uint 0

prevTimeHi:
.uint 0
prevTimeLo:
.uint 0
entryTimeLo:
.uint 0

savedLR:
.uint 0
savedSteps:
.uint 0
savedR4:
.uint 0

step60:
.float 0.016666668
step30:
.float 0.033333335
; largest step this patch ever sets (1/24 s, with a small allowance)
stepMax:
.float 0.042

; smoothed variable time step: step sizes of 5 to 10 units of 1/300 s, and the moving average of
; the frame time (long stalls count as 50 ms at most)
stepTable:
.float 0.016666668
.float 0.02
.float 0.023333333
.float 0.026666667
.float 0.03
.float 0.033333335
avgGain:
.float 0.0625
avgClamp:
.float 0.05
half:
.float 0.5
zero:
.float 0.0

; tenth-of-a-second counter: length of one unit (1/300 s) and the time not yet counted
unitTime:
.float 0.0033333334
unitsFrac:
.float 0.0

; frame pacing: step size, its length in units of 1/600 s and in timer ticks for 60, 40, 30 and
; 24 FPS
tierStep:
.float 0.016666668
.float 0.025
.float 0.033333335
.float 0.041666668
tierUnits:
.uint 10
.uint 15
.uint 20
.uint 25
tierTicks:
.uint 1035937
.uint 1553906
.uint 2071875
.uint 2589843
; a single long frame counts as 1.25 tier lengths at most, so that it does not change the tier
tierClamp:
.float 0.020833334
.float 0.03125
.float 0.041666668
.float 0.052083332
; averaged work time per frame from which the next slower tier is used (60 -> 40, 40 -> 30, 30 -> 24)
thrSlow:
.float 0.0150
.float 0.0240
.float 0.0320
; and below which the next faster tier is used again (40 -> 60, 30 -> 40, 24 -> 30)
thrFast:
.float 0.0125
.float 0.0215
.float 0.0290
; the measured work time is a moving average that follows increases within about 8 frames and
; decreases within about 64 frames
envAttack:
.float 0.125
envRelease:
.float 0.015625
; number of frames a tier is kept at least before a faster one is tried with a borderline load.
; It doubles (up to 480) each time the game has to go slower again within 300 frames of the
; previous change.
upHold:
.uint 120
one:
.float 1.0
earlyFactor:
.float 0.75
sinceSwitch:
.uint 0
paceDueLo:
.uint 0
frameStartLo:
.uint 0
prevStartLo:
.uint 0
nowLo:
.uint 0
; 1 while the game is in a cutscene or in the crash camera (set every frame by the mode hooks)
cutsceneNow:
.uint 0

; direct variable time step: a single step becomes 1/30 s when at least this much real time is owed
debtThreshold:
.float 0.025
; longer stalls are dropped instead of being caught up later
debtMax:
.float 0.1
debtMin:
.float -0.034

; ---- helper: r9 = positive number of timer ticks -> f10 = seconds. Uses r9, r10, f12 ----
_ticksToSeconds:
xoris r9, r9, 0x8000
lis r10, floatConv@ha
stw r9, floatConv@l+0x4(r10)
lis r9, 0x4330
stw r9, floatConv@l+0x0(r10)
lfd f10, floatConv@l+0x0(r10)
lis r10, convSub@ha
lfd f12, convSub@l(r10)
fsub f10, f10, f12
frsp f10, f10
lis r10, timerTickSpeed@ha
lfs f12, timerTickSpeed@l(r10)
fdivs f10, f10, f12
blr

; ---- tenth-of-a-second counter ----
; The routine at 0x023AAE2C adds 12, 10, 6 or 5 to a counter (object +154, units of 1/300 s) when
; the time step is exactly 1/25, 1/30, 1/50 or 1/60 s and nothing for any other value. It is the
; only place in the game that compares the step with fixed values. This replacement adds the
; length of the step for every value and carries the remainder, so that any step size works.
; Replaces "lis r9,0x1002" at 0x023AAE2C. r3 = timer structure (step at +16), r30 = object.
; Continues at 0x023AAEF8 with r10 = new counter value, as the original code does.
_unitsHook:
lfs f0, 16(r3)
lis r12, unitsFrac@ha
lfs f13, unitsFrac@l(r12)
fadds f0, f0, f13
lis r9, unitTime@ha
lfs f13, unitTime@l(r9)
lbz r10, 154(r30)
li r9, 16
_unitsLoop:
fcmpu cr0, f0, f13
blt _unitsDone
fsubs f0, f0, f13
addi r10, r10, 1
addi r9, r9, -1
cmpwi r9, 0
bgt _unitsLoop
_unitsDone:
stfs f0, unitsFrac@l(r12)
stb r10, 154(r30)
lbz r10, 154(r30)
lis r12, statCounterCalls@ha
lwz r9, statCounterCalls@l(r12)
addi r9, r9, 1
stw r9, statCounterCalls@l(r12)
lis r12, 0x023A
ori r12, r12, 0xAEF8
mtlr r12
blr

; ---- before the engine decides the number of steps ----
; Replaces "lbz r5,67(r31)" at 0x020C4684 (r5 = upper limit of steps per frame). r4 is in use.
_entryHook:
mflr r0
lis r12, savedLR@ha
stw r0, savedLR@l(r12)
lis r12, savedR4@ha
stw r4, savedR4@l(r12)
bl import.coreinit.OSGetSystemTime
lis r12, entryTimeLo@ha
stw r4, entryTimeLo@l(r12)
lis r12, savedR4@ha
lwz r4, savedR4@l(r12)
lis r12, savedLR@ha
lwz r0, savedLR@l(r12)
mtlr r0
lbz r5, 67(r31)
blr

; ---- step control mode while driving ----
; Replaces the call "bl 0x02CA22E4" at 0x020C0470, which sets mode 0 (always exactly one step per
; frame) and an upper limit of one step. r3 = frame control structure, r4 = 0, r5 = 0.
; Frame skip: mode 1 (as many steps as real time requires, excess beyond the limit is dropped) and
; the limit from the preset. In cutscenes the game itself uses mode 2 with a limit of three.
_normalModeHook:
li r9, 0
lis r12, cutsceneNow@ha
stw r9, cutsceneNow@l(r12)
li r9, $maxSteps
cmpwi r9, 1
ble _normalModeSet
stb r9, 67(r3)
li r4, 1
_normalModeSet:
li r5, 0
stw r4, 0(r3)
stb r5, 52(r3)
blr

; ---- step control mode in cutscenes and in the crash camera ----
; Replaces the call "bl 0x02CA22E4" at 0x020C0448, which sets mode 2 (as many steps as real time
; requires, catching up completely) after the game has set an upper limit of three steps.
; r3 = frame control structure, r4 = 2, r5 = 0.
; With a step of 1/60 s the game needs two or three steps per frame there, and a step is the most
; expensive part of a frame. "Cutscenes paced" treats these scenes like driving instead: mode 0 with
; one step per frame, and the variable time step or the frame pacing keeps the game speed correct.
; Not used in the frame skip and fixed time step modes, which do not adjust the step themselves.
_cutsceneModeHook:
li r9, 1
lis r12, cutsceneNow@ha
stw r9, cutsceneNow@l(r12)
li r9, $cutscenes
cmpwi r9, 0
beq _cutsceneModeSet
li r9, $adaptive
cmpwi r9, 0
beq _cutsceneModeSet
li r9, 1
stb r9, 67(r3)
li r4, 0
_cutsceneModeSet:
li r5, 0
stw r4, 0(r3)
stb r5, 52(r3)
blr

; ---- right after the engine has decided the number of steps ----
; Replaces "li r6,0" at 0x020C469C. r3 = number of steps, r30 = game object, r31 = frame control
; structure. All other volatile registers are free because a function call has just returned.
_stepHook:
mflr r0
lis r12, savedLR@ha
stw r0, savedLR@l(r12)
lis r12, savedSteps@ha
stw r3, savedSteps@l(r12)

bl import.coreinit.OSGetSystemTime
lis r12, nowLo@ha
stw r4, nowLo@l(r12)

; time the engine spent inside its step control, which is where its frame limiter waits
lis r12, entryTimeLo@ha
lwz r11, entryTimeLo@l(r12)
.uint 0x7D2B2050 ; subf r9, r11, r4
cmpwi r9, 0
ble _waitDone
bl _ticksToSeconds
lis r12, statWait@ha
lfs f9, statWait@l(r12)
fadds f9, f9, f10
stfs f9, statWait@l(r12)
_waitDone:

lis r12, prevTimeHi@ha
lwz r8, prevTimeHi@l(r12)
lis r12, prevTimeLo@ha
lwz r10, prevTimeLo@l(r12)
lis r12, prevTimeHi@ha
stw r3, prevTimeHi@l(r12)
lis r12, prevTimeLo@ha
stw r4, prevTimeLo@l(r12)

.uint 0x7D2A2010 ; subfc r9, r10, r4   (low word of now - previous)
.uint 0x7C081910 ; subfe r0, r8, r3    (high word)

; real time since the previous frame in seconds. If the difference is not a small positive number
; (first frame, very long stall), fall back to 1/60 s.
lis r12, step60@ha
lfs f10, step60@l(r12)
cmpwi r0, 0
bne _haveElapsed
cmpwi r9, 0
ble _haveElapsed
bl _ticksToSeconds

_haveElapsed:
; the work of this frame starts now (the frame pacing mode sets a later time after its wait)
lis r12, nowLo@ha
lwz r11, nowLo@l(r12)
lis r12, frameStartLo@ha
lwz r7, frameStartLo@l(r12)
stw r11, frameStartLo@l(r12)
lis r12, prevStartLo@ha
stw r7, prevStartLo@l(r12)
lis r12, statElapsed@ha
stfs f10, statElapsed@l(r12)
lis r12, statUpdates@ha
lwz r11, statUpdates@l(r12)
addi r11, r11, 1
stw r11, statUpdates@l(r12)
lis r12, cutsceneNow@ha
lwz r11, cutsceneNow@l(r12)
cmpwi r11, 0
beq _noCutFrame
lis r12, statCutFrames@ha
lwz r11, statCutFrames@l(r12)
addi r11, r11, 1
stw r11, statCutFrames@l(r12)
_noCutFrame:

; debt = real time that the game has not simulated yet
lis r12, timeDebt@ha
lfs f11, timeDebt@l(r12)
fadds f11, f11, f10
lis r12, debtMax@ha
lfs f12, debtMax@l(r12)
fcmpu cr0, f11, f12
ble _debtLimited
fsubs f13, f11, f12
lis r12, statLost@ha
lfs f9, statLost@l(r12)
fadds f9, f9, f13
stfs f9, statLost@l(r12)
fmr f11, f12
_debtLimited:

; only touch the step if it is in the range this patch uses (1/60 to 1/24 s)
lfs f13, 268(r30)
lis r12, step60@ha
lfs f12, step60@l(r12)
fcmpu cr0, f13, f12
blt _stepStoreDebt
lis r12, stepMax@ha
lfs f9, stepMax@l(r12)
fcmpu cr0, f13, f9
bgt _stepStoreDebt

_stepKnown:
; r10 = number of steps the engine runs this frame (two if its own catch-up flag is set)
lis r12, savedSteps@ha
lwz r10, savedSteps@l(r12)
lbz r9, 105(r31)
cmpwi r9, 0
beq _stepCounted
li r10, 2
_stepCounted:
lis r12, statSteps@ha
lwz r11, statSteps@l(r12)
add r11, r11, r10
stw r11, statSteps@l(r12)

; default step 1/60 s
fmr f13, f12
cmpwi r10, 1
bne _stepSeveral

; exactly one step. The variable time step modes only act while the engine itself is limited to
; one step per frame
li r9, $adaptive
cmpwi r9, 0
beq _stepSingle
lbz r9, 67(r31)
cmpwi r9, 1
bne _stepSingle
li r9, $adaptive
cmpwi r9, 3
beq _stepPaced
cmpwi r9, 2
bne _stepDirect

; smoothed: the step follows the average frame time in increments of 1/300 s (5 to 10 units,
; 1/60 to 1/30 s) and alternates between the two sizes next to the average. A late frame is
; made up for over several frames instead of with one doubled step.
lis r12, avgClamp@ha
lfs f9, avgClamp@l(r12)
fmr f8, f10
fcmpu cr0, f8, f9
ble _avgInput
fmr f8, f9
_avgInput:
lis r12, avgFrame@ha
lfs f9, avgFrame@l(r12)
fsubs f8, f8, f9
lis r12, avgGain@ha
lfs f7, avgGain@l(r12)
fmuls f8, f8, f7
fadds f9, f9, f8
lis r12, avgFrame@ha
stfs f9, avgFrame@l(r12)
; find the two neighbouring step sizes around the average: r9 -> lower one, r8 = its length in
; units of 1/300 s
lis r9, stepTable@ha
addi r9, r9, stepTable@l
li r8, 5
_levelLoop:
lfs f6, 4(r9)
fcmpu cr0, f9, f6
ble _levelFound
addi r9, r9, 4
addi r8, r8, 1
cmpwi r8, 9
blt _levelLoop
_levelFound:
lfs f5, 0(r9)
lfs f6, 4(r9)
; the longer one if the real time owed is beyond the middle between the two
fadds f7, f5, f6
lis r12, half@ha
lfs f4, half@l(r12)
fmuls f7, f7, f4
fmr f13, f5
fcmpu cr0, f11, f7
blt _levelChosen
fmr f13, f6
addi r8, r8, 1
_levelChosen:
cmpwi r8, 5
ble _stepSingleUnits
lis r12, statLong@ha
lwz r11, statLong@l(r12)
addi r11, r11, 1
stw r11, statLong@l(r12)
b _stepSingleUnits

; frame pacing: every frame lasts exactly 1/60, 1/40, 1/30 or 1/24 s and is simulated with a step of
; the same length. The tier follows the averaged work time per frame, so the step never changes
; from one frame to the next except when the tier changes.
_stepPaced:
; r7 = current tier: 0 (60 FPS), 1 (40 FPS), 2 (30 FPS) or 3 (24 FPS)
lis r12, paceTier@ha
lwz r7, paceTier@l(r12)
; work time of the previous frame = entry into the step control minus the start of that frame
lis r12, entryTimeLo@ha
lwz r11, entryTimeLo@l(r12)
lis r12, prevStartLo@ha
lwz r9, prevStartLo@l(r12)
.uint 0x7D295850 ; subf r9, r9, r11
cmpwi r9, 0
ble _envDone
bl _ticksToSeconds
; a single long frame counts as 1.25 tier lengths at most
add r9, r7, r7
add r9, r9, r9
lis r12, tierClamp@ha
addi r12, r12, tierClamp@l
add r12, r12, r9
lfs f9, 0(r12)
fcmpu cr0, f10, f9
ble _envInput
fmr f10, f9
_envInput:
lis r12, workEnv@ha
lfs f9, workEnv@l(r12)
; follow the work time, faster upwards than downwards
fsubs f8, f10, f9
lis r11, envAttack@ha
lfs f7, envAttack@l(r11)
fcmpu cr0, f10, f9
bgt _envGain
lis r11, envRelease@ha
lfs f7, envRelease@l(r11)
_envGain:
fmuls f8, f8, f7
fadds f9, f9, f8
stfs f9, workEnv@l(r12)
_envDone:
lis r12, workEnv@ha
lfs f9, workEnv@l(r12)

; r6 = frames since the last change of tier
lis r12, sinceSwitch@ha
lwz r6, sinceSwitch@l(r12)
addi r6, r6, 1
stw r6, sinceSwitch@l(r12)

; r8 = new tier. Slower while the work time is above the limit of the tier.
mr r8, r7
_slowLoop:
cmpwi r8, 3
bge _slowDone
add r9, r8, r8
add r9, r9, r9
lis r12, thrSlow@ha
addi r12, r12, thrSlow@l
add r12, r12, r9
lfs f7, 0(r12)
fcmpu cr0, f9, f7
blt _slowDone
addi r8, r8, 1
b _slowLoop
_slowDone:
; faster only if nothing got slower, and never within 30 frames of a change. f6 = factor on the
; limits for going faster: 1 once the tier has been kept long enough, 0.75 before that, so that
; clear headroom is used at once and a borderline load has to wait.
.uint 0x7D274050 ; subf r9, r7, r8
cmpwi r9, 0
bne _tierFilter
cmpwi r6, 30
blt _tierFilter
lis r12, one@ha
lfs f6, one@l(r12)
lis r12, upHold@ha
lwz r9, upHold@l(r12)
.uint 0x7D293050 ; subf r9, r9, r6   (frames since the last change - frames to wait)
cmpwi r9, 0
bge _fastLoop
lis r12, earlyFactor@ha
lfs f6, earlyFactor@l(r12)
_fastLoop:
cmpwi r8, 0
ble _tierFilter
addi r9, r8, -1
add r9, r9, r9
add r9, r9, r9
lis r12, thrFast@ha
addi r12, r12, thrFast@l
add r12, r12, r9
lfs f7, 0(r12)
fmuls f7, f7, f6
fcmpu cr0, f9, f7
bge _tierFilter
addi r8, r8, -1
b _fastLoop
_tierFilter:
; tiers the preset does not offer: 24 FPS needs four tiers, 40 FPS at least three
li r11, $paceTiers
cmpwi r11, 4
bge _tierFiltered
cmpwi r8, 3
bne _tierNo24
li r8, 2
_tierNo24:
cmpwi r11, 3
bge _tierFiltered
cmpwi r8, 1
bne _tierFiltered
li r8, 2
_tierFiltered:
.uint 0x7D274050 ; subf r9, r7, r8
cmpwi r9, 0
beq _tierKept
lis r12, sinceSwitch@ha
li r10, 0
stw r10, sinceSwitch@l(r12)
cmpwi r9, 0
blt _tierKept
; slower: if the previous change was recent, wait twice as long before trying to go faster
lis r12, upHold@ha
lwz r10, upHold@l(r12)
cmpwi r6, 300
bge _holdReset
add r10, r10, r10
cmpwi r10, 480
ble _holdStore
li r10, 480
b _holdStore
_holdReset:
li r10, 120
_holdStore:
stw r10, upHold@l(r12)
_tierKept:
mr r11, r7
lis r12, paceTier@ha
stw r8, paceTier@l(r12)
lis r12, nowLo@ha
lwz r10, nowLo@l(r12)
; a change of tier restarts the schedule. At 60 FPS the game's own limiter does the pacing.
.uint 0x7CEB4050 ; subf r7, r11, r8
cmpwi r7, 0
bne _paceResync
cmpwi r8, 0
beq _paceResync
; r11 = length of the tier in timer ticks, r9 = time at which this frame is due
add r9, r8, r8
add r9, r9, r9
lis r12, tierTicks@ha
addi r12, r12, tierTicks@l
add r12, r12, r9
lwz r11, 0(r12)
lis r12, paceDueLo@ha
lwz r9, paceDueLo@l(r12)
add r9, r9, r11
.uint 0x7CE95050 ; subf r7, r9, r10   (now - due)
cmpwi r7, 0
bge _paceLate
; early: wait, unless the due time is more than one tier away (then the schedule is not valid)
add r6, r7, r11
cmpwi r6, 0
blt _paceLost
lis r12, paceDueLo@ha
stw r9, paceDueLo@l(r12)
_paceLoop:
bl import.coreinit.OSGetSystemTime
lis r12, paceDueLo@ha
lwz r9, paceDueLo@l(r12)
.uint 0x7CE92050 ; subf r7, r9, r4   (now - due)
cmpwi r7, 0
blt _paceLoop
lis r12, frameStartLo@ha
stw r4, frameStartLo@l(r12)
b _paceStep
_paceLate:
; late: no waiting, the next frame is due one tier after this one was. More than one tier
; behind: give up the schedule and start again from now. In cutscenes the limit is eight tiers,
; so that the picture catches up with the sound after a stall.
lis r12, statLate@ha
lwz r6, statLate@l(r12)
addi r6, r6, 1
stw r6, statLate@l(r12)
lis r12, cutsceneNow@ha
lwz r6, cutsceneNow@l(r12)
mr r12, r11
cmpwi r6, 0
beq _paceLimit
add r12, r12, r12
add r12, r12, r12
add r12, r12, r12
_paceLimit:
.uint 0x7CCC3850 ; subf r6, r12, r7   (time behind - limit)
cmpwi r6, 0
bge _paceLost
lis r12, paceDueLo@ha
stw r9, paceDueLo@l(r12)
b _paceStep
_paceLost:
lis r12, statResync@ha
lwz r6, statResync@l(r12)
addi r6, r6, 1
stw r6, statResync@l(r12)
_paceResync:
lis r12, paceDueLo@ha
stw r10, paceDueLo@l(r12)
_paceStep:
; step size and statistics for the tier
lis r12, paceTier@ha
lwz r8, paceTier@l(r12)
add r9, r8, r8
add r9, r9, r9
lis r12, tierStep@ha
addi r12, r12, tierStep@l
add r12, r12, r9
lfs f13, 0(r12)
lis r12, tierUnits@ha
addi r12, r12, tierUnits@l
add r12, r12, r9
lwz r10, 0(r12)
lis r12, statUnits@ha
lwz r11, statUnits@l(r12)
add r11, r11, r10
stw r11, statUnits@l(r12)
cmpwi r8, 0
beq _paceApply
lis r12, statLong@ha
lwz r11, statLong@l(r12)
addi r11, r11, 1
stw r11, statLong@l(r12)
_paceApply:
; this mode keeps no time account
lis r12, zero@ha
lfs f11, zero@l(r12)
b _stepApply

; direct: 1/30 s if enough real time is owed, otherwise 1/60 s
_stepDirect:
lis r12, debtThreshold@ha
lfs f9, debtThreshold@l(r12)
fcmpu cr0, f11, f9
blt _stepSingle
lis r12, step30@ha
lfs f13, step30@l(r12)
li r8, 10
lis r12, statLong@ha
lwz r11, statLong@l(r12)
addi r11, r11, 1
stw r11, statLong@l(r12)
b _stepSingleUnits
_stepSingle:
li r8, 5
_stepSingleUnits:
; r8 = length of the step in units of 1/300 s (the statistics count units of 1/600 s)
lis r12, statUnits@ha
lwz r11, statUnits@l(r12)
add r11, r11, r8
add r11, r11, r8
stw r11, statUnits@l(r12)
fsubs f11, f11, f13
b _stepClamp

_stepSeveral:
lis r12, statMulti@ha
lwz r11, statMulti@l(r12)
addi r11, r11, 1
stw r11, statMulti@l(r12)
cmpwi r10, 0
ble _stepClamp
_stepSeveralLoop:
fsubs f11, f11, f12
lis r12, statUnits@ha
lwz r11, statUnits@l(r12)
addi r11, r11, 10
stw r11, statUnits@l(r12)
addi r10, r10, -1
cmpwi r10, 0
bgt _stepSeveralLoop

_stepClamp:
lis r12, debtMin@ha
lfs f9, debtMin@l(r12)
fcmpu cr0, f11, f9
bge _stepApply
fsubs f8, f9, f11
lis r12, statGained@ha
lfs f7, statGained@l(r12)
fadds f7, f7, f8
stfs f7, statGained@l(r12)
fmr f11, f9
_stepApply:
stfs f13, 268(r30)
lis r12, lastStep@ha
stfs f13, lastStep@l(r12)

_stepStoreDebt:
lis r12, timeDebt@ha
stfs f11, timeDebt@l(r12)

lis r12, savedSteps@ha
lwz r3, savedSteps@l(r12)
lis r12, savedLR@ha
lwz r0, savedLR@l(r12)
mtlr r0
li r6, 0 ; replaced instruction
blr

; ---- patches ----

; GX2SetSwapInterval(2) -> GX2SetSwapInterval(1): present on every vblank
0x03288C5C = li r3, 1

; Step size the game object and its timers are initialised with (0x020C060C). 1/30 s -> 1/60 s
0x10007B04 = .float 0.016666668

; Step control mode while driving (frame skip)
0x020C0470 = bla _normalModeHook

; Step control mode in cutscenes and in the crash camera
0x020C0448 = bla _cutsceneModeHook

; Tenth-of-a-second counter for every step size
0x023AAE2C = bla _unitsHook

; Time stamp for the statistics
0x020C4684 = bla _entryHook

; Step size for this frame
0x020C469C = bla _stepHook

; Note: the 1/30 s constant at 0x10000200 belongs to the video player (frame timing next to the
; H264 decoder calls at 0x02004BAC). It must stay at 1/30, otherwise videos play at double speed.
