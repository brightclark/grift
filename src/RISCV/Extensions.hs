{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}

{-|
Module      : RISCV.Extensions
Copyright   : (c) Benjamin Selfridge, 2018
                  Galois Inc.
License     : None (yet)
Maintainer  : benselfridge@galois.com
Stability   : experimental
Portability : portable

Extensions for RISC-V.
-}

module RISCV.Extensions
  ( -- * RISC-V Base ISA and extensions
    knownISet
  ) where

import Data.Monoid
import Data.Parameterized

import RISCV.InstructionSet
import RISCV.Extensions.Base
import RISCV.Extensions.A
import RISCV.Extensions.M
import RISCV.Extensions.Priv
import RISCV.Types

-- | Infer the current instruction set from a context in which the 'BaseArch' and
-- 'Extensions' are known.
knownISet :: forall arch exts
             .  (KnownArch arch, KnownExtensions exts)
          => InstructionSet arch exts
knownISet = baseset <> privset <> mset <> aset <> fset
  where  archRepr = knownRepr :: BaseArchRepr arch
         ecRepr = knownRepr :: ExtensionsRepr exts
         baseset = case archRepr of
           RV32Repr -> base32
           RV64Repr -> base64
           RV128Repr -> error "RV128 not yet supported"
         privset = privm -- TODO
         mset = case (archRepr, ecRepr) of
           (RV32Repr, ExtensionsRepr _ MYesRepr _ _) -> m32
           (RV64Repr, ExtensionsRepr _ MYesRepr _ _) -> m64
           _ -> mempty
         aset = case (archRepr, ecRepr) of
           (RV32Repr, ExtensionsRepr _ _ AYesRepr _) -> a32
           (RV64Repr, ExtensionsRepr _ _ AYesRepr _) -> a64
           _ -> mempty
         fset = case ecRepr of
           ExtensionsRepr _ _ _ FDNoRepr -> mempty
           _ -> error "Floating point not yet supported"
