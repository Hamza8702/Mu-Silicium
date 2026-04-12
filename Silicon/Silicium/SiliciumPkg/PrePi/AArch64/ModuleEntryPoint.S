//
//  Copyright (c) 2011 - 2020, Arm Limited. All rights reserved.
//  Modified for EL2/VHE Support by Hamza
//
//  SPDX-License-Identifier: BSD-2-Clause-Patent
//

#include <AsmMacroLib.h>

.set CTRL_SPAN_BIT, (1 << 23)
.set HCR_EL2_E2H,   (1 << 34)  /* Virtualization Host Extensions Bit */

.text
.align 3

ASM_FUNC (_ModuleEntryPoint)
  // Run SoC Specific Code
  bl   ASM_PFX (PlatformAssemblyInit)

  // Get MpId
  bl   ASM_PFX (ArmReadMpidr)

  // Save MpId
  mov  x10, x0

SetSVCMode:
  // Clear x0 and x1
  mov  x0, #0
  mov  x1, #0

  // Disable all Interrupts
  bl   ASM_PFX (ArmDisableInterrupts)

  // Disable MMU and CPU Caches
  bl   ASM_PFX (ArmDisableCachesAndMmu)

  // Invalidate I-Cache
  bl   ASM_PFX (ArmInvalidateInstructionCache)

  // Invalidate TLB
  bl   ASM_PFX (ArmInvalidateTlb)

  /* --- EL2 / VHE CHECK START --- */
  mrs  x0, CurrentEL
  lsr  x0, x0, #2
  cmp  x0, #2
  b.ne SetupEL1

#if (FixedPcdGet32 (PcdEnableVHE) == 1)
EnableVHE:
  // Enable VHE Mode in HCR_EL2
  mrs  x0, hcr_el2
  orr  x0, x0, #HCR_EL2_E2H
  msr  hcr_el2, x0
  isb

  // Rewrite SCTLR_EL2 (Instead of EL1)
  mrs  x0, sctlr_el2
  orr  x0, x0, #CTRL_SPAN_BIT
  msr  sctlr_el2, x0

  // Untrap VFP/SIMD at EL2
  mrs  x0, cptr_el2
  bic  x0, x0, #(1 << 20) // Clear TFP bit
  msr  cptr_el2, x0
  isb
  b    SetupCoreStack
#endif

SetupEL1:
  // Rewrite SCTLR_EL1
  mrs  x0, sctlr_el1
  orr  x0, x0, #CTRL_SPAN_BIT
  msr  sctlr_el1, x0

UntrapVFP:
  // Rewrite CPACR_EL1
  mrs  x0, cpacr_el1
  orr  x0, x0, #0x300000
  msr  cpacr_el1, x0

  // Fetch Subsequent Instructions
  isb  sy

SetupCoreStack:
  // Get Stack Base & Size
  ldr  x0, =FixedPcdGet32 (PcdPrePiStackBase)
  ldr  x1, =FixedPcdGet32 (PcdPrePiStackSize)

  // Prepare Stack Clear
  add  x2, x0, x1
  mov  x3, x0

  // Set Core Stack
  mov  v4.d[0], xzr
  mov  v4.d[1], xzr
  mov  v5.2d, v4.2d
  mov  v6.2d, v4.2d
  mov  v7.2d, v4.2d

ClearStack:
  // Clear 64 Bytes
  st4  { v4.2d, v5.2d, v6.2d, v7.2d }, [x3], #64
  cmp  x3, x2
  b.lt ClearStack

  // Init SP
  add  sp, x2, xzr

EnableCaches:
  // Disable D-Cache
  bl   ASM_PFX (ArmDisableDataCache)

  // Enable I-Cache & D-Cache
  bl   ASM_PFX (ArmEnableInstructionCache)
  bl   ASM_PFX (ArmEnableDataCache)

JumpToC:
  // Restore Values
  mov  x0, x10
  mov  x1, x11
  mov  x2, x12

  // Set Jump Location
  ldr  x4, =ASM_PFX (CEntryPoint)

  // Clear Frame Pointer
  mov  x29, xzr

  // Jump to C Code
  blr  x4

.align 3

NeverReturn:
  b  NeverReturn

