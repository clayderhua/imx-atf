/*
 * Copyright (c) 2018-2020, ARM Limited and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

#include <arch.h>
#include <asm_macros.S>
#include <console_macros.S>
#include <assert_macros.S>
#include "imx_uart.h"

#define URXD  0x0  /* Receiver Register */
#define UTXD  0x40 /* Transmitter Register */
#define USR2  0x98 /* UART Status Register 2 */
#define UTS   0xb4 /* UART Test Register (mx31) */
#define  URXD_RX_DATA    (0xFF)
#define FCR   0x0a01
#define BIR   0xf
#define BMR   0x68
#define CR1   0x1
#define CR2   0x4027

	.globl	console_imx_uart_register
	.globl	console_imx_uart_init
	.globl	console_imx_uart_putc
	.globl	console_imx_uart_getc
	.globl	console_imx_uart_flush

func console_imx_uart_register
	mov	x7, x30
	mov	x6, x3
	cbz	x6, register_fail
	str	x0, [x6, #CONSOLE_T_BASE]

	bl	console_imx_uart_init
	cbz	x0, register_fail

	mov	x0, x6
	mov	x30, x7
	finish_console_register imx_uart putc=1, getc=ENABLE_CONSOLE_GETC, flush=1

register_fail:
	ret	x7
endfunc console_imx_uart_register

func console_imx_uart_init
	mov     w5, #FCR
	str     w5, [x0, #0x90]
	mov     w5, #BIR
	str     w5, [x0, #0xa4]
	mov     w5, #BMR
	str     w5, [x0, #0xa8]
	mov     w5, #CR2
	str     w5, [x0, #0x84]
	mov     w5, #CR1
	str     w5, [x0, #0x80]

	ldr     w5, [x0, #0x88]
	orr     x5, x5, #0x4
	str     w5, [x0, #0x88]
	ret
endfunc console_imx_uart_init

func console_imx_uart_putc
	ldr	x1, [x1, #CONSOLE_T_BASE]
	cbz	x1, putc_error

	/* Prepare '\r' to '\n' */
	cmp	w0, #0xA
	b.ne	2f
1:
	/* Check if the transmit FIFO is full */
	ldr	w2, [x1, #UTS]
	tbnz	w2, #4, 1b
	mov	w2, #0xD
	str	w2, [x1, #UTXD]
2:
	/* Check if the transmit FIFO is full */
	ldr	w2, [x1, #UTS]
	tbnz	w2, #4, 2b
	str	w0, [x1, #UTXD]
	ret
putc_error:
	mov	w0, #-1
	ret
endfunc console_imx_uart_putc

func console_imx_uart_getc
	ldr	x0, [x0, #CONSOLE_T_BASE]
	cbz	x0, getc_error
1:
	ldr	w1, [x0, #UTS]
	tbnz	w1, #5, 1b

	ldr	w1, [x0, #URXD]
	and	w0, w1, #URXD_RX_DATA

	ret
getc_error:
	mov	w0, #-1
	ret
endfunc console_imx_uart_getc

func console_imx_uart_flush
	ldr	x0, [x0, #CONSOLE_T_BASE]
	cbz	x0, flush_exit
1:
	/* Wait for the transmit complete bit */
	ldr	w1, [x0, #USR2]
	tbz	w1, #3, 1b

flush_exit:
	ret
endfunc console_imx_uart_flush
