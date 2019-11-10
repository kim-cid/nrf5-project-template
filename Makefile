# File: Makefile
# Author: Gabriel Kim
# 11/2019

###############################################################################
## Project settings
###############################################################################

# Include project specific configuration file
include config.mk

###############################################################################
## Verbosity
###############################################################################

# Verbosity setting
ifeq ($(VERBOSE), 1)
    AT :=
else
    AT := @
endif

###############################################################################
## Optimization
###############################################################################

# Optimization setting
ifeq ($(DEBUG), 1)
    OPT := -Og -O3
else
    OPT := -Os
    # OPT += -flto
endif

###############################################################################
## Toolchain + SDK
###############################################################################

# GNU ARM GCC toolchain
ifndef ARM_GCC_PATH
    $(error ARM_GCC_PATH not defined!)
endif

# nRF5 SDK
ifndef NRF5_SDK_PATH
    $(error NRF5_SDK_PATH not defined!)
endif

SDK_ROOT := $(NRF5_SDK_PATH)

###############################################################################
## Source files
###############################################################################

# SDK source files
ifeq ($(TARGET), nRF52810_xxAA)
    ASM_SOURCES := $(SDK_ROOT)/modules/nrfx/mdk/gcc_startup_nrf52810.S
    SDK_SOURCES := $(SDK_ROOT)/modules/nrfx/mdk/system_nrf52810.c
else ifeq ($(TARGET), nRF52811_xxAA)
    ASM_SOURCES := $(SDK_ROOT)/modules/nrfx/mdk/gcc_startup_nrf52811.S
    SDK_SOURCES := $(SDK_ROOT)/modules/nrfx/mdk/system_nrf52811.c
else ifeq ($(TARGET), nRF52840_xxAA)
    ASM_SOURCES := $(SDK_ROOT)/modules/nrfx/mdk/gcc_startup_nrf52840.S
    SDK_SOURCES := $(SDK_ROOT)/modules/nrfx/mdk/system_nrf52840.c
else ifeq ($(findstring nRF51, $(TARGET)), nRF51)
    ASM_SOURCES := $(SDK_ROOT)/modules/nrfx/mdk/gcc_startup_nrf51.S
    SDK_SOURCES := $(SDK_ROOT)/modules/nrfx/mdk/system_nrf51.c
else ifeq ($(findstring nRF52, $(TARGET)), nRF52)
    ASM_SOURCES := $(SDK_ROOT)/modules/nrfx/mdk/gcc_startup_nrf52.S
    SDK_SOURCES := $(SDK_ROOT)/modules/nrfx/mdk/system_nrf52.c
else
    $(error Unknown device or device family! $(TARGET))
endif

SDK_SOURCES += \
    $(SDK_ROOT)/components/libraries/util/app_util_platform.c \
    $(SDK_ROOT)/external/freertos/portable/CMSIS/nrf52/port_cmsis.c \
    $(SDK_ROOT)/external/freertos/portable/CMSIS/nrf52/port_cmsis_systick.c \
    $(SDK_ROOT)/external/freertos/portable/GCC/nrf52/port.c \
    $(SDK_ROOT)/external/freertos/source/list.c \
    $(SDK_ROOT)/external/freertos/source/tasks.c \
    $(SDK_ROOT)/integration/nrfx/legacy/nrf_drv_clock.c \
    $(SDK_ROOT)/modules/nrfx/drivers/src/nrfx_clock.c

# SDK header folders
SDK_HEADERS_FOLDERS := \
    $(SDK_ROOT)/components/drivers_nrf/nrf_soc_nosd \
    $(SDK_ROOT)/components/libraries/experimental_section_vars \
    $(SDK_ROOT)/components/libraries/log \
    $(SDK_ROOT)/components/libraries/log/src \
    $(SDK_ROOT)/components/libraries/util \
    $(SDK_ROOT)/components/toolchain/cmsis/include \
    $(SDK_ROOT)/external/freertos/config \
    $(SDK_ROOT)/external/freertos/portable/CMSIS/nrf52 \
    $(SDK_ROOT)/external/freertos/portable/GCC/nrf52 \
    $(SDK_ROOT)/external/freertos/source/include \
    $(SDK_ROOT)/integration/nrfx \
    $(SDK_ROOT)/integration/nrfx/legacy \
    $(SDK_ROOT)/modules/nrfx \
    $(SDK_ROOT)/modules/nrfx/drivers/include \
    $(SDK_ROOT)/modules/nrfx/hal \
    $(SDK_ROOT)/modules/nrfx/mdk

# Application source files
APP_SOURCES := $(shell find src -name "*.c")

# Application header files
APP_HEADERS := $(shell find inc -name "*.h")

# Source files
SRC_FILES   += \
    $(ASM_SOURCES) \
    $(SDK_SOURCES) \
    $(APP_SOURCES) \
    $(LIB_SOURCES)

###############################################################################
## Include paths
###############################################################################

# Include paths
INC_FOLDERS += \
    $(sort $(dir $(APP_HEADERS))) \
    $(sort $(dir $(LIB_HEADERS))) \
    $(SDK_HEADERS_FOLDERS)

###############################################################################
## Compilation defines
###############################################################################

# Device
DEVICE := $(shell echo $(TARGET) | tr '[:lower:]' '[:upper:]')

# C defines
C_DEFS   := \
    -DCONFIG_GPIO_AS_PINRESET \
    -DFREERTOS \
    -D$(DEVICE)

# Family specific defines (nRF51 / nRF52)
ifeq ($(findstring nRF51, $(TARGET)), nRF51)
    C_DEFS += -DNRF51
else ifeq ($(findstring nRF52, $(TARGET)), nRF52)
    C_DEFS += -DNRF52_PAN_74

    ifneq (, $(filter $(TARGET), nRF52832_xxAA nRF52840_xxAA))
        C_DEFS += -DFLOAT_ABI_HARD
    else
        C_DEFS += -DFLOAT_ABI_SOFT
    endif
endif

# Softdevice specific defines
ifdef SOFTDEVICE
    SOFTDEVICE_UC := $(shell echo $(SOFTDEVICE) | tr '[:lower:]' '[:upper:]')

    C_DEFS += \
        -D$(SOFTDEVICE_UC) \
        -DSOFTDEVICE_PRESENT \
        -DNRF_SD_BLE_API_VERSION=6 \
        -DBLE_STACK_SUPPORT_REQD
endif

ifeq ($(DEBUG), 1)
    C_DEFS += -DDEBUG
endif

###############################################################################
## Compilation flags
###############################################################################

# Common microcontroller related flags
MCUFLAGS := -mthumb -mabi=aapcs

# Device specific microcontroller related flags
ifeq ($(findstring nRF51, $(TARGET)), nRF51)
    MCUFLAGS += -mcpu=cortex-m0
else ifeq ($(findstring nRF52, $(TARGET)), nRF52)
    MCUFLAGS += -mcpu=cortex-m4

    ifneq (, $(filter $(TARGET), nRF52832_xxAA nRF52840_xxAA))
        MCUFLAGS += -mfloat-abi=hard -mfpu=fpv4-sp-d16
    else
        MCUFLAGS += -mfloat-abi=soft
    endif
endif

# C flags
CFLAGS := \
    $(MCUFLAGS) $(C_DEFS) \
    -Wall -Werror \
    -ffunction-sections -fdata-sections -fno-strict-aliasing \
    -fno-builtin -fshort-enums \
    $(OPT)

# Assembler flags
ASMFLAGS := \
    $(MCUFLAGS) $(C_DEFS) $(ASM_DEFS) \
    -g3

# Linker flags
LDFLAGS  := \
    $(OPT) $(MCUFLAGS) \
    -L$(SDK_ROOT)/modules/nrfx/mdk -T$(LINKER_SCRIPT) \
    -Wl,--gc-sections \
    --specs=nano.specs

# Heap and stack allocation related defines
CFLAGS += -D__HEAP_SIZE=$(HEAP_SIZE)
CFLAGS += -D__STACK_SIZE=$(STACK_SIZE)
ASMFLAGS += -D__HEAP_SIZE=$(HEAP_SIZE)
ASMFLAGS += -D__STACK_SIZE=$(STACK_SIZE)

# Add standard libraries at the very end of the linker input, after all objects
# that may need symbols provided by these libraries.
LIB_FILES += -lc -lnosys -lm

###############################################################################
## Build Targets
###############################################################################

# Default target (uses nRF5 SDK's Makefile.common)
default: $(PROJECT_NAME)

TEMPLATE_PATH := $(SDK_ROOT)/components/toolchain/gcc

include $(TEMPLATE_PATH)/Makefile.common

$(call define_target, $(PROJECT_NAME))

###############################################################################
## Release generation targets
###############################################################################

# Only generate releases and DFU packages when SoftDevice is defined.
ifdef SOFTDEVICE

# Lower-case target and SoftDevice
TARGET_LC      := $(shell echo $(TARGET) | tr '[:upper:]' '[:lower:]')
SOFTDEVICE_LC  := $(shell echo $(SOFTDEVICE) | tr '[:upper:]' '[:lower:]')

# Find DFU bootloader and SoftDevice .hex files
BOOTLOADER_HEX := $(shell find dfu -name "$(TARGET_LC)_$(SOFTDEVICE_LC).hex")
SOFTDEVICE_HEX := $(shell find $(SDK_ROOT)/components/softdevice/$(SOFTDEVICE_LC)/hex -name "*.hex")

# Determine family parameter for nrfutil settings file generation
ifeq ($(TARGET), nRF52810_xxAA)
    FAMILY := NRF52810
else ifeq ($(TARGET), nRF52840_xxAA)
    FAMILY := NRF52840
else ifeq ($(findstring nRF51, $(TARGET)), nRF51)
    FAMILY := NRF51
else ifeq ($(findstring nRF52, $(TARGET)), nRF52)
    FAMILY := NRF52
else
    $(error Unknown device or device family! $(TARGET))
endif

# Determine hw_version parameter for nrfutil package generation
ifeq ($(findstring nRF51, $(TARGET)), nRF51)
    HW_VERSION := 51
else ifeq ($(findstring nRF52, $(TARGET)), nRF52)
    HW_VERSION := 52
else
    $(error Target is invalid!)
endif

# Determine sd_req parameter for nrfutil package generation
ifeq ($(SOFTDEVICE), S112)
    SD_REQ := 0xB8
else ifeq ($(TARGET), S132)
    SD_REQ := 0xB7
else ifeq ($(TARGET), S140)
    SD_REQ := 0xB6
else
    $(error Unknown device or device family! $(TARGET))
endif

# Private key passed as key_file parameter for nrfutil package generation
PRIVATE_KEY := dfu/keys/private.key

# Generate release .hex file with: SoftDevice + Application + Settings + DFU bootloader
generate_release: default $(BOOTLOADER_HEX) | $(RELEASE_DIRECTORY)
	@echo Generating application settings file
	$(AT)nrfutil settings generate --family $(FAMILY) --application $(OUTPUT_DIRECTORY)/$(PROJECT_NAME).hex --application-version $(APP_VERSION) --bootloader-version 1 --bl-settings-version 1 $(RELEASE_DIRECTORY)/$(PROJECT_NAME)-settings.hex
	@echo Merging SoftDevice and DFU bootloader files
	$(AT)mergehex -m $(SOFTDEVICE_HEX) $(BOOTLOADER_HEX) -o $(RELEASE_DIRECTORY)/$(PROJECT_NAME)-sd-dfu.hex
	@echo Merging application and settings files
	$(AT)mergehex -m $(OUTPUT_DIRECTORY)/$(PROJECT_NAME).hex $(RELEASE_DIRECTORY)/$(PROJECT_NAME)-settings.hex -o $(RELEASE_DIRECTORY)/$(PROJECT_NAME)-app-settings.hex
	@echo Generating release .hex file
	$(AT)mergehex -m $(RELEASE_DIRECTORY)/$(PROJECT_NAME)-sd-dfu.hex $(RELEASE_DIRECTORY)/$(PROJECT_NAME)-app-settings.hex -o $(RELEASE_DIRECTORY)/$(PROJECT_NAME)-release.hex
	@echo Removing temporary .hex files
	$(AT)rm -rf $(RELEASE_DIRECTORY)/$(PROJECT_NAME)-settings.hex $(RELEASE_DIRECTORY)/$(PROJECT_NAME)-sd-dfu.hex $(RELEASE_DIRECTORY)/$(PROJECT_NAME)-app-settings.hex

# Generate dfu package .zip file with: Application + Settings
generate_dfu_package: $(OUTPUT_DIRECTORY)/$(PROJECT_NAME).hex | $(RELEASE_DIRECTORY)
	@echo Generating DFU package file
	$(AT)nrfutil pkg generate --application $(OUTPUT_DIRECTORY)/$(PROJECT_NAME).hex --application-version $(APP_VERSION) --hw-version $(HW_VERSION) --sd-req $(SD_REQ) --key-file $(PRIVATE_KEY) $(RELEASE_DIRECTORY)/$(PROJECT_NAME)-dfu-package.zip

# Flash release .hex file
flash_release: generate_release
	@echo Flashing: $(RELEASE_DIRECTORY)/$(PROJECT_NAME)-sd-dfu.hex
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --halt
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --reset
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --program $(RELEASE_DIRECTORY)/$(PROJECT_NAME)-release.hex --chiperase
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --reset

# Generate release directory
$(RELEASE_DIRECTORY):
	@echo Creating release directory
	$(AT)mkdir -p $@

else

generate_release:
	@echo SoftDevice is undefined!

generate_dfu_package:
	@echo SoftDevice is undefined!

flash_release:
	@echo SoftDevice is undefined!

endif

# Remove release folder
clean_release:
	@echo Removing release folder
	$(AT)rm -rf release

###############################################################################
## Device operations targets
###############################################################################

# Determine device family for nrfjprog.
ifeq ($(findstring nRF51, $(TARGET)), nRF51)
    DEVICE_FAMILY := NRF51
else ifeq ($(findstring nRF52, $(TARGET)), nRF52)
    DEVICE_FAMILY := NRF52
else
    DEVICE_FAMILY := UNKNOWN
endif

# Flash application
flash: default
	@echo Flashing: $(OUTPUT_DIRECTORY)/$(PROJECT_NAME).hex
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --halt
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --reset
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --program $(OUTPUT_DIRECTORY)/$(PROJECT_NAME).hex --sectorerase
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --reset

# Flash SoftDevice
ifdef SOFTDEVICE

flash_softdevice:
	@echo Flashing: SoftDevice $(SOFTDEVICE)
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --halt
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --reset
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --program $(SOFTDEVICE_HEX) --sectorerase
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --reset

else

flash_softdevice:
	@echo SoftDevice is undefined!

endif

# Erase device flash memory
erase:
	@echo Erasing flash memory
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --halt
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --reset
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --eraseall

# Reset device
reset:
	@echo Resetting target
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --halt
	$(AT)nrfjprog -f $(DEVICE_FAMILY) --reset

###############################################################################
## Auxiliary targets
###############################################################################

SDK_CONFIG_FILE := ./inc/config/sdk_config.h
CMSIS_CONFIG_TOOL := $(SDK_ROOT)/external_tools/cmsisconfig/CMSIS_Configuration_Wizard.jar
sdk_config:
	@echo Generating sdk_config file
	$(AT)java -jar $(CMSIS_CONFIG_TOOL) $(SDK_CONFIG_FILE)

# Format source code using uncrustify
format:
	@echo Formatting application source and header files
	$(AT)uncrustify -c uncrustify.cfg --replace --no-backup $(APP_SOURCES) $(APP_HEADERS)

# Display help
help:
	@echo "------------------------------ Makefile ------------------------------"
	@echo
	@echo "Options:"
	@echo "	clean:            Clean all object files."
	@echo "	erase:            Erase nRF5 device flash memory."
	@echo "	flash:            Program nRF5 device flash memory with the application."
	@echo "	flash_softdevice: Program nRF5 device flash memory with the chosen SoftDevice."
	@echo "	format:           Format .c/.h inside src/inc directories."
	@echo "	help:             Show this message."
	@echo "	prepare:          Generate GitHooks and VSCode configuration files."]
	@echo "	reset:            Reset nRF5 device."
	@echo "	sdk_config:       Generate SDK configuration file."
	@echo
	@echo "Current configurations:"
	@echo "	TARGET     := "$(TARGET)
	@echo "	SOFTDEVICE := "$(SOFTDEVICE)

###############################################################################
## VS Code files
##########################'#####################################################

VSCODE_FOLDER            := .vscode
VS_LAUNCH_FILE           := $(VSCODE_FOLDER)/launch.json
VS_C_CPP_PROPERTIES_FILE := $(VSCODE_FOLDER)/c_cpp_properties.json

NULL  :=
SPACE := $(NULL) #
COMMA := ,

define VS_LAUNCH
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "cortex-debug",
            "request": "launch",
            "servertype": "jlink",
            "cwd": "$${workspaceRoot}",
            "executable": "./$(OUTPUT_DIRECTORY)/$(TARGET).out",
            "name": "Cortex Debug (J-Link)",
            "device": "$(TARGET)",
            "interface": "swd",
            "runToMain": true,
            "rtos": "FreeRTOS",
        }
    ]
}
endef

define VS_CPP_PROPERTIES
{
    "configurations": [
        {
            "name": "ARM GCC Environment",
            "includePath": [
                "$(NRF5_SDK_PATH)/**"
            ],

            "defines": [
                $(subst -D,$(NULL),$(subst $(SPACE),$(COMMA),$(strip $(foreach def,$(C_DEFS),"$(def)"))))
            ],

            "compilerPath": "$${env:ARM_GCC_PATH}/arm-none-eabi-gcc",
            "cStandard": "c99",
            "cppStandard": "c++14",
            "intelliSenseMode": "clang-x64"
        }
    ],
    "version": 4
}
endef

export VS_LAUNCH
export VS_CPP_PROPERTIES

vs_files: $(VS_LAUNCH_FILE) $(VS_C_CPP_PROPERTIES_FILE)

$(VS_LAUNCH_FILE): config.mk Makefile | $(VSCODE_FOLDER)
	$(AT)echo "$$VS_LAUNCH" > $@

$(VS_C_CPP_PROPERTIES_FILE): config.mk Makefile | $(VSCODE_FOLDER)
	$(AT)echo "$$VS_CPP_PROPERTIES" > $@

$(VSCODE_FOLDER):
	$(AT)mkdir -p $@

# Prepare VS Code and githook files
prepare: $(VS_LAUNCH_FILE) $(VS_C_CPP_PROPERTIES_FILE)
	@echo "Linking githooks"
	$(AT)git config core.hooksPath .githooks

###############################################################################

# Include dependecy files for .h dependency detection
-include $(wildcard $(OUTPUT_DIRECTORY)/**/*.d)

.PHONY: \
	default \
	generate_release generate_dfu_package \
	flash flash_softdevice flash_release erase reset \
	sdk_config prepare format help \
	vs_files
