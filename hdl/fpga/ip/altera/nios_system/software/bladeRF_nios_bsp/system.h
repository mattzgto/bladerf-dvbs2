/*
 * system.h - SOPC Builder system and BSP software package information
 *
 * Machine generated for CPU 'nios2' in SOPC Builder design 'nios_system'
 * SOPC Builder design path: ../../nios_system.sopcinfo
 *
 * Generated: Mon Jun 26 14:10:02 EDT 2017
 */

/*
 * DO NOT MODIFY THIS FILE
 *
 * Changing this file will have subtle consequences
 * which will almost certainly lead to a nonfunctioning
 * system. If you do modify this file, be aware that your
 * changes will be overwritten and lost when this file
 * is generated again.
 *
 * DO NOT MODIFY THIS FILE
 */

/*
 * License Agreement
 *
 * Copyright (c) 2008
 * Altera Corporation, San Jose, California, USA.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * This agreement shall be governed in all respects by the laws of the State
 * of California and by the laws of the United States of America.
 */

#ifndef __SYSTEM_H_
#define __SYSTEM_H_

/* Include definitions from linker script generator */
#include "linker.h"


/*
 * CPU configuration
 *
 */

#define ALT_CPU_ARCHITECTURE "altera_nios2_gen2"
#define ALT_CPU_BIG_ENDIAN 0
#define ALT_CPU_BREAK_ADDR 0x00008820
#define ALT_CPU_CPU_ARCH_NIOS2_R1
#define ALT_CPU_CPU_FREQ 80000000u
#define ALT_CPU_CPU_ID_SIZE 1
#define ALT_CPU_CPU_ID_VALUE 0x00000000
#define ALT_CPU_CPU_IMPLEMENTATION "tiny"
#define ALT_CPU_DATA_ADDR_WIDTH 0x10
#define ALT_CPU_DCACHE_LINE_SIZE 0
#define ALT_CPU_DCACHE_LINE_SIZE_LOG2 0
#define ALT_CPU_DCACHE_SIZE 0
#define ALT_CPU_EXCEPTION_ADDR 0x00004020
#define ALT_CPU_FLASH_ACCELERATOR_LINES 0
#define ALT_CPU_FLASH_ACCELERATOR_LINE_SIZE 0
#define ALT_CPU_FLUSHDA_SUPPORTED
#define ALT_CPU_FREQ 80000000
#define ALT_CPU_HARDWARE_DIVIDE_PRESENT 0
#define ALT_CPU_HARDWARE_MULTIPLY_PRESENT 0
#define ALT_CPU_HARDWARE_MULX_PRESENT 0
#define ALT_CPU_HAS_DEBUG_CORE 1
#define ALT_CPU_HAS_DEBUG_STUB
#define ALT_CPU_HAS_ILLEGAL_INSTRUCTION_EXCEPTION
#define ALT_CPU_HAS_JMPI_INSTRUCTION
#define ALT_CPU_ICACHE_LINE_SIZE 0
#define ALT_CPU_ICACHE_LINE_SIZE_LOG2 0
#define ALT_CPU_ICACHE_SIZE 0
#define ALT_CPU_INST_ADDR_WIDTH 0x10
#define ALT_CPU_NAME "nios2"
#define ALT_CPU_OCI_VERSION 1
#define ALT_CPU_RESET_ADDR 0x00004000


/*
 * CPU configuration (with legacy prefix - don't use these anymore)
 *
 */

#define NIOS2_BIG_ENDIAN 0
#define NIOS2_BREAK_ADDR 0x00008820
#define NIOS2_CPU_ARCH_NIOS2_R1
#define NIOS2_CPU_FREQ 80000000u
#define NIOS2_CPU_ID_SIZE 1
#define NIOS2_CPU_ID_VALUE 0x00000000
#define NIOS2_CPU_IMPLEMENTATION "tiny"
#define NIOS2_DATA_ADDR_WIDTH 0x10
#define NIOS2_DCACHE_LINE_SIZE 0
#define NIOS2_DCACHE_LINE_SIZE_LOG2 0
#define NIOS2_DCACHE_SIZE 0
#define NIOS2_EXCEPTION_ADDR 0x00004020
#define NIOS2_FLASH_ACCELERATOR_LINES 0
#define NIOS2_FLASH_ACCELERATOR_LINE_SIZE 0
#define NIOS2_FLUSHDA_SUPPORTED
#define NIOS2_HARDWARE_DIVIDE_PRESENT 0
#define NIOS2_HARDWARE_MULTIPLY_PRESENT 0
#define NIOS2_HARDWARE_MULX_PRESENT 0
#define NIOS2_HAS_DEBUG_CORE 1
#define NIOS2_HAS_DEBUG_STUB
#define NIOS2_HAS_ILLEGAL_INSTRUCTION_EXCEPTION
#define NIOS2_HAS_JMPI_INSTRUCTION
#define NIOS2_ICACHE_LINE_SIZE 0
#define NIOS2_ICACHE_LINE_SIZE_LOG2 0
#define NIOS2_ICACHE_SIZE 0
#define NIOS2_INST_ADDR_WIDTH 0x10
#define NIOS2_OCI_VERSION 1
#define NIOS2_RESET_ADDR 0x00004000


/*
 * Define for each module class mastered by the CPU
 *
 */

#define __ALTERA_AVALON_JTAG_UART
#define __ALTERA_AVALON_ONCHIP_MEMORY2
#define __ALTERA_AVALON_PIO
#define __ALTERA_AVALON_SPI
#define __ALTERA_NIOS2_GEN2
#define __BLADERF_OC_I2C_MASTER
#define __COMMAND_UART
#define __LMS6_SPI_CONTROLLER
#define __TIME_TAMER
#define __VCTCXO_TAMER


/*
 * System configuration
 *
 */

#define ALT_DEVICE_FAMILY "Cyclone IV E"
#define ALT_ENHANCED_INTERRUPT_API_PRESENT
#define ALT_IRQ_BASE NULL
#define ALT_LOG_PORT "/dev/null"
#define ALT_LOG_PORT_BASE 0x0
#define ALT_LOG_PORT_DEV null
#define ALT_LOG_PORT_TYPE ""
#define ALT_NUM_EXTERNAL_INTERRUPT_CONTROLLERS 0
#define ALT_NUM_INTERNAL_INTERRUPT_CONTROLLERS 1
#define ALT_NUM_INTERRUPT_CONTROLLERS 1
#define ALT_STDERR "/dev/jtag_uart"
#define ALT_STDERR_BASE 0x9100
#define ALT_STDERR_DEV jtag_uart
#define ALT_STDERR_IS_JTAG_UART
#define ALT_STDERR_PRESENT
#define ALT_STDERR_TYPE "altera_avalon_jtag_uart"
#define ALT_STDIN "/dev/jtag_uart"
#define ALT_STDIN_BASE 0x9100
#define ALT_STDIN_DEV jtag_uart
#define ALT_STDIN_IS_JTAG_UART
#define ALT_STDIN_PRESENT
#define ALT_STDIN_TYPE "altera_avalon_jtag_uart"
#define ALT_STDOUT "/dev/jtag_uart"
#define ALT_STDOUT_BASE 0x9100
#define ALT_STDOUT_DEV jtag_uart
#define ALT_STDOUT_IS_JTAG_UART
#define ALT_STDOUT_PRESENT
#define ALT_STDOUT_TYPE "altera_avalon_jtag_uart"
#define ALT_SYSTEM_NAME "nios_system"


/*
 * command_uart configuration
 *
 */

#define ALT_MODULE_CLASS_command_uart command_uart
#define COMMAND_UART_BASE 0x9120
#define COMMAND_UART_IRQ 7
#define COMMAND_UART_IRQ_INTERRUPT_CONTROLLER_ID 0
#define COMMAND_UART_NAME "/dev/command_uart"
#define COMMAND_UART_SPAN 32
#define COMMAND_UART_TYPE "command_uart"


/*
 * control configuration
 *
 */

#define ALT_MODULE_CLASS_control altera_avalon_pio
#define CONTROL_BASE 0x9040
#define CONTROL_BIT_CLEARING_EDGE_REGISTER 0
#define CONTROL_BIT_MODIFYING_OUTPUT_REGISTER 1
#define CONTROL_CAPTURE 0
#define CONTROL_DATA_WIDTH 32
#define CONTROL_DO_TEST_BENCH_WIRING 0
#define CONTROL_DRIVEN_SIM_VALUE 0
#define CONTROL_EDGE_TYPE "NONE"
#define CONTROL_FREQ 80000000
#define CONTROL_HAS_IN 0
#define CONTROL_HAS_OUT 1
#define CONTROL_HAS_TRI 0
#define CONTROL_IRQ -1
#define CONTROL_IRQ_INTERRUPT_CONTROLLER_ID -1
#define CONTROL_IRQ_TYPE "NONE"
#define CONTROL_NAME "/dev/control"
#define CONTROL_RESET_VALUE 0
#define CONTROL_SPAN 32
#define CONTROL_TYPE "altera_avalon_pio"


/*
 * hal configuration
 *
 */

#define ALT_MAX_FD 4
#define ALT_SYS_CLK none
#define ALT_TIMESTAMP_CLK none


/*
 * iq_corr_rx_phase_gain configuration
 *
 */

#define ALT_MODULE_CLASS_iq_corr_rx_phase_gain altera_avalon_pio
#define IQ_CORR_RX_PHASE_GAIN_BASE 0x90d0
#define IQ_CORR_RX_PHASE_GAIN_BIT_CLEARING_EDGE_REGISTER 0
#define IQ_CORR_RX_PHASE_GAIN_BIT_MODIFYING_OUTPUT_REGISTER 0
#define IQ_CORR_RX_PHASE_GAIN_CAPTURE 0
#define IQ_CORR_RX_PHASE_GAIN_DATA_WIDTH 32
#define IQ_CORR_RX_PHASE_GAIN_DO_TEST_BENCH_WIRING 0
#define IQ_CORR_RX_PHASE_GAIN_DRIVEN_SIM_VALUE 0
#define IQ_CORR_RX_PHASE_GAIN_EDGE_TYPE "NONE"
#define IQ_CORR_RX_PHASE_GAIN_FREQ 80000000
#define IQ_CORR_RX_PHASE_GAIN_HAS_IN 0
#define IQ_CORR_RX_PHASE_GAIN_HAS_OUT 1
#define IQ_CORR_RX_PHASE_GAIN_HAS_TRI 0
#define IQ_CORR_RX_PHASE_GAIN_IRQ -1
#define IQ_CORR_RX_PHASE_GAIN_IRQ_INTERRUPT_CONTROLLER_ID -1
#define IQ_CORR_RX_PHASE_GAIN_IRQ_TYPE "NONE"
#define IQ_CORR_RX_PHASE_GAIN_NAME "/dev/iq_corr_rx_phase_gain"
#define IQ_CORR_RX_PHASE_GAIN_RESET_VALUE 0
#define IQ_CORR_RX_PHASE_GAIN_SPAN 16
#define IQ_CORR_RX_PHASE_GAIN_TYPE "altera_avalon_pio"


/*
 * iq_corr_tx_phase_gain configuration
 *
 */

#define ALT_MODULE_CLASS_iq_corr_tx_phase_gain altera_avalon_pio
#define IQ_CORR_TX_PHASE_GAIN_BASE 0x90c0
#define IQ_CORR_TX_PHASE_GAIN_BIT_CLEARING_EDGE_REGISTER 0
#define IQ_CORR_TX_PHASE_GAIN_BIT_MODIFYING_OUTPUT_REGISTER 0
#define IQ_CORR_TX_PHASE_GAIN_CAPTURE 0
#define IQ_CORR_TX_PHASE_GAIN_DATA_WIDTH 32
#define IQ_CORR_TX_PHASE_GAIN_DO_TEST_BENCH_WIRING 0
#define IQ_CORR_TX_PHASE_GAIN_DRIVEN_SIM_VALUE 0
#define IQ_CORR_TX_PHASE_GAIN_EDGE_TYPE "NONE"
#define IQ_CORR_TX_PHASE_GAIN_FREQ 80000000
#define IQ_CORR_TX_PHASE_GAIN_HAS_IN 0
#define IQ_CORR_TX_PHASE_GAIN_HAS_OUT 1
#define IQ_CORR_TX_PHASE_GAIN_HAS_TRI 0
#define IQ_CORR_TX_PHASE_GAIN_IRQ -1
#define IQ_CORR_TX_PHASE_GAIN_IRQ_INTERRUPT_CONTROLLER_ID -1
#define IQ_CORR_TX_PHASE_GAIN_IRQ_TYPE "NONE"
#define IQ_CORR_TX_PHASE_GAIN_NAME "/dev/iq_corr_tx_phase_gain"
#define IQ_CORR_TX_PHASE_GAIN_RESET_VALUE 1
#define IQ_CORR_TX_PHASE_GAIN_SPAN 16
#define IQ_CORR_TX_PHASE_GAIN_TYPE "altera_avalon_pio"


/*
 * jtag_uart configuration
 *
 */

#define ALT_MODULE_CLASS_jtag_uart altera_avalon_jtag_uart
#define JTAG_UART_BASE 0x9100
#define JTAG_UART_IRQ 1
#define JTAG_UART_IRQ_INTERRUPT_CONTROLLER_ID 0
#define JTAG_UART_NAME "/dev/jtag_uart"
#define JTAG_UART_READ_DEPTH 64
#define JTAG_UART_READ_THRESHOLD 8
#define JTAG_UART_SPAN 8
#define JTAG_UART_TYPE "altera_avalon_jtag_uart"
#define JTAG_UART_WRITE_DEPTH 64
#define JTAG_UART_WRITE_THRESHOLD 8


/*
 * lms_spi configuration
 *
 */

#define ALT_MODULE_CLASS_lms_spi lms6_spi_controller
#define LMS_SPI_BASE 0x9200
#define LMS_SPI_IRQ -1
#define LMS_SPI_IRQ_INTERRUPT_CONTROLLER_ID -1
#define LMS_SPI_NAME "/dev/lms_spi"
#define LMS_SPI_SPAN 256
#define LMS_SPI_TYPE "lms6_spi_controller"


/*
 * opencores_i2c configuration
 *
 */

#define ALT_MODULE_CLASS_opencores_i2c bladerf_oc_i2c_master
#define OPENCORES_I2C_BASE 0x90f0
#define OPENCORES_I2C_IRQ 5
#define OPENCORES_I2C_IRQ_INTERRUPT_CONTROLLER_ID 0
#define OPENCORES_I2C_NAME "/dev/opencores_i2c"
#define OPENCORES_I2C_SPAN 8
#define OPENCORES_I2C_TYPE "bladerf_oc_i2c_master"


/*
 * peripheral_spi configuration
 *
 */

#define ALT_MODULE_CLASS_peripheral_spi altera_avalon_spi
#define PERIPHERAL_SPI_BASE 0x9060
#define PERIPHERAL_SPI_CLOCKMULT 1
#define PERIPHERAL_SPI_CLOCKPHASE 1
#define PERIPHERAL_SPI_CLOCKPOLARITY 1
#define PERIPHERAL_SPI_CLOCKUNITS "Hz"
#define PERIPHERAL_SPI_DATABITS 8
#define PERIPHERAL_SPI_DATAWIDTH 16
#define PERIPHERAL_SPI_DELAYMULT "1.0E-9"
#define PERIPHERAL_SPI_DELAYUNITS "ns"
#define PERIPHERAL_SPI_EXTRADELAY 0
#define PERIPHERAL_SPI_INSERT_SYNC 0
#define PERIPHERAL_SPI_IRQ 4
#define PERIPHERAL_SPI_IRQ_INTERRUPT_CONTROLLER_ID 0
#define PERIPHERAL_SPI_ISMASTER 1
#define PERIPHERAL_SPI_LSBFIRST 0
#define PERIPHERAL_SPI_NAME "/dev/peripheral_spi"
#define PERIPHERAL_SPI_NUMSLAVES 2
#define PERIPHERAL_SPI_PREFIX "spi_"
#define PERIPHERAL_SPI_SPAN 32
#define PERIPHERAL_SPI_SYNC_REG_DEPTH 2
#define PERIPHERAL_SPI_TARGETCLOCK 9600000u
#define PERIPHERAL_SPI_TARGETSSDELAY "0.0"
#define PERIPHERAL_SPI_TYPE "altera_avalon_spi"


/*
 * ram configuration
 *
 */

#define ALT_MODULE_CLASS_ram altera_avalon_onchip_memory2
#define RAM_ALLOW_IN_SYSTEM_MEMORY_CONTENT_EDITOR 1
#define RAM_ALLOW_MRAM_SIM_CONTENTS_ONLY_FILE 0
#define RAM_BASE 0x4000
#define RAM_CONTENTS_INFO ""
#define RAM_DUAL_PORT 0
#define RAM_GUI_RAM_BLOCK_TYPE "AUTO"
#define RAM_INIT_CONTENTS_FILE "nios_system_ram"
#define RAM_INIT_MEM_CONTENT 1
#define RAM_INSTANCE_ID "MED"
#define RAM_IRQ -1
#define RAM_IRQ_INTERRUPT_CONTROLLER_ID -1
#define RAM_NAME "/dev/ram"
#define RAM_NON_DEFAULT_INIT_FILE_ENABLED 0
#define RAM_RAM_BLOCK_TYPE "AUTO"
#define RAM_READ_DURING_WRITE_MODE "DONT_CARE"
#define RAM_SINGLE_CLOCK_OP 0
#define RAM_SIZE_MULTIPLE 1
#define RAM_SIZE_VALUE 16384
#define RAM_SPAN 16384
#define RAM_TYPE "altera_avalon_onchip_memory2"
#define RAM_WRITABLE 1


/*
 * rx_tamer configuration
 *
 */

#define ALT_MODULE_CLASS_rx_tamer time_tamer
#define RX_TAMER_BASE 0x9160
#define RX_TAMER_IRQ 3
#define RX_TAMER_IRQ_INTERRUPT_CONTROLLER_ID 0
#define RX_TAMER_NAME "/dev/rx_tamer"
#define RX_TAMER_SPAN 32
#define RX_TAMER_TYPE "time_tamer"


/*
 * rx_trigger_ctl configuration
 *
 */

#define ALT_MODULE_CLASS_rx_trigger_ctl altera_avalon_pio
#define RX_TRIGGER_CTL_BASE 0x9400
#define RX_TRIGGER_CTL_BIT_CLEARING_EDGE_REGISTER 0
#define RX_TRIGGER_CTL_BIT_MODIFYING_OUTPUT_REGISTER 1
#define RX_TRIGGER_CTL_CAPTURE 0
#define RX_TRIGGER_CTL_DATA_WIDTH 8
#define RX_TRIGGER_CTL_DO_TEST_BENCH_WIRING 0
#define RX_TRIGGER_CTL_DRIVEN_SIM_VALUE 0
#define RX_TRIGGER_CTL_EDGE_TYPE "NONE"
#define RX_TRIGGER_CTL_FREQ 80000000
#define RX_TRIGGER_CTL_HAS_IN 1
#define RX_TRIGGER_CTL_HAS_OUT 1
#define RX_TRIGGER_CTL_HAS_TRI 0
#define RX_TRIGGER_CTL_IRQ -1
#define RX_TRIGGER_CTL_IRQ_INTERRUPT_CONTROLLER_ID -1
#define RX_TRIGGER_CTL_IRQ_TYPE "NONE"
#define RX_TRIGGER_CTL_NAME "/dev/rx_trigger_ctl"
#define RX_TRIGGER_CTL_RESET_VALUE 0
#define RX_TRIGGER_CTL_SPAN 32
#define RX_TRIGGER_CTL_TYPE "altera_avalon_pio"


/*
 * tx_tamer configuration
 *
 */

#define ALT_MODULE_CLASS_tx_tamer time_tamer
#define TX_TAMER_BASE 0x9140
#define TX_TAMER_IRQ 2
#define TX_TAMER_IRQ_INTERRUPT_CONTROLLER_ID 0
#define TX_TAMER_NAME "/dev/tx_tamer"
#define TX_TAMER_SPAN 32
#define TX_TAMER_TYPE "time_tamer"


/*
 * tx_trigger_ctl configuration
 *
 */

#define ALT_MODULE_CLASS_tx_trigger_ctl altera_avalon_pio
#define TX_TRIGGER_CTL_BASE 0x9420
#define TX_TRIGGER_CTL_BIT_CLEARING_EDGE_REGISTER 0
#define TX_TRIGGER_CTL_BIT_MODIFYING_OUTPUT_REGISTER 1
#define TX_TRIGGER_CTL_CAPTURE 0
#define TX_TRIGGER_CTL_DATA_WIDTH 8
#define TX_TRIGGER_CTL_DO_TEST_BENCH_WIRING 0
#define TX_TRIGGER_CTL_DRIVEN_SIM_VALUE 0
#define TX_TRIGGER_CTL_EDGE_TYPE "NONE"
#define TX_TRIGGER_CTL_FREQ 80000000
#define TX_TRIGGER_CTL_HAS_IN 1
#define TX_TRIGGER_CTL_HAS_OUT 1
#define TX_TRIGGER_CTL_HAS_TRI 0
#define TX_TRIGGER_CTL_IRQ -1
#define TX_TRIGGER_CTL_IRQ_INTERRUPT_CONTROLLER_ID -1
#define TX_TRIGGER_CTL_IRQ_TYPE "NONE"
#define TX_TRIGGER_CTL_NAME "/dev/tx_trigger_ctl"
#define TX_TRIGGER_CTL_RESET_VALUE 0
#define TX_TRIGGER_CTL_SPAN 32
#define TX_TRIGGER_CTL_TYPE "altera_avalon_pio"


/*
 * vctcxo_tamer_0 configuration
 *
 */

#define ALT_MODULE_CLASS_vctcxo_tamer_0 vctcxo_tamer
#define VCTCXO_TAMER_0_BASE 0x9300
#define VCTCXO_TAMER_0_IRQ 0
#define VCTCXO_TAMER_0_IRQ_INTERRUPT_CONTROLLER_ID 0
#define VCTCXO_TAMER_0_NAME "/dev/vctcxo_tamer_0"
#define VCTCXO_TAMER_0_SPAN 256
#define VCTCXO_TAMER_0_TYPE "vctcxo_tamer"


/*
 * xb_gpio configuration
 *
 */

#define ALT_MODULE_CLASS_xb_gpio altera_avalon_pio
#define XB_GPIO_BASE 0x90b0
#define XB_GPIO_BIT_CLEARING_EDGE_REGISTER 0
#define XB_GPIO_BIT_MODIFYING_OUTPUT_REGISTER 0
#define XB_GPIO_CAPTURE 0
#define XB_GPIO_DATA_WIDTH 32
#define XB_GPIO_DO_TEST_BENCH_WIRING 0
#define XB_GPIO_DRIVEN_SIM_VALUE 0
#define XB_GPIO_EDGE_TYPE "NONE"
#define XB_GPIO_FREQ 80000000
#define XB_GPIO_HAS_IN 1
#define XB_GPIO_HAS_OUT 1
#define XB_GPIO_HAS_TRI 0
#define XB_GPIO_IRQ -1
#define XB_GPIO_IRQ_INTERRUPT_CONTROLLER_ID -1
#define XB_GPIO_IRQ_TYPE "NONE"
#define XB_GPIO_NAME "/dev/xb_gpio"
#define XB_GPIO_RESET_VALUE 0
#define XB_GPIO_SPAN 16
#define XB_GPIO_TYPE "altera_avalon_pio"


/*
 * xb_gpio_dir configuration
 *
 */

#define ALT_MODULE_CLASS_xb_gpio_dir altera_avalon_pio
#define XB_GPIO_DIR_BASE 0x90a0
#define XB_GPIO_DIR_BIT_CLEARING_EDGE_REGISTER 0
#define XB_GPIO_DIR_BIT_MODIFYING_OUTPUT_REGISTER 0
#define XB_GPIO_DIR_CAPTURE 0
#define XB_GPIO_DIR_DATA_WIDTH 32
#define XB_GPIO_DIR_DO_TEST_BENCH_WIRING 0
#define XB_GPIO_DIR_DRIVEN_SIM_VALUE 0
#define XB_GPIO_DIR_EDGE_TYPE "NONE"
#define XB_GPIO_DIR_FREQ 80000000
#define XB_GPIO_DIR_HAS_IN 0
#define XB_GPIO_DIR_HAS_OUT 1
#define XB_GPIO_DIR_HAS_TRI 0
#define XB_GPIO_DIR_IRQ -1
#define XB_GPIO_DIR_IRQ_INTERRUPT_CONTROLLER_ID -1
#define XB_GPIO_DIR_IRQ_TYPE "NONE"
#define XB_GPIO_DIR_NAME "/dev/xb_gpio_dir"
#define XB_GPIO_DIR_RESET_VALUE 0
#define XB_GPIO_DIR_SPAN 16
#define XB_GPIO_DIR_TYPE "altera_avalon_pio"

#endif /* __SYSTEM_H_ */
