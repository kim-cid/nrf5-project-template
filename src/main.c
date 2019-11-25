/**
 * @file main.c
 *
 * @brief Blinky example application main file.
 */

#include "nrf_gpio.h"
#include "nrf_delay.h"

int main(void)
{
    nrf_gpio_cfg_output(18);

    while (true)
    {
        nrf_gpio_pin_toggle(18);

        nrf_delay_ms(500);
    }

    return 0;
}
