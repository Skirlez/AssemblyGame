PUBLIC asmMain
PUBLIC renderer
PUBLIC window
PUBLIC scaleX
PUBLIC scaleY
.386
.model flat, c
.stack 4096
option casemap: none

; C++ functions from AssemblyGame.cpp
extern getTime: PROC
extern createSDLRect: PROC
extern deleteSDLRect: PROC
extern distanceBetweenPoints: PROC

; std functions
extern srand: PROC
extern rand: PROC

; SDL functions
extern SDL_Init: PROC
extern SDL_RenderPresent: PROC
extern SDL_SetRenderDrawColor: PROC
extern SDL_RenderDrawLine: PROC
extern SDL_RenderDrawRect: PROC
extern SDL_RenderFillRect: PROC
extern SDL_RenderDrawPoint: PROC
extern SDL_RenderClear: PROC
extern SDL_RenderCopy: PROC
extern SDL_CreateWindow: PROC
extern SDL_CreateRenderer: PROC
extern SDL_PollEvent: PROC
extern SDL_GetMouseState: PROC
extern SDL_SetWindowMinimumSize: PROC
extern SDL_SetWindowFullscreen: PROC
extern SDL_GetWindowSizeInPixels: PROC
extern SDL_RenderSetScale: PROC
extern SDL_DestroyRenderer: PROC
extern SDL_DestroyWindow: PROC
extern SDL_Quit: PROC

; SDL_image functions
extern IMG_LoadTexture: PROC
extern SDL_DestroyTexture: PROC
extern IMG_Quit: PROC

; SDL_Mixer functions
extern Mix_OpenAudio: PROC
extern Mix_LoadMUS: PROC
extern Mix_LoadWAV: PROC
extern Mix_PlayChannel: PROC
extern Mix_Playing: PROC
extern Mix_FreeChunk: PROC
extern Mix_PlayMusic: PROC
extern Mix_HaltMusic: PROC
extern Mix_FreeMusic: PROC
extern Mix_CloseAudio: PROC
extern Mix_Quit: PROC
; game constants
SLIDER_SPEED = 2 ; the amount of pixels the slider moves every frame (0 - very sad slider)
COOL_COLORS = 0 ; whether to generate two colors every round (0 - no, 1 - yes please)
STREAKS_AMOUNT = 10 ; the number of streaks to have on screen (0 - disable)
CIRCLE_AMOUNT = 3; the amount of circles to create per round (0 - disable)

; SDL constant stuff
SDL_INIT_EVERYTHING = 62001
SDL_WINDOWPOS_CENTERED = 805240832
SDL_WINDOW_RESIZABLE = 32
SDL_KEYDOWN = 768
SDL_QUIT = 256
SDL_MOUSEBUTTONDOWN = 1025
SDL_MOUSEBUTTONUP = 1026
SDLK_F11 = 1073741892
SDLK_r = 114
SDL_WINDOW_FULLSCREEN_DESKTOP = 4097
MIX_DEFAULT_FORMAT = 32784

.data
    gaming db 1 ; the game runs while this is 1
    fullscreen db 0

    executions dword 0
    startTime dword 0

    w dword 0
    h dword 0
    full_w dword 1280
    full_h dword 720

    scaleX dword 0
    scaleY dword 0

    circles_x dword CIRCLE_AMOUNT dup (0)
    circles_y dword CIRCLE_AMOUNT dup (0)
    circles_clicked dword CIRCLE_AMOUNT dup (0)

    bonusNode db 1 ; bonus node enabled
    bonusNodeState db 0

    slider db 1 ; slider enabled
    sliderPos dw 0
    sliderDrawPos dw 0
    sliderDragged db 0

    levers db 1 ; levers enabled
    levers_state db 3 dup (0)
    levers_light db 3 dup (0)


    mousePressed db 0
    mouseReleased db 0

    streaks_x dw STREAKS_AMOUNT dup (2000)
    streaks_y dw STREAKS_AMOUNT dup (0)
    streaks_delay db 5


    mouseX dword 0 ; need to be dword since SDL_GetMouseState expects them to be
    mouseY dword 0
    prevMouseX dw 0
    prevMouseY dw 0

    timer dword 700
    fullTimer word 6100

    fullTimerColors db 3 dup (255)

    ; contains colors that the game might randomly switch to (except for the first which is reserved for beginning and ending)
    ; goodColorIndex determines which one the game will pick using setColorToPalette
    ; each 6 bytes represent two rgb colors that are complimentary
    goodColors db 255, 255, 255, 0, 0, 0,
    53, 78, 135, 205, 176, 122,
    97, 205, 129, 159, 49, 128,
    255, 138, 28, 0, 138, 173,
    40, 204, 125, 57, 55, 235,
    64, 148, 0, 103, 72, 105

    goodColorIndex db 0

    window dword 0
    renderer dword 0
    gameName db "AssemblyGame", 0

    ; music definitions
    gameMusicStartPath db ".\\Assets\\Sounds\\musicstart.wav", 0
    gameMusicPath db ".\\Assets\\Sounds\\music.wav", 0
    winMusicPath db ".\\Assets\\Sounds\\win.wav", 0
    gameOverMusicPath db ".\\Assets\\Sounds\\gameover.wav", 0
    
    gameMusicStart dword ?
    gameMusic dword ?
    winMusic dword ?
    gameOverMusic dword ?
    MUSIC_COUNT = 4

    ; sound definitions
    bonusTouchPath db ".\\Assets\\Sounds\\touchbonus.wav", 0
    circleClickPath db ".\\Assets\\Sounds\\circleclick.wav", 0
    sliderDragPath db ".\\Assets\\Sounds\\sliderdrag.wav", 0
    leverFlickPath db ".\\Assets\\Sounds\\leverflick.wav", 0
    bonusTouchSound dword ?
    circleClickSound dword ?
    sliderDragSound dword ?
    leverFlickSound dword ?
    SOUND_COUNT = 4

    loseImagePath byte ".\\Assets\\Images\\lose.png", 0
    winImagePath db ".\\Assets\\Images\\win.png", 0
    instructionsImagePath db ".\\Assets\\Images\\instructions.png", 0
    sliderHappyPath db ".\\Assets\\Images\\sliderhappy.png", 0
    sliderWinPath db ".\\Assets\\Images\\sliderwin.png", 0
    sliderSadPath db ".\\Assets\\Images\\slidersad.png", 0
    leverUpPath db ".\\Assets\\Images\\leverup.png", 0
    leverDownPath db ".\\Assets\\Images\\leverdown.png", 0

    ; image definitions
    loseImage dword ?
    winImage dword ?
    instructionsImage dword ?
    sliderHappyImage dword ?
    sliderWinImage dword ?
    sliderSadImage dword ?
    leverUpImage dword ?
    leverDownImage dword ?
    IMAGE_COUNT = 8

    numberPath db ".\\Assets\\Images\\*.png", 0
    numberAddresses dword 10 dup (0)
    
    event db 56 dup (?) ; SDL_Event type

    tempVar dword 0 ; i use this for float operations, since you need to load the value from memory, for some reason...
    
    gameState dw 0
    ; states: 0 - pre init, 1 - round 0 (just music), 2 - the game, 3 - win screen, 4 - lose screen

    score dword 0
    round db 0
.code
asmMain PROC 
    ; initialize SDL
    push SDL_INIT_EVERYTHING
    call SDL_Init
    add esp, 4

    ; create the window
    push SDL_WINDOW_RESIZABLE
    push 720
    push 1280
    push SDL_WINDOWPOS_CENTERED
    push SDL_WINDOWPOS_CENTERED
    push OFFSET gameName
    call SDL_CreateWindow
    add esp, 24

    mov window, eax

    ; set minimum size to 1280x720
    push 720
    push 1280
    push window
    call SDL_SetWindowMinimumSize
    add esp, 12

    ; create the renderer
    push 0
    push -1
    push window
    call SDL_CreateRenderer
    add esp, 12

    mov renderer, eax

    ; initialize the audio mixer
    push 1024
    push 2
    push MIX_DEFAULT_FORMAT
    push 44100
    call Mix_OpenAudio
    add esp, 16


    mov esi, 0
    loadNumbersLoop:
        mov eax, esi
        add eax, "0"
                
        mov [numberPath + 19], al ; replace the byte in the 19th position, the *, with the number
        push OFFSET numberPath
        push renderer
        call IMG_LoadTexture
        add esp, 8

        mov [numberAddresses + esi * 4], eax

        inc esi
        cmp esi, 10
        jne loadNumbersLoop


    ; load all of the images
    mov esi, 0
    mov edi, 0
    loadTexturesLoop:
        push edi
        push esi

        lea eax, [loseImagePath + edi]
        push eax
        push renderer
        call IMG_LoadTexture
        add esp, 8

        pop esi
        pop edi
        mov [loseImage + esi * 4], eax
        push edi
        push esi

        lea eax, [loseImagePath + edi]
        push eax
        call stringLength
        add esp, 4
        
        pop esi
        pop edi

        add edi, eax
        inc edi

        inc esi
        cmp esi, IMAGE_COUNT
        jne loadTexturesLoop



    ; load all of the music
    mov esi, 0
    mov edi, 0
    loadMusicLoop:
        push edi
        push esi

        lea eax, [gameMusicStartPath + edi]
        push eax
        call Mix_LoadMUS
        add esp, 4

        pop esi
        pop edi
        mov [gameMusicStart + esi * 4], eax
        push edi
        push esi

        lea eax, [gameMusicStartPath + edi]
        push eax
        call stringLength
        add esp, 4
        
        pop esi
        pop edi

        add edi, eax
        inc edi

        inc esi
        cmp esi, MUSIC_COUNT
        jne loadMusicLoop


    ; load all of the sound
    mov esi, 0
    mov edi, 0
    loadSoundsLoop:
        push edi
        push esi

        lea eax, [bonusTouchPath + edi]
        push eax
        call Mix_LoadWAV
        add esp, 4

        pop esi
        pop edi
        mov [bonusTouchSound + esi * 4], eax
        push edi
        push esi

        lea eax, [bonusTouchPath + edi]
        push eax
        call stringLength
        add esp, 4
        
        pop esi
        pop edi

        add edi, eax
        inc edi

        inc esi
        cmp esi, SOUND_COUNT
        jne loadSoundsLoop

    call getTime
    mov startTime, eax

    gameLoop:

    mov edx, 0
    mov eax, executions
    mov ebx, 16666666
    mul ebx
    mov ecx, eax

    push ecx
    
    call getTime

    pop ecx

    sub eax, startTime
    sub eax, ecx



    cmp eax, 16666666
    jl gameLoop

    ; the game loop starts here

    inc executions

    push OFFSET h
    push OFFSET w
    push window
    call SDL_GetWindowSizeInPixels
    add esp, 12
        
    finit

    fld w
    fld full_w
    fdiv
    fstp scaleX

    fld h
    fld full_h
    fdiv
    fstp scaleY

    push scaleY
    push scaleX
    push renderer
    call SDL_RenderSetScale
    add esp, 12


    cmp gameState, 0
    jne afterInit
        ; init variables
        mov goodColorIndex, 0

        cmp timer, 405
        jg afterInitTimer
            mov timer, 405
            mov fullTimer, 5805
        afterInitTimer:
        mov esi, 0

        initResetArraysLoop:
            mov [fullTimerColors + esi], 255
            mov [levers_state + esi], 0
            mov [levers_light + esi], 0
            inc esi
            cmp esi, 3
            jne initResetArraysLoop

        mov sliderPos, 0
        mov sliderDrawPos, 0
        mov sliderDragged, 0
        mov bonusNodeState, 0
        mov round, 0
        mov score, 0


        mov gameState, 1
    afterInit:
    
 


    cmp timer, 405
    jne afterPlayMusic
    cmp gameState, 1
    jne afterPlayMusic
    
    call Mix_HaltMusic
        
    push 0
    push gameMusicStart
    call Mix_PlayMusic
    add esp, 8

    afterPlayMusic:

    ; event handling
    mov mousePressed, 0
    mov mouseReleased, 0
    eventHandlingLoop:
        ; event + 20 holds event.key.keysym.sym
        push OFFSET event
        call SDL_PollEvent
        add esp, 4
    
        cmp eax, 0
        je afterEventHandling

        mov eax, dword ptr [event]

        cmp eax, SDL_QUIT
        je quitLabel

        cmp eax, SDL_KEYDOWN
        je checkButton

        cmp eax, SDL_MOUSEBUTTONDOWN
        je setMouseDown

        cmp eax, SDL_MOUSEBUTTONUP
        je setMouseUp
        ; default case
        jmp eventHandlingLoop

        quitLabel:
            mov gaming, 0
            jmp afterEndScreen
        checkButton:
            mov eax, dword ptr [event + 20]
            cmp	eax, SDLK_F11 
            je fullscreenHandling
            cmp	eax, SDLK_r
            jne eventHandlingLoop

            cmp gameState, 1
            je startGameEarlyLabel
            mov gameState, 0
            jmp gameLoop
            startGameEarlyLabel:
            mov timer, 1
            mov fullTimer, 5401

            jmp gameLoop

            fullscreenHandling:
                xor fullscreen, 1
                cmp fullscreen, 1
                je fullscreenTrue
                    push 0
                    jmp setFullscreen
                fullscreenTrue:
                    push SDL_WINDOW_FULLSCREEN_DESKTOP
                setFullscreen:
                push window
                call SDL_SetWindowFullscreen
                add esp, 8
                jmp eventHandlingLoop
        setMouseDown:
            mov mousePressed, 1
            jmp eventHandlingLoop
        setMouseUp:
            mov mouseReleased, 1
            jmp eventHandlingLoop

    
    
    afterEventHandling:
    ; update mouse coordinates 

    mov eax, 0
    mov eax, mouseX
    mov prevMouseX, ax

    mov eax, mouseY
    mov prevMouseY, ax

    push OFFSET mouseY
    push OFFSET mouseX
    call SDL_GetMouseState
    add esp, 8


    fld mouseX
    fld scaleX
    fdiv
    fstp mouseX

    fld mouseY
    fld scaleY
    fdiv
    fstp mouseY


    push 1280
    push 0
    push mouseX
    call clamp
    add esp, 12
    mov mouseX, eax

    push 720
    push 0
    push mouseY
    call clamp
    add esp, 12
    mov mouseY, eax

    ; end update mouse coordinates



    ; timer handling

    cmp gameState, 2
    jg skipResetTimer

    dec fullTimer
    dec timer
    jnz skipResetTimer
        mov timer, 180
        inc round
        mov esi, 0
        mov eax, 1
        cmp eax, COOL_COLORS
        jne skipNewColors

        mov eax, LENGTHOF goodColors
        dec eax ; adding 1 later, this is so you don't randomly get the black and white palette
        mov edx, 0
        mov ebx, 6
        div ebx
        

        push eax

        call randomNum
        mov edx, 0
        pop ebx
        div ebx

        inc dl
        mov goodColorIndex, dl
        skipNewColors:
        

        cmp levers, 0
        je afterNewLeverLights

        mov esi, 0
        leverLightsCheck:
            mov al, [levers_light + esi]
            mov ah, [levers_state + esi]

            cmp al, ah
            jne loseLabel
            inc esi
            cmp esi, 3
            jne leverLightsCheck
        mov esi, 0
        newLeverLightsLoop:
            push esi

            call randomNum
            mov edx, 0
            mov ebx, 2
            div ebx

            pop esi

            mov [levers_light + esi], dl
           

            inc esi
            cmp esi, 3
            jne newLeverLightsLoop

        afterNewLeverLights:

        mov esi, 0
        cmp esi, CIRCLE_AMOUNT
        je skipResetCircles

        resetCirclesLoop:
            call randomNum
            mov edx, 0
            mov ebx, 1080
            div ebx  

            mov [circles_x + esi * 4], edx
            
            call randomNum
            mov edx, 0
            mov ebx, 720
            div ebx  

            mov [circles_y + esi * 4], edx

            mov eax, [circles_clicked + esi * 4]
            cmp eax, 0
            jne afterLoseLabel
                cmp gameState, 1
                je afterLoseLabel
                
                loseLabel:

                call Mix_HaltMusic

                push -1
                push gameOverMusic
                call Mix_PlayMusic
                add esp, 8

                mov gameState, 4
                mov sliderDragged, 0
                mov goodColorIndex, 0
                jmp skipResetTimer
        afterLoseLabel:

            mov [circles_clicked + esi * 4], 0

            inc esi
            cmp esi, CIRCLE_AMOUNT
            jne resetCirclesLoop

    skipResetCircles:
    cmp gameState, 1
    jne afterStartLabel

    push 0
    push gameMusic
    call Mix_PlayMusic
    add esp, 8

    mov gameState, 2
    afterStartLabel:
    cmp round, 31
    jne skipResetTimer

    ; win game
    mov gameState, 3
    mov timer, 0
    mov sliderDragged, 0
    call Mix_HaltMusic
        
    push 0
    push winMusic
    call Mix_PlayMusic
    add esp, 8

    mov goodColorIndex, 0
    skipResetTimer:
    ; end of timer handling

    ; draw background
    push 1
    call setColorToPalette
    add esp, 4

    push renderer
    call SDL_RenderClear
    add esp, 4

    ; end draw background

    ; draw streaks
    push 0
    call setColorToPalette
    add esp, 4

    mov esi, 0
    cmp esi, STREAKS_AMOUNT
    je afterDrawStreaks
    cmp gameState, 2
    jne afterDrawStreaks

    mov eax, 0
    mov ebx, 0
    handleStreaksLoop:
        mov ax, [streaks_x + esi * 2] 
        cmp ax, 1360 ; 1280 + 80
        jg afterMoveStreak
            add ax, 40
            mov [streaks_x + esi * 2], ax

            inc esi
            cmp esi, STREAKS_AMOUNT
            jne handleStreaksLoop
            jmp afterHandleStreaks
        afterMoveStreak:
            dec streaks_delay
            cmp streaks_delay, 0
            je afterHandleStreakDelay
                inc esi
                cmp esi, STREAKS_AMOUNT
                jne handleStreaksLoop
                jmp afterHandleStreaks
            afterHandleStreakDelay:
            mov streaks_delay, 10
            mov [streaks_x + esi * 2], 0
            call randomNum
            mov edx, 0
            mov ebx, 680
            div ebx

            add dx, 20
            mov [streaks_y + esi * 2], dx
    afterHandleStreaks:
        mov esi, 0
        drawStreaksLoop:
            mov eax, 0
            mov ebx, 0
            mov ecx, 0
            mov ax, [streaks_x + esi * 2]
            mov bx, [streaks_y + esi * 2]
            
            push esi

            mov cx, ax
            sub cx, 80
            cmp ax, 80
            jg afterClampStreakX
                mov cx, 0
            afterClampStreakX:

            push ebx
            push eax
            push ebx
            push ecx
            push renderer

            dec ebx

            push ebx
            push eax
            push ebx
            push ecx
            push renderer

            call SDL_RenderDrawLine
            add esp, 20

            call SDL_RenderDrawLine
            add esp, 20


            pop esi

            inc esi
            cmp esi, STREAKS_AMOUNT
            jne drawStreaksLoop

    afterDrawStreaks:

    ; draw timers
    push 0
    push 0
    push 0
    push 0
    push renderer
    call SDL_SetRenderDrawColor
    add esp, 20

    ; draw black rectangles & colored outlines at the top and bottom
    push 20
    push 1280
    push 0
    push 0
    call createSDLRect
    add esp, 16

    push eax
    push eax

    push renderer
    call SDL_RenderFillRect
    add esp, 8

    call deleteSDLRect
    add esp, 4

    push 20
    push 1280
    push 700
    push 0
    call createSDLRect
    add esp, 16

    push eax
    push eax

    push renderer
    call SDL_RenderFillRect
    add esp, 8

    call deleteSDLRect
    add esp, 4

    ; draw round timer
    push 0
    call setColorToPalette
    add esp, 4

    ; multiplication by 7 + 1/9
    mov edx, 0
    mov eax, timer
    mov ebx, 7
    mul ebx

    mov ecx, eax

    mov edx, 0
    mov eax, timer
    mov ebx, 9
    div ebx

    add ecx, eax
        
    push 20
    push ecx
    push 700
    push 0
    call createSDLRect
    add esp, 16
    
    push eax
    push eax

    push renderer
    call SDL_RenderFillRect
    add esp, 8

    call deleteSDLRect
    add esp, 4

    ; draw full timer (until game end)


    push 255

    ; push 3 random colors
    cmp gameState, 2
    jne afterFullTimerColor

    mov edx, 0
    mov eax, 0
    mov ax, fullTimer
    mov ebx, 8
    div ebx

    ; we only want to generate new colors every 8 frames or it flashes too fast and doesn't look good
    cmp dl, 0
    jne afterFullTimerColor


    mov esi, 0
    fullTimerRandomColor:
        push esi
        call randomBrightColorValue
        pop esi
        

        mov [fullTimerColors + esi], al

        inc esi
        cmp esi, 3
        jne fullTimerRandomColor
    afterFullTimerColor:

    mov eax, 0
    mov al, [fullTimerColors]
    push eax
    mov al, [fullTimerColors + 1]
    push eax
    mov al, [fullTimerColors + 2]
    push eax

    push renderer
    call SDL_SetRenderDrawColor
    add esp, 20

    mov eax, 0
    mov ax, fullTimer

    ; multiplication by 5400/1280
    mov ebx, 237    
    mul ebx               

    mov ebx, 1000
    div ebx

    push 20
    push eax
    push 0
    push 0
    call createSDLRect
    add esp, 16

    push eax
    push eax

    push renderer
    call SDL_RenderFillRect
    add esp, 8

    call deleteSDLRect
    add esp, 4
    
    push 0
    call setColorToPalette
    add esp, 4
    ; end draw timer


    ; draw instructions
    cmp gameState, 1
    jne afterDrawInstructions
        push 720
        push 1280
        push 0
        push 0
        call createSDLRect
        add esp, 16

        push eax
        
        push eax
        push 0
        push [instructionsImage]
        push renderer
        call SDL_RenderCopy
        add esp, 16

        call deleteSDLRect
        add esp, 4
    afterDrawInstructions:
    ; end draw instructions
    

    cmp slider, 0
    je afterSlideDrawing

    ; slider handling
    cmp gameState, 2
    jne afterSlideHandling
        add sliderPos, SLIDER_SPEED
        cmp mouseReleased, 1
        jne startSlideHandling
            mov sliderDragged, 0
        startSlideHandling:
        cmp sliderDragged, 1
        je slideDragHandling
        cmp mousePressed, 0
        je afterSlideClick
            mov eax, 0
            mov edx, 0
            mov ax, sliderPos
            mov ebx, 5
            mul ebx
            mov ebx, 7
            div ebx        

            add eax, 100


            push eax
            push 1150

            push mouseY
            push mouseX

            call distanceBetweenPoints
            add esp, 16



            cmp eax, 40
            jg afterSlideClick
            mov sliderDragged, 1
            jmp slideDragHandling
        afterSlideClick:
        

        cmp sliderPos, 700
        jl afterSlideHandling
        jmp loseLabel

    slideDragHandling:
        sub sliderPos, SLIDER_SPEED
        push 2
        call Mix_Playing
        add esp, 4

        cmp eax, 1
        je skipSliderSound
            push 0
            push sliderDragSound
            push 2
            call Mix_PlayChannel
            add esp, 12
        skipSliderSound:
        mov edx, 0
        mov eax, mouseY
        mov ebx, 7
        mul ebx
        mov ebx, 5
        div ebx        
        sub eax, 130

        cmp ax, sliderPos
        jg afterSlideHandling
        cmp ax, 0
        jl resetSliderPos
        mov sliderPos, ax
        jmp afterSlideHandling
        resetSliderPos:
            mov sliderPos, 0
    afterSlideHandling:

    ; slider drawing
    push 100
    push 1150
    push 600
    push 1150
    push renderer
    call SDL_RenderDrawLine
    add esp, 20

    push 40
    push 600
    push 1150
    call drawCircle
    add esp, 12


    mov eax, 0
    mov edx, 0
    mov ax, sliderPos
    mov ebx, 5
    mul ebx
    mov ebx, 7
    div ebx        
    add eax, 100
    push eax

    push 40
    push eax
    push 1150
    call drawCircleFilled
    add esp, 12


    pop eax
    sub eax, 24
    push 48
    push 48
    push eax
    push 1126
    call createSDLRect
    add esp, 16

    push eax

    cmp gameState, 3
    je sliderFaceWin

    cmp sliderDragged, 1
    je sliderFaceHappy

    jmp sliderFaceSad

    sliderFaceWin:
    mov ebx, sliderWinImage
    jmp drawSliderFace

    sliderFaceHappy:
    mov ebx, sliderHappyImage
    jmp drawSliderFace

    sliderFaceSad:
    mov ebx, sliderSadImage

    
    drawSliderFace:
    ; draw slider expression
    push eax
    push 0 ; null
    push ebx
    push renderer
    call SDL_RenderCopy
    add esp, 16

    call deleteSDLRect
    add esp, 4


    afterSlideDrawing:

        cmp bonusNode, 0
    je afterBonusNodeDraw
    cmp gameState, 2
    jne afterBonusNodeHandle
    cmp sliderDragged, 1 ; so you can't keep the slider dragged and use the bonus
    je afterBonusNodeHandle
    ; bonus node handling
    ; bonus node needs to detect if the mouse has just passed through it's x position,
    ; and then check if that happened above or below it. if it intersected where it
    ; last didn't, award some points and flip the place to intersect next

    cmp mouseX, 150
    setge al

    cmp prevMouseX, 150
    setge ah

    cmp al, ah
    jne bonusNodeTouch
    jmp afterBonusNodeHandle

    bonusNodeTouch:
        cmp mouseY, 450
        setle al
        cmp al, bonusNodeState
        je afterBonusNodeHandle

        mov eax, mouseY
        sub eax, 450
        cmp eax, 0
        jg bonusNodeSkipNeg
            neg eax
        bonusNodeSkipNeg:
        cmp eax, 100
        jg afterBonusNodeHandle

        xor bonusNodeState, 1
        add score, 100
        push 0
        push bonusTouchSound
        push 0
        call Mix_PlayChannel
        add esp, 12
    afterBonusNodeHandle:

    ; end bonus node handling

    ; bonus node drawing
    mov eax, 0
    cmp bonusNodeState, 1
    je bonusNodeSkipGreen
        push 255
        push 0
        push 255
        push 0
        push renderer
        call SDL_SetRenderDrawColor
        add esp, 20

    bonusNodeSkipGreen:
    push 350
    push 150
    push 450
    push 150
    push renderer
    call SDL_RenderDrawLine
    add esp, 20

    push 0
    call setColorToPalette
    add esp, 4

    cmp bonusNodeState, 0
    je bonusNodeSkipGreen2
        push 255
        push 0
        push 255
        push 0
        push renderer
        call SDL_SetRenderDrawColor
        add esp, 20
    bonusNodeSkipGreen2:

    push 450
    push 150
    push 550
    push 150
    push renderer
    call SDL_RenderDrawLine
    add esp, 20


    push 0
    call setColorToPalette
    add esp, 4

    push 30
    push 450
    push 150
    call drawCircleFilled
    add esp, 12

    afterBonusNodeDraw:
    ; end bonus node drawing

    
    ; circle click detection
    ; needs to happen before lever handling, but drawing needs to happen after, so the circles
    ; are on top of the levers, but you don't accidentally click a lever while trying to click a circle
    mov al, 0
    cmp al, CIRCLE_AMOUNT
    je afterCircleDraw
    cmp mousePressed, 0
    je afterClick
    cmp gameState, 2
    jne afterClick
        
    mov esi, 0
    clickCirclesLoop:
                
        cmp [circles_clicked + esi * 4], 1
        je noClick

        mov eax, mouseX
        mov ebx, mouseY

        mov ecx, [circles_x + esi * 4] 
        mov edx, [circles_y + esi * 4] 
        
        push esi

        push edx
        push ecx
        push ebx
        push eax
        call distanceBetweenPoints
        add esp, 16

        pop esi
        cmp eax, timer
        jge noClick
            mov [circles_clicked + esi * 4], 1
            add score, 1000
            mov mousePressed, 0
            push 0
            push circleClickSound
            push 1
            call Mix_PlayChannel
            add esp, 12
            jmp afterClick
        noClick:
        

        inc esi
        cmp esi, CIRCLE_AMOUNT
        jne clickCirclesLoop

    afterClick:
    ; end click detection



    ; lever handling
    cmp levers, 0
    je afterLeverDraw
    cmp mousePressed, 1 
    jne afterLeverHandle
    cmp gameState, 2
    jne afterLeverHandle


    mov esi, 0
    handleLeverLoop:
        mov edx, 0
        mov eax, 100
        mul esi
        add eax, 540

        push esi

        push 604
        push eax
        push mouseY
        push mouseX
        call distanceBetweenPoints
        add esp, 16

        pop esi

        cmp eax, 50
        jg leverNotClicked
            xor [levers_state + esi], 1
            push 0
            push leverFlickSound
            push 1
            call Mix_PlayChannel
            add esp, 12
            jmp afterLeverHandle
        leverNotClicked:
        

        inc esi
        cmp esi, 3
        jne handleLeverLoop



    afterLeverHandle:



    ; lever drawing
    mov esi, 0
    drawLeverLoop:
        push esi

        push 0
        call setColorToPalette
        add esp, 4

        pop esi

        mov edx, 0
        mov eax, 100
        mul esi
        add eax, 540

        push eax
        push eax

        push 32
        push 604
        push eax
        call drawCircleFilled
        add esp, 12

        pop eax
        sub eax, 32

        push 128
        push 64
        push 540
        push eax
        call createSDLRect
        add esp, 16

        push eax
        push eax


        mov eax, leverUpImage
        mov bl, [levers_state + esi]
        cmp bl, 1
        je afterLeverImage
            mov eax, leverDownImage
        afterLeverImage:

        push 0
        push eax
        push renderer
        call SDL_RenderCopy
        add esp, 16

        call deleteSDLRect
        add esp, 4


        push 255
        push 0
        push 0
        push 255
        push renderer
        call SDL_SetRenderDrawColor
        add esp, 20

        pop eax

        mov ecx, 678
        mov bl, [levers_light + esi]
        cmp bl, 0
        je drawLeverIndicator
        push eax

        push 255
        push 0
        push 255
        push 0
        push renderer
        call SDL_SetRenderDrawColor
        add esp, 20

        pop eax

        mov ecx, 530
        drawLeverIndicator:
        push 16
        push ecx
        push eax
        call drawCircleFilled
        add esp, 12
            

        inc esi
        cmp esi, 3
        jne drawLeverLoop

    afterLeverDraw:

    push 0
    call setColorToPalette
    add esp, 4

    cmp gameState, 2
    jne afterCircleDraw
    ; drawing the circles
    mov esi, 0
    drawCirclesLoop:
        
        
        mov ecx, [circles_clicked + esi * 4]
        cmp ecx, 1
        lea edx, drawCircle
        je drawFullCircle
            lea edx, drawCircleFilled
        drawFullCircle:


        push timer

        mov eax, [circles_x + esi * 4] 
        mov ebx, [circles_y + esi * 4] 

        push ebx
        push eax
        call edx
        add esp, 12

        
        inc esi
        cmp esi, CIRCLE_AMOUNT
        jne drawCirclesLoop

    afterCircleDraw:

     ; score display
    mov ecx, 0

    drawDigitsLoop:
        push ecx

        mov eax, 5
        sub eax, ecx
        mov ecx, eax

        inc ecx
        mov eax, score
        getCurrentDigit: 
            mov edx, 0
            mov ebx, 10
            div ebx

            loop getCurrentDigit
            
        mov edi, edx

        pop ecx
        push ecx
        push edi

        push 24
        push 24
        mov ebx, ecx
        shl ebx, 6
        add ebx, 450
        push 30
        push ebx
        call createSDLRect
        add esp, 16

        pop edi

        push eax


        push eax
        push 0 ; null
        push [numberAddresses + edi * 4]
        push renderer
        call SDL_RenderCopy
        add esp, 16

        call deleteSDLRect
        add esp, 4

        pop ecx

        inc ecx
        cmp ecx, 6
        jne drawDigitsLoop
    ; end score display


    cmp gameState, 2
    jle afterEndScreen

        
        push 400
        push 800
        push 160
        push 240
        call createSDLRect
        add esp, 16

        push eax

        cmp gameState, 4
        je drawLose

        ; draw win screen
        push eax
        push 0 ; null
        push winImage
        push renderer
        call SDL_RenderCopy
        add esp, 16

        call deleteSDLRect
        add esp, 4

        jmp afterEndScreen

        ; draw lose screen
        drawLose:


        push eax
        push 0 ; null
        push loseImage
        push renderer
        call SDL_RenderCopy
        add esp, 16

        call deleteSDLRect
        add esp, 4


    afterEndScreen:

    push renderer
    call SDL_RenderPresent
    add esp, 4

    cmp gaming, 1
    je gameLoop

    ; removing things from memory

    mov esi, 0
    destroyMusicLoop:
        push [gameMusicStart + esi * 4]
        call Mix_FreeMusic
        add esp, 4

        inc esi
        cmp esi, MUSIC_COUNT
        jne destroyMusicLoop

    mov esi, 0
    destroySoundsLoop:
        push [bonusTouchSound + esi * 4]
        call Mix_FreeChunk
        add esp, 4

        inc esi
        cmp esi, SOUND_COUNT
        jne destroySoundsLoop


    mov esi, 0
    destroyTexturesLoop:
        push [loseImage + esi * 4]
        call SDL_DestroyTexture
        add esp, 4

        inc esi
        cmp esi, IMAGE_COUNT
        jne destroyTexturesLoop

    push renderer
    call SDL_DestroyRenderer
    add esp, 4

    push window
    call SDL_DestroyWindow
    add esp, 4

    call Mix_CloseAudio

    call Mix_Quit
    call IMG_Quit
    call SDL_Quit
    ret
asmMain ENDP






drawCircle PROC pos_x: dword, pos_y: dword, radius: dword
    ; This is an implementation of the midpoint circle algorithm
    ; I selected it since it does not need trigonometry and was very simple.
    LOCAL x: dword, y: dword, error: dword
    mov eax, radius
    mov x, eax
    mov y, 0
    mov error, 0
    circleLoop:
        
        ; draw these points
        ;(pos_x + x, pos_y + y)
        ;(pos_x + x, pos_y - y)
        ;(pos_x - x, pos_y - y)
        ;(pos_x - x, pos_y + y)
        mov eax, pos_x 
        add eax, x
        mov ebx, pos_y
        add ebx, y
        push ebx
        push eax
        push renderer
        call SDL_RenderDrawPoint
        add esp, 12

        mov eax, pos_x 
        add eax, x
        mov ebx, pos_y 
        sub ebx, y
        push ebx
        push eax
        push renderer
        call SDL_RenderDrawPoint
        add esp, 12

        mov ebx, pos_y 
        sub ebx, y
        mov eax, pos_x 
        sub eax, x
        push ebx
        push eax
        push renderer
        call SDL_RenderDrawPoint
        add esp, 12

        mov eax, pos_x
        sub eax, x
        mov ebx, pos_y
        add ebx, y
        push ebx
        push eax
        push renderer
        call SDL_RenderDrawPoint
        add esp, 12

        ; draw these points
        ;(pos_x + y, pos_y + x)
        ;(pos_x + y, pos_y - x)
        ;(pos_x - y, pos_y - x)
        ;(pos_x - y, pos_y + x)

        mov eax, pos_x 
        add eax, y
        mov ebx, pos_y
        add ebx, x
        push ebx
        push eax
        push renderer
        call SDL_RenderDrawPoint
        add esp, 12

        mov eax, pos_x
        add eax, y
        mov ebx, pos_y
        sub ebx, x
        push ebx
        push eax
        push renderer
        call SDL_RenderDrawPoint
        add esp, 12

        mov ebx, pos_y 
        sub ebx, x
        mov eax, pos_x
        sub eax, y
        push ebx
        push eax
        push renderer
        call SDL_RenderDrawPoint
        add esp, 12

        mov eax, pos_x
        sub eax, y
        mov ebx, pos_y 
        add ebx, x
        push ebx
        push eax
        push renderer
        call SDL_RenderDrawPoint
        add esp, 12

        ; done drawing

        inc y
        inc error
        mov eax, y
        shl eax, 1
        add error, eax

        mov eax, error
        sub eax, x
        shl eax, 1
        inc eax

        cmp eax, 0
        jng skipErrorCheck
            dec x
            mov eax, x
            shl eax, 1
            mov ebx, 1
            sub ebx, eax
            add error, ebx
        skipErrorCheck:

        mov eax, x
        cmp eax, y
    jge circleLoop


    ret
drawCircle ENDP

drawCircleFilled PROC pos_x:dword, pos_y:dword, radius:dword
    ; This is a modification of the function above to draw the circle using lines so it looks filled.
    ; is probably not very fast, but we don't care
    LOCAL x: dword, y: dword, error: dword
    
    mov eax, radius
    mov x, eax
    mov y, 0
    mov error, 0
    circleLoop:
        
        ;from
        ;(pos_x - x, pos_y - y)
        ;to
        ;(pos_x + x, pos_y - y)

        mov eax, pos_x
        sub eax, x
        mov ebx, pos_y 
        sub ebx, y

        mov ecx, pos_x
        add ecx, x
        mov edx, pos_y
        sub edx, y

        push edx
        push ecx
        push ebx
        push eax
        push renderer
        call SDL_RenderDrawLine
        add esp, 20
    
        ;from
        ;(pos_x - x, pos_y + y)
        ;to
        ;(pos_x + x, pos_y + y)
    

        mov eax, pos_x 
        sub eax, x
        mov ebx, pos_y 
        add ebx, y

        mov ecx, pos_x
        add ecx, x
        mov edx, pos_y
        add edx, y

        push edx
        push ecx
        push ebx
        push eax
        push renderer
        call SDL_RenderDrawLine
        add esp, 20

        ;from
        ;(pos_x - y, pos_y - x)
        ;to
        ;(pos_x + y, pos_y - x)

        mov eax, pos_x 
        sub eax, y
        mov ebx, pos_y 
        sub ebx, x

        mov ecx, pos_x
        add ecx, y
        mov edx, pos_y
        sub edx, x

        push edx
        push ecx
        push ebx
        push eax
        push renderer
        call SDL_RenderDrawLine
        add esp, 20
    
        ;from
        ;(pos_x - y, pos_y + x)
        ;to
        ;(pos_x + y, pos_y + x)

        mov eax, pos_x 
        sub eax, y
        mov ebx, pos_y 
        add ebx, x

        mov ecx, pos_x
        add ecx, y
        mov edx, pos_y
        add edx, x

        push edx
        push ecx
        push ebx
        push eax
        push renderer
        call SDL_RenderDrawLine
        add esp, 20

        ; done drawing

        inc y
        inc error

        mov eax, y
        shl eax, 1
        add error, eax

        mov eax, error
        sub eax, x
        shl eax, 1
        inc eax

        cmp eax, 0
        jng skipErrorCheck
            dec x
            mov eax, x
            shl eax, 1
            mov ebx, 1
            sub ebx, eax
            add error, ebx
        skipErrorCheck:

        mov eax, x
        cmp eax, y
    jge circleLoop

    ret
drawCircleFilled ENDP

randomBrightColorValue PROC
    call randomNum

    mov edx, 0
    mov ebx, 160 ; instead of generating a random number between 0-255, we generate from 95-255, so the resulting values will produce brighter colors
    div ebx

    add edx, 95

    mov eax, edx
    ret
randomBrightColorValue ENDP



setColorToPalette PROC secondary: byte ; if 1 it will set the color to the second color in the set.
    push 255

    mov edx, 0
    mov ebx, 0
    mov eax, 6
    mov bl, goodColorIndex
    inc bl
    mul ebx
    mov esi, eax
    mov eax, 0

    dec esi
    cmp secondary, 0
    sete al
    sub esi, eax
    shl al, 1
    sub esi, eax

    mov ecx, 3
    pushLoop:
        mov al, [goodColors + esi]
        push eax

        dec esi
        loop pushLoop
    push renderer
    call SDL_SetRenderDrawColor
    add esp, 20
    ret
setColorToPalette ENDP

stringLength PROC address: dword
    mov esi, address
    mov edi, 0
    stringLengthLoop:
        mov bl, [esi + edi]
        cmp bl, 0
        je stringLengthDone
        inc edi
        jmp stringLengthLoop

    stringLengthDone:
    mov eax, edi
    ret
stringLength ENDP

clamp PROC value: dword, bottom: dword, top: dword
    mov eax, value
    cmp eax, bottom
    jg skipBottom
        mov eax, bottom
        ret
    skipBottom:

    cmp eax, top
    jl skipTop
        mov eax, top
        ret
    skipTop:

    ret
clamp ENDP

randomNum PROC
    call getTime
    push eax
    call srand
    add esp, 4

    call rand
    ret
randomNum ENDP

end