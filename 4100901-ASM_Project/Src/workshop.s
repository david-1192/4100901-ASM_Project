// --- Ejemplo de parpadeo de LED LD2 en STM32F476RGTx -------------------------
    .section .data
button_pressed: .word 0
tick_counter:   .word 0

    .section .text
    .syntax unified
    .thumb

    .global main
    .global init_led
    .global init_button
    .global read_button
    .global init_systick
    .global SysTick_Handler

// --- Definiciones de registros para LD2 (Ver RM0351) -------------------------
    .equ RCC_BASE,       0x40021000         @ Base de RCC
    .equ RCC_AHB2ENR,    RCC_BASE + 0x4C    @ Enable GPIOA clock (AHB2ENR)
    .equ GPIOA_BASE,     0x48000000         @ Base de GPIOA
    .equ GPIOA_MODER,    GPIOA_BASE + 0x00  @ Mode register
    .equ GPIOA_ODR,      GPIOA_BASE + 0x14  @ Output data register
    .equ LD2_PIN,        5                  @ Pin del LED LD2
    .equ LD2_PIN_MODER,  (5 * 2)            @ Bit de MODER para LD2
    .equ LD2_PIN_MASK,   (1 << 5)           @ Máscara para ODR LD2

    .equ GPIOC_BASE,     0x48000800         @ Base de GPIOC
    .equ GPIOC_MODER,    GPIOC_BASE + 0x00  @ Mode register
    .equ GPIOC_IDR,      GPIOC_BASE + 0x10  @ Input data register
    .equ BUTTON_PIN,     13                 @ Pin del botón B1
    .equ BUTTON_PIN_MODER, (13 * 2)         @ Bit de MODER para botón
    .equ BUTTON_PIN_MASK, (1 << 13)         @ Máscara para IDR botón

// --- Definiciones de registros para SysTick (Ver PM0214) ---------------------
    .equ SYST_CSR,       0xE000E010         @ Control and status
    .equ SYST_RVR,       0xE000E014         @ Reload value register
    .equ SYST_CVR,       0xE000E018         @ Current value register
    .equ HSI_FREQ,       4000000            @ Reloj interno por defecto (4 MHz)

// --- Programa principal ------------------------------------------------------
main:
    bl init_led
    bl init_button
    bl init_systick

loop:
    bl read_button
    wfi
    b loop

// --- Inicialización de GPIOA PA5 para el LED LD2 -----------------------------
init_led:
    movw  r0, #:lower16:RCC_AHB2ENR
    movt  r0, #:upper16:RCC_AHB2ENR
    ldr   r1, [r0]
    orr   r1, r1, #(1 << 0)                @ Habilita reloj GPIOA
    str   r1, [r0]

    movw  r0, #:lower16:GPIOA_MODER
    movt  r0, #:upper16:GPIOA_MODER
    ldr   r1, [r0]
    bic   r1, r1, #(0b11 << LD2_PIN_MODER) @ Limpia bits MODER5
    orr   r1, r1, #(0b01 << LD2_PIN_MODER) @ PA5 como salida
    str   r1, [r0]
    bx    lr

// --- Inicialización de GPIOC PC13 como entrada (Botón B1) --------------------
init_button:
    movw  r0, #:lower16:RCC_AHB2ENR
    movt  r0, #:upper16:RCC_AHB2ENR
    ldr   r1, [r0]
    orr   r1, r1, #(1 << 2)                @ Habilita reloj GPIOC (bit 2)
    str   r1, [r0]

    movw  r0, #:lower16:GPIOC_MODER
    movt  r0, #:upper16:GPIOC_MODER
    ldr   r1, [r0]
    bic   r1, r1, #(0b11 << BUTTON_PIN_MODER) @ PC13 como entrada (00)
    str   r1, [r0]
    bx    lr

// --- Leer el botón y controlar el LED ----------------------------------------
read_button:
    movw  r0, #:lower16:GPIOC_IDR
    movt  r0, #:upper16:GPIOC_IDR
    ldr   r1, [r0]
    movs  r2, #BUTTON_PIN_MASK
    tst   r1, r2
    bne   button_not_pressed               @ Si PC13==1, no presionado (pull-up)

    ldr   r3, =button_pressed
    ldr   r4, [r3]
    cmp   r4, #0
    bne   button_not_pressed               @ Ya estaba presionado

    movs  r4, #1
    str   r4, [r3]                         @ Marca como presionado

    // Enciende el LED
    movw  r0, #:lower16:GPIOA_ODR
    movt  r0, #:upper16:GPIOA_ODR
    ldr   r1, [r0]
    orr   r1, r1, #LD2_PIN_MASK
    str   r1, [r0]

    // Inicializa el contador de ticks (3 segundos)
    ldr   r5, =tick_counter
    movs  r6, #0
    str   r6, [r5]

button_not_pressed:
    // Si el botón ya fue presionado, cuenta ticks y apaga LED después de 3s
    ldr   r3, =button_pressed
    ldr   r4, [r3]
    cmp   r4, #1
    bne   end_read_button

    ldr   r5, =tick_counter
    ldr   r6, [r5]
    ldr   r7, =3000                @ Cargar 3000 en r7
    cmp   r6, r7                   @ Comparar tick_counter con 3000
    blt   end_read_button

    // Apaga el LED
    movw  r0, #:lower16:GPIOA_ODR
    movt  r0, #:upper16:GPIOA_ODR
    ldr   r1, [r0]
    bic   r1, r1, #LD2_PIN_MASK
    str   r1, [r0]

    movs  r4, #0
    str   r4, [r3]                         @ Permite nueva pulsación

end_read_button:
    bx    lr

// --- Inicialización de Systick para 1 ms -------------------------------------
init_systick:
    movw  r0, #:lower16:SYST_RVR
    movt  r0, #:upper16:SYST_RVR
    movw  r1, #3999                       @ 4 MHz / 1000 - 1 = 3999 para 1 ms
    movt  r1, #0
    str   r1, [r0]

    movw  r0, #:lower16:SYST_CSR
    movt  r0, #:upper16:SYST_CSR
    movs  r1, #(1 << 0)|(1 << 1)|(1 << 2)  @ ENABLE=1, TICKINT=1, CLKSOURCE=1
    str   r1, [r0]
    bx    lr

// --- Manejador de la interrupción SysTick ------------------------------------
    .thumb_func
SysTick_Handler:
    ldr   r0, =tick_counter
    ldr   r1, [r0]
    adds  r1, r1, #1
    str   r1, [r0]
    bx    lr