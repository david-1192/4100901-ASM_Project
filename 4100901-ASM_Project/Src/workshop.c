// --- Ejemplo de parpadeo de LED LD2 en STM32L476RGTx -------------------------
#include <stdint.h>


typedef struct {
    volatile uint32_t MODER;   // Modo de configuración
    volatile uint32_t OTYPER;  // Tipo de salida
    volatile uint32_t OSPEEDR; // Velocidad de salida
    volatile uint32_t PUPDR;   // Resistencia de pull-up/pull-down
    volatile uint32_t IDR;     // Entrada de datos
    volatile uint32_t ODR;     // Salida de datos
} GPIO_TypeDef;

typedef struct {
    volatile uint32_t CTRL;    // Control y estado
    volatile uint32_t LOAD;    // Carga
    volatile uint32_t VAL;     // Valor actual
    volatile uint32_t CALIB;   // Calibración

} SYSYTICK_TypeDef;

typedef struct {
    volatile uint32_t CR;      // Control
    volatile uint32_t ICSCR;   // Configuración de RCC
    volatile uint32_t CFGR;    // Configuración del sistema
    volatile uint32_t PLLCFGR; // Configuración del PLL
    volatile uint32_t PLLSAI1CFGR; // Configuración del PLLSAI1
    volatile uint32_t PLLSAI2CFGR; // Configuración del PLLSAI2
    volatile uint32_t CIER;     // Interrupciones habilitadas
    volatile uint32_t CIFR;     // Interrupciones pendientes
    volatile uint32_t CICR;     // Interrupciones limpias
    volatile uint32_t RESERVED_1;  // Reservado
    volatile uint32_t AHB1RSTR; // Reset de AHB1
    volatile uint32_t AHB2RSTR; // Reset de AHB2
    volatile uint32_t AHB3RSTR; // Reset de AHB3
    volatile uint32_t RESERVED_2;  // Reservado
    volatile uint32_t APB1RSTR1; // Reset de APB1 1
    volatile uint32_t APB1RSTR2; // Reset de APB1 2
    volatile uint32_t APB2RSTR; // Reset de APB2
    volatile uint32_t RESERVED_3;  // Reservado
    volatile uint32_t AHB1ENR;  // Habilitación de reloj AHB1
    volatile uint32_t AHB2ENR;  // Habilitación de reloj AHB2
    volatile uint32_t AHB3ENR;  // Habilitación de reloj AHB3
    volatile uint32_t APB1ENR1;  // Habilitación de reloj APB1 1
    volatile uint32_t APB1ENR2;  // Habilitación de reloj APB1 2
    volatile uint32_t APB2ENR;  // Habilitación de reloj APB2
} RCC_TypeDef;


#define SYSYTICK ((SYSYTICK_TypeDef *)0xE000E010U) // Dirección base de SysTick

#define RCC ((RCC_TypeDef *)0x40021000U) // Dirección base de RCC

#define GPIOA ((GPIO_TypeDef *)0x48000000U) // Dirección base de GPIOA

#define GPIOC ((GPIO_TypeDef *)0x48000800U) // Dirección base de GPIOC



#define LD2_PIN     5U                                         // Pin PA5 (LED LD2)
#define B1_PIN      13U                                         // Pin PC13 (Boton B1)
#define HSI_FREQ    4000U                                      // 1 ms (Reloj interno 4 MHz)

volatile uint32_t ms_counter = 0;

volatile uint8_t pressed_counter = 0;
volatile uint8_t pressed = 0;

void init_systick(void);
void init_button(void);
void init_led(void);


// --- Programa principal ------------------------------------------------------
int main(void)
{
    init_led();
    init_button();
    init_systick();

    uint32_t heartbeat_tick = 0;
    while (1) {
        if (pressed) {
            pressed = 0; // Reinicia el estado del botón
            heartbeat_tick = ms_counter + 3000; // Establece el tiempo de parpadeo
        }

        if (ms_counter >= heartbeat_tick) {
            GPIOA->ODR ^= (1 << LD2_PIN); // Alterna el estado del LED
            heartbeat_tick += 1000; // Establece el siguiente tiempo de parpadeo
        }
        
    }
}

// --- Inicialización de GPIOC PC3 para el Boton B1 -----------------------------
void init_button(void)
{
    RCC->AHB2ENR |= (1 << 2);            // Habilita el reloj de GPIOC

    GPIOC->MODER &= ~(0x03 << (B1_PIN*2));           // Limpia bits
    GPIOC->MODER |=  (0x00 << (B1_PIN*2));           // Configura como entrada
}

// --- Inicialización de GPIOA PA5 para el LED LD2 -----------------------------
void init_led(void)
{
    RCC->AHB2ENR |= (1 << 0);            // Habilita el reloj de GPIOA

    GPIOA->MODER &= ~(3 << (LD2_PIN*2));           // Limpia bits
    GPIOA->MODER |=  (1 << (LD2_PIN*2));           // Configura como salida
}

// --- Inicialización de Systick para 1 s --------------------------------------
void init_systick(void)
{
    SYSYTICK->LOAD = (HSI_FREQ - 1);              // Carga el valor de cuenta
    SYSYTICK->VAL  = 0;                            // Limpia el valor actual
    SYSYTICK->CTRL = (1 << 2) | (1 << 1) | (1 << 0); // Habilita SysTick, interrumpir y reloj HSI
}

// --- Manejador de la interrupción SysTick ------------------------------------
void SysTick_Handler(void)
{
    ms_counter++; // Incrementa el contador de milisegundos
    if ((GPIOC->IDR & (1 << B1_PIN)) == 0) { // Si el botón está presionado
        pressed_counter++; // Incrementa el contador de presión
        if (pressed_counter > 10) { // Si el botón ha sido presionado por más de 10 ms
            pressed = 1; // Marca que el botón fue presionado
        }
    } else {
        pressed_counter = 0; // Reinicia el contador si el botón no está presionado
    }
}