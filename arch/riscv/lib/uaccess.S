#include <linux/linkage.h>
#include <asm-generic/export.h>
#include <asm/asm.h>
#include <asm/csr.h>

	.macro fixup op reg addr lbl
100:
	\op \reg, \addr
	.section __ex_table,"a"
	.balign RISCV_SZPTR
	RISCV_PTR 100b, \lbl
	.previous
	.endm

ENTRY(__asm_copy_to_user)
ENTRY(__asm_copy_from_user)

	/* Enable access to user memory */
	li t6, SR_SUM
	csrs CSR_STATUS, t6

	move t5, a0  /* Preserve return value */

	/* Defer to byte-oriented copy for small sizes */
	sltiu a3, a2, 64
	bnez a3, 4f
	/* Use word-oriented copy only if low-order bits match */
	andi a3, t5, SZREG-1
	andi a4, a1, SZREG-1
	bne a3, a4, 4f

	beqz a3, 2f  /* Skip if already aligned */
	/*
	 * Round to nearest double word-aligned address
	 * greater than or equal to start address
	 */
	andi a3, a1, ~(SZREG-1)
	addi a3, a3, SZREG
	/* Handle initial misalignment */
	sub a4, a3, a1
1:
	lb a5, 0(a1)
	addi a1, a1, 1
	sb a5, 0(t5)
	addi t5, t5, 1
	bltu a1, a3, 1b
	sub a2, a2, a4  /* Update count */

2:
	andi a4, a2, ~((8*SZREG)-1)
	beqz a4, 4f
	add a3, a1, a4
3:
	fixup REG_L a4,       0(a1), 10f
	fixup REG_L a5,   SZREG(a1), 10f
	fixup REG_L a6, 2*SZREG(a1), 10f
	fixup REG_L a7, 3*SZREG(a1), 10f
	fixup REG_L t0, 4*SZREG(a1), 10f
	fixup REG_L t1, 5*SZREG(a1), 10f
	fixup REG_L t2, 6*SZREG(a1), 10f
	fixup REG_L t3, 7*SZREG(a1), 10f
	fixup REG_S a4,       0(t5), 10f
	fixup REG_S a5,   SZREG(t5), 10f
	fixup REG_S a6, 2*SZREG(t5), 10f
	fixup REG_S a7, 3*SZREG(t5), 10f
	fixup REG_S t0, 4*SZREG(t5), 10f
	fixup REG_S t1, 5*SZREG(t5), 10f
	fixup REG_S t2, 6*SZREG(t5), 10f
	fixup REG_S t3, 7*SZREG(t5), 10f
	addi a1, a1, 8*SZREG
	addi t5, t5, 8*SZREG
	bltu a1, a3, 3b
	andi a2, a2, (8*SZREG)-1  /* Update count */

4:
	/* Handle trailing misalignment */
	beqz a2, 6f
	add a3, a1, a2

	/* Use word-oriented copy if co-aligned to word boundary */
	or a5, a1, t5
	or a5, a5, a3
	andi a5, a5, 3
	bnez a5, 5f
7:
	fixup lw a4, 0(a1), 10f
	addi a1, a1, 4
	fixup sw a4, 0(t5), 10f
	addi t5, t5, 4
	bltu a1, a3, 7b

	j 6f

5:
	fixup lb a4, 0(a1), 10f
	addi a1, a1, 1
	fixup sb a4, 0(t5), 10f
	addi t5, t5, 1
	bltu a1, a3, 5b

6:
	/* Disable access to user memory */
	csrc CSR_STATUS, t6
	li a0, 0
	ret
ENDPROC(__asm_copy_to_user)
ENDPROC(__asm_copy_from_user)
EXPORT_SYMBOL(__asm_copy_to_user)
EXPORT_SYMBOL(__asm_copy_from_user)


ENTRY(__clear_user)

	/* Enable access to user memory */
	li t6, SR_SUM
	csrs CSR_STATUS, t6

	add a3, a0, a1
	addi t0, a0, SZREG-1
	andi t1, a3, ~(SZREG-1)
	andi t0, t0, ~(SZREG-1)
	/*
	 * a3: terminal address of target region
	 * t0: lowest doubleword-aligned address in target region
	 * t1: highest doubleword-aligned address in target region
	 */
	bgeu t0, t1, 2f
	bltu a0, t0, 4f
1:
	fixup REG_S, zero, (a0), 11f
	addi a0, a0, SZREG
	bltu a0, t1, 1b
2:
	bltu a0, a3, 5f

3:
	/* Disable access to user memory */
	csrc CSR_STATUS, t6
	li a0, 0
	ret
4: /* Edge case: unalignment */
	fixup sb, zero, (a0), 11f
	addi a0, a0, 1
	bltu a0, t0, 4b
	j 1b
5: /* Edge case: remainder */
	fixup sb, zero, (a0), 11f
	addi a0, a0, 1
	bltu a0, a3, 5b
	j 3b
ENDPROC(__clear_user)
EXPORT_SYMBOL(__clear_user)

	.section .fixup,"ax"
	.balign 4
	/* Fixup code for __copy_user(10) and __clear_user(11) */
10:
	/* Disable access to user memory */
	csrs CSR_STATUS, t6
	mv a0, a2
	ret
11:
	csrs CSR_STATUS, t6
	mv a0, a1
	ret
	.previous
