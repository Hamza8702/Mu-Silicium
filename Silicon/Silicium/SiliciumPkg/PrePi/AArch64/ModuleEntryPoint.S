//  Copyright (c) 2011 - 2020, Arm Limited. All rights reserved.
//  Modified for EL2/KVM Support by Hamza
//  Target: Xiaomi Miatoll (Snapdragon 720G)
//  SPDX-License-Identifier: BSD-2-Clause-Patent

#include <AsmMacroLib.h>

// Register Bit Definitions
.set CTRL_SPAN_BIT, (1 << 23)
.set HCR_EL2_RW,    (1 << 31)  /* EL1 Execution state is AArch64 */
.set CPTR_EL2_RES1, 0x33ff     /* Safe architectural default for CPTR_EL2 */

.text
.align 3

ASM_FUNC (_ModuleEntryPoint)
  // 1. Low-level platform initialization
  bl   ASM_PFX (PlatformAssemblyInit)

  // 2. Save MPIDR and cleanup CPU state
  bl   ASM_PFX (ArmReadMpidr)
  mov  x10, x0
  bl   ASM_PFX (ArmDisableInterrupts)
  bl   ASM_PFX (ArmDisableCachesAndMmu)
  bl   ASM_PFX (ArmInvalidateInstructionCache)
  bl   ASM_PFX (ArmInvalidateTlb)

  // 3. Check current Exception Level (EL)
  mrs  x0, CurrentEL
  lsr  x0, x0, #2
  cmp  x0, #2
  b.eq EnableEL2Config // Already in EL2, proceed to config

  // 4. EL1 to EL2 Transition Logic
  // Note: Your custom EL1->EL2 switch code should be executed here.
  // We ensure EL2 registers are in a known state before switching.
  ldr  x0, =0x30c50830 // Safe SCTLR_EL2 value (MMU off)
  msr  sctlr_el2, x0
  isb

EnableEL2Config:
  // 5. Configure HCR_EL2: Set RW=1 for AArch64 EL1
  mrs  x0, hcr_el2
  orr  x0, x0, #HCR_EL2_RW
  msr  hcr_el2, x0
  isb

  // 6. Setup Traps and Floating Point (CPTR_EL2)
  // Using RES1 bits to satisfy Qualcomm's strict EL3/TrustZone checks
  ldr  x0, =CPTR_EL2_RES1
  msr  cptr_el2, x0
  isb
  b    SetupCoreStack

SetupEL1:
  // Fallback for EL1 (Should not be reached if transition is successful)
  mrs  x0, sctlr_el1
  orr  x0, x0, #CTRL_SPAN_BIT
  msr  sctlr_el1, x0
  mov  x0, #0x300000
  msr  cpacr_el1, x0

SetupCoreStack:
  // 7. Setup Stack Pointer for the current EL
  ldr  x0, =FixedPcdGet32 (PcdPrePiStackBase)
  ldr  x1, =FixedPcdGet32 (PcdPrePiStackSize)
  add  x2, x0, x1
  mov  sp, x2
  isb

  // 8. Zero-initialize stack
  mov  x3, x0
ClearStackLoop:
  stp  xzr, xzr, [x3], #16
  cmp  x3, x2
  b.lt ClearStackLoop

JumpToC:
  // 9. Enable caches and jump to CEntryPoint
  bl   ASM_PFX (ArmEnableInstructionCache)
  bl   ASM_PFX (ArmEnableDataCache)
  mov  x0, x10
  ldr  x4, =ASM_PFX (CEntryPoint)
  mov  x29, xzr
  blr  x4

NeverReturn:
  b  NeverReturn



