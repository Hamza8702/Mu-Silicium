//  Copyright (c) 2011 - 2020, Arm Limited. All rights reserved.
//  Modified for EL2/KVM Support by Hamza - Stable English Version
//  SPDX-License-Identifier: BSD-2-Clause-Patent

#include <AsmMacroLib.h>

// Definitions for system registers
.set CTRL_SPAN_BIT, (1 << 23)
.set HCR_EL2_E2H,   (1 << 34)  /* Virtualization Host Extensions Bit */
.set HCR_EL2_RW,    (1 << 31)  /* Execution state for EL1 is AArch64 */

.text
.align 3

ASM_FUNC (_ModuleEntryPoint)
  // Standard SoC specific initialization
  bl   ASM_PFX (PlatformAssemblyInit)

  // Read Multiprocessor Affinity Register
  bl   ASM_PFX (ArmReadMpidr)
  mov  x10, x0

  // Basic CPU state cleanup
  bl   ASM_PFX (ArmDisableInterrupts)
  bl   ASM_PFX (ArmDisableCachesAndMmu)
  bl   ASM_PFX (ArmInvalidateInstructionCache)
  bl   ASM_PFX (ArmInvalidateTlb)

  // Check current Exception Level (EL)
  mrs  x0, CurrentEL
  lsr  x0, x0, #2
  cmp  x0, #2
  b.ne SetupEL1

EnableEL2Config:
  // Configure HCR_EL2: Set RW=1 for AArch64 EL1
  mrs  x0, hcr_el2
  orr  x0, x0, #HCR_EL2_RW
#if (FixedPcdGet32 (PcdEnableVHE) == 1)
  orr  x0, x0, #HCR_EL2_E2H
#endif
  msr  hcr_el2, x0
  isb

  // Initialize SCTLR_EL2 to a safe value (MMU disabled, I-Cache potentially enabled)
  ldr  x0, =0x30c50830
  msr  sctlr_el2, x0

  // Untrap VFP/SIMD: Avoiding 'xzr' to prevent "System Destroyed" on Qualcomm
  mrs  x0, cptr_el2
  bic  x0, x0, #(1 << 20) // Clear TFP bit (Trap Floating Point)
  msr  cptr_el2, x0
  b    SetupCoreStack

SetupEL1:
  mrs  x0, sctlr_el1
  orr  x0, x0, #CTRL_SPAN_BIT
  msr  sctlr_el1, x0

  mrs  x0, cpacr_el1
  orr  x0, x0, #0x300000
  msr  cpacr_el1, x0

SetupCoreStack:
  // Setup Stack Pointer for the current EL
  ldr  x0, =FixedPcdGet32 (PcdPrePiStackBase)
  ldr  x1, =FixedPcdGet32 (PcdPrePiStackSize)
  add  x2, x0, x1
  mov  sp, x2

  // Clear the stack area
  mov  x3, x0
ClearStackLoop:
  stp  xzr, xzr, [x3], #16
  cmp  x3, x2
  b.lt ClearStackLoop

EnableCaches:
  bl   ASM_PFX (ArmEnableInstructionCache)
  bl   ASM_PFX (ArmEnableDataCache)

JumpToC:
  mov  x0, x10
  ldr  x4, =ASM_PFX (CEntryPoint)
  mov  x29, xzr
  blr  x4

NeverReturn:
  b  NeverReturn


