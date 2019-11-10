# nRF5 Project Template

Environment setup for developing with Nordic Semiconductor's nRF5 family of Bluetooth-enabled microcontrollers.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes.

### Prerequisites

- [Visual Studio Code](https://code.visualstudio.com/)
  - [C/C++](https://marketplace.visualstudio.com/items?itemName=ms-vscode.cpptools)
  - [Cortex-Debug](https://marketplace.visualstudio.com/items?itemName=marus25.cortex-debug)
  - [EditorConfig](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig)

- [GNU Arm Embedded Toolchain](https://developer.arm.com/tools-and-software/open-source-software/developer-tools/gnu-toolchain/gnu-rm/downloads)
  > Add the `bin` path of the ARM GCC toolchain to the `ARM_GCC_PATH` variable.

- [nRF5 SDK](https://www.nordicsemi.com/Software-and-Tools/Software/nRF5-SDK)
  > Add version and path of the ARM GCC toolchain to the SDK configuration file: `nRF5_SDK_<sdk_version>/components/toolchain/gcc/Makefile.posix`.
  > Add nRF5 SDK path to the environment variable `NRF5_SDK_PATH`.

- [nRF Command Line Tools](https://www.nordicsemi.com/Software-and-Tools/Development-Tools/nRF-Command-Line-Tools)
  > Installs [J-Link Software and Documentation Pack](https://www.segger.com/downloads/jlink).

- make
  > `sudo apt install make`

- uncrustify
  > `sudo apt install uncrustify`

## Preparing

### [config.mk](config.mk)

The `config.mk` file contains project-specific configurations, such as its name, device and output files' directory.

The target naming convention can be seen in [J-Link's list of supported devices](https://www.segger.com/downloads/supported-devices.php).

```Makefile
TARGET           := nRF52810_xxAA
```

It is also important that the Link Descriptor file is properly located at the project's root directory and identified by the `LINKER_SCRIPT` variable.

```Makefile
# Link descriptor file
LINKER_SCRIPT := $(PROJECT_NAME)-$(TARGET).ld # Named "nrf5-project-template-nRF52810_xxAA.ld" in this template.
```

If a SoftDevice is going to be used in the project, it can be defined here. Elsewise, this configuration must be **commented out**.

On SDK version **15.3.0**, the SoftDevices compatible with this configuration are: **S112**, **S132** and **S140**.

```Makefile
# SoftDevice
SOFTDEVICE := S112
```

### VSCode configurations

To add VSCode files `c_cpp_properties.json` and `launch.json` enabling complete **file indexing** and **debugging support**:

```bash
make prepare
```

## Compiling

To build the project:

```bash
make
```

To clean the project:

```bash
make clean
```

## Flashing

To flash the binary file, using **nrfjprog**:

```bash
make flash
```

To erase flash memory:

```bash
make erase
```

To flash the **SoftDevice** (if the project makes use of one):

```bash
make flash_softdevice
```

## Tasks

On VSCode, pressing `CTRL`+`SHIFT`+`B` will list Tasks for compiling, flashing, etc.

- Clean Project (_make clean_)
- Build Project (_make_)
- Rebuild Project (_make clean && make_)
- Flash Program (_make flash_)
- Flash SoftDevice (_make flash\_softdevice_)
- Flash Erase (_make erase_)
- Build and Flash (_make && make flash_)

## Debug

> This section is under construction!

Use VSCode's extension [Cortex-Debug](https://marketplace.visualstudio.com/items?itemName=marus25.cortex-debug), which is automatically recommended if not already installed. Its usage instructions can be found on the following link: https://marcelball.ca/projects/cortex-debug/.

Be sure to generate the necessary launch configuration for debugging with the ```make prepare``` command and connect the JLink probe attached to the target. 

Then, to start debugging, simply press **F5**; alternatively, tap the Debug icon, select the "**Cortex-Debug (JLink)**" launch configuration and hit start.

## DFU: Instructions and explanations

The recommended method for creating projects with DFU over BLE capabilities is to use Nordic's Secure DFU bootloader.

For a step-by-step guide on the dependencies and process of generating images for firmware updates, please check the following link: https://devzone.nordicsemi.com/nordic/nordic-blog/b/blog/posts/getting-started-with-nordics-secure-dfu-bootloader.

## Tips and tricks

This section is intended for documenting tips, procedures, hacks, workarounds, etc. that may be useful when developing for the nRF5 family of microcontrollers under certain conditions. Needles to say, this section may be updated through the course of time.

### Running FreeRTOS on the nRF52810

- **Issue:** The FreeRTOS port for the nRF52 family of microcontrollers assumes that the processor has a FPU (Floating Point Unit), but the nRF52810 has been stripped down of this functinality, for cost reduction reasons.

- **Workaround:** Thankfully, the FreeRTOS port makes no actual use of the FPU, other than pushing / popping its context register during context switches. The workaround is to make these snippets of code conditionally compiled:

```NRF5_SDK_PATH/external/freertos/portable/CMSIS/nrf52/port_cmsis.c```

```C
#if !(__FPU_USED) && !(__LINT__) && (defined(NRF52832_XXAA) || defined(NRF52840_XXAA))
    #error This port can only be used when the project options are configured to enable hardware floating point support.
#endif

...

#if defined(NRF52832_XXAA) || defined(NRF52840_XXAA)
    /* Lazy save always. */
    FPU->FPCCR |= FPU_FPCCR_ASPEN_Msk | FPU_FPCCR_LSPEN_Msk;
#endif
```

```NRF5_SDK_PATH/external/freertos/portable/GCC/nrf52/port.c```

```C
void xPortPendSVHandler( void )
{
    /* This is a naked function. */

    __asm volatile
    (
    "   mrs r0, psp                         \n"
    "   isb                                 \n"
    "                                       \n"
    "   ldr r3, =pxCurrentTCB               \n" /* Get the location of the current TCB. */
    "   ldr r2, [r3]                        \n"
    "                                       \n"

#if (__FPU_PRESENT == 1U) && (__FPU_USED == 1U)
    "   tst r14, #0x10                      \n" /* Is the task using the FPU context?  If so, push high vfp registers. */
    "   it eq                               \n"
    "   vstmdbeq r0!, {s16-s31}             \n"
    "                                       \n"
#endif

    "   stmdb r0!, {r4-r11, r14}            \n" /* Save the core registers. */
    "                                       \n"
    "   str r0, [r2]                        \n" /* Save the new top of stack into the first member of the TCB. */
    "                                       \n"
    "   stmdb sp!, {r3}                     \n"
    "   mov r0, %0                          \n"
    "   msr basepri, r0                     \n"
    "   dsb                                 \n"
    "   isb                                 \n"
    "   bl vTaskSwitchContext               \n"
    "   mov r0, #0                          \n"
    "   msr basepri, r0                     \n"
    "   ldmia sp!, {r3}                     \n"
    "                                       \n"
    "   ldr r1, [r3]                        \n" /* The first item in pxCurrentTCB is the task top of stack. */
    "   ldr r0, [r1]                        \n"
    "                                       \n"
    "   ldmia r0!, {r4-r11, r14}            \n" /* Pop the core registers. */
    "                                       \n"

#if (__FPU_PRESENT == 1U) && (__FPU_USED == 1U)
    "   tst r14, #0x10                      \n" /* Is the task using the FPU context?  If so, pop the high vfp registers too. */
    "   it eq                               \n"
    "   vldmiaeq r0!, {s16-s31}             \n"
    "                                       \n"
#endif

    "   msr psp, r0                         \n"
    "   isb                                 \n"
    "                                       \n"
    "                                       \n"
    "   bx r14                              \n"
    "                                       \n"
    "   .align 2                            \n"
    ::"i"(configMAX_SYSCALL_INTERRUPT_PRIORITY  << (8 - configPRIO_BITS))
    );
}
```

- **Resources:** [FreeRTOS on nRF52810](https://devzone.nordicsemi.com/f/nordic-q-a/30103/freertos-on-nrf52810)

### Flash and RAM usage

- **Tip:** Flash and RAM usage depend on whether the application makes use of a SoftDevice, bootloaders, etc. The tutorial [Adjustment of RAM and Flash memory](https://devzone.nordicsemi.com/nordic/short-range-guides/b/getting-started/posts/adjustment-of-ram-and-flash-memory) describes how to decide on and edit memory usage parameters.

- **Note:** The C / Assembly defines ```__STACK_SIZE``` and ```__HEAP_SIZE``` also reserve some of the available RAM for static and dynamic allocation, respectively, aside from the actual memory consumed by the **.data** (initialized variables) and **.bss** (uninitialized variables)  memory sections. Upon facing "region RAM overflowed with stack" linker errors, even though the application RAM usage is in check, lowering the values of these 2 defines may solve the problem.

## Authors

- **Gabriel Kim**

## Acknowledgments

- [ThundeRatz/STM32ProjectTemplate](https://github.com/ThundeRatz/STM32ProjectTemplate)
