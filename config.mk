# File: config.mk
# Author: Gabriel Kim
# 11/2019

# Project information
PROJECT_NAME     := $(notdir $(CURDIR))
TARGET           := nRF52810_xxAA
OUTPUT_DIRECTORY := build

# Link descriptor file
LINKER_SCRIPT := $(PROJECT_NAME)-$(TARGET).ld

# SoftDevice
# SOFTDEVICE := S112

# Application Stack / Heap sizes
STACK_SIZE := 2048
HEAP_SIZE  := 2048

# Default values, can be set on the command line or here
DEBUG   ?= 1
PRETTY  ?= 1
VERBOSE ?= 0
