/**
 * @file main.c
 *
 * @brief Blinky FreeRTOS Example Application main file.
 */

#include <stdbool.h>
#include <stdint.h>

#include "FreeRTOS.h"
#include "task.h"

#include "nordic_common.h"
#include "nrf_drv_clock.h"
#include "nrf_gpio.h"

#include "app_error.h"

/** Reference to LED toggling FreeRTOS task. */
TaskHandle_t m_led_toggle_task_handle = NULL;

/** Static allocated stack for LED toggling FreeRTOS task. */
StaticTask_t m_led_toggle_task_tcb;

/** Static allocated stack for LED toggling FreeRTOS task. */
StackType_t mp_led_toggle_task_stack[configMINIMAL_STACK_SIZE + 200];

/**
 * @brief LED task entry function.
 *
 * @param[in] p_parameter Pointer that will be used as the parameter for the task.
 */
static void led_toggle_task_function(void *p_parameter)
{
    UNUSED_PARAMETER(p_parameter);

    nrf_gpio_cfg_output(7);
    nrf_gpio_pin_set(7);

    while (true)
    {
        nrf_gpio_pin_toggle(7);

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

int main(void)
{
    /* Initialize clock driver for better time accuracy in FREERTOS */
    nrf_drv_clock_init();

    m_led_toggle_task_handle = xTaskCreateStatic(led_toggle_task_function,
                                                 "LED",
                                                 configMINIMAL_STACK_SIZE + 200,
                                                 NULL,
                                                 tskIDLE_PRIORITY,
                                                 mp_led_toggle_task_stack,
                                                 &m_led_toggle_task_tcb);

    /* Activate deep sleep mode */
    SCB->SCR |= SCB_SCR_SLEEPDEEP_Msk;

    vTaskStartScheduler();

    while (true)
        ;

    return 0;
}

/**
 * @brief Stack memory provider for FreeRTOS' Idle task.
 *
 * @param[out] pp_idle_task_tcb FreeRTOS' idle task TCB reference.
 * @param[out] pp_idle_task_stack FreeRTOS' idle task stack reference.
 * @param[out] p_idle_task_stack_size FreeRTOS' idle task stack size.
 */
void vApplicationGetIdleTaskMemory(StaticTask_t **pp_idle_task_tcb,
                                   StackType_t **pp_idle_task_stack,
                                   uint32_t *p_idle_task_stack_size)
{
    static StaticTask_t idle_task_tcb;
    static StackType_t p_idle_task_stack[configMINIMAL_STACK_SIZE];

    *pp_idle_task_tcb = &idle_task_tcb;
    *pp_idle_task_stack = p_idle_task_stack;
    *p_idle_task_stack_size = configMINIMAL_STACK_SIZE;
}
