{-# LANGUAGE BinaryLiterals        #-}
{-# LANGUAGE DataKinds             #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE KindSignatures        #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE RankNTypes            #-}
{-# LANGUAGE StandaloneDeriving    #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeOperators         #-}

{-|
Module      : RISCV.Instruction
Copyright   : (c) Benjamin Selfridge, 2018
                  Galois Inc.
License     : None (yet)
Maintainer  : benselfridge@galois.com
Stability   : experimental
Portability : portable

Instruction sets
-}

module RISCV.InstructionSet
  ( -- * Instruction sets
    InstructionSet(..)
  , instructionSet
  , EncodeMap, DecodeMap, SemanticsMap
    -- * Opcode / OpBits conversion
  , opcodeFromOpBits
  , opBitsFromOpcode
  , semanticsFromOpcode
  ) where

import Data.Parameterized
import qualified Data.Parameterized.Map as Map
import Data.Parameterized.Map (MapF)

import RISCV.Instruction
import RISCV.Semantics

-- | Instruction encoding, mapping each opcode to its associated 'OpBits', the bits
-- it fixes in an instruction word.
type EncodeMap = MapF Opcode OpBits

-- | Reverse of 'EncodeMap'
type DecodeMap = MapF OpBits Opcode

type SemanticsMap arch = MapF Opcode (Formula arch)

-- | A set of RISC-V instructions. We use this type to group the various instructions
-- into categories based on extension and register width.
data InstructionSet arch
  = InstructionSet { isEncodeMap    :: EncodeMap
                   , isDecodeMap    :: DecodeMap
                   , isSemanticsMap :: SemanticsMap arch
                   }

instance Monoid (InstructionSet arch) where
  -- RV32 is the default/minimum, so that should be mempty.
  mempty = InstructionSet Map.empty Map.empty Map.empty


  InstructionSet em1 dm1 sm1 `mappend` InstructionSet em2 dm2 sm2
    = InstructionSet (em1 `Map.union` em2) (dm1 `Map.union` dm2) (sm1 `Map.union` sm2)

-- | Construction an instructionSet from only an EncodeMap
instructionSet :: EncodeMap -> SemanticsMap arch -> InstructionSet arch
instructionSet em sm = InstructionSet em (transMap em) sm
  where swap :: Pair (k :: t -> *) (v :: t -> *) -> Pair v k
        swap (Pair k v) = Pair v k
        transMap :: OrdF v => MapF (k :: t -> *) (v :: t -> *) -> MapF v k
        transMap = Map.fromList . map swap . Map.toList

-- | Given an instruction set, obtain the fixed bits of an opcode (encoding)
opBitsFromOpcode :: InstructionSet arch -> Opcode fmt -> OpBits fmt
opBitsFromOpcode is opcode = case Map.lookup opcode (isEncodeMap is) of
  Just opBits -> opBits
  Nothing     -> error $ "Opcode " ++ show opcode ++
                 " does not have corresponding OpBits defined."

-- | Given an instruction set, obtain the semantics of an opcode
semanticsFromOpcode :: InstructionSet arch -> Opcode fmt -> Formula arch fmt
semanticsFromOpcode is opcode = case Map.lookup opcode (isSemanticsMap is) of
  Just formula -> formula
  Nothing      -> error $ "Opcode " ++ show opcode ++
                  " does not have corresponding semantics defined."

-- | Given an instruction set, obtain the opcode from its fixed bits (decoding)
opcodeFromOpBits :: InstructionSet arch -> OpBits fmt -> Either (Opcode 'X) (Opcode fmt)
opcodeFromOpBits is opBits =
  maybe (Left Illegal) Right (Map.lookup opBits (isDecodeMap is))
