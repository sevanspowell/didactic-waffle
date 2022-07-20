module Hydra where

-- initial:
--------------------------------------------------------------------------------
-- Announce identies of parties
-- Establish authenticated channels
-- Exchange public-key material
-- Submit initial transaction
  -- head parameters
  -- forge participation tokens
  -- initialize state machine
-- Wait for initial transaction to appear
-- Attach commit transaction (locks committed UTxOs on mainchain)

-- open
--------------------------------------------------------------------------------
-- Collect transactions (initial -> open)
-- Begin offchain head protocol
  -- Set UTxO -> Set UTxO

-- Use certificiat for current head UTxO set to advance state machine to closed state

-- closed
--------------------------------------------------------------------------------
-- Contest period

-- Head protocol

-- U0 (intial set of UTxOs == those locked on chain)

-- Party state: L = { currentUTxOs = U0 + Txs }

-- Snapshot = a party state (L), but signed by multisignature (of every party?).
-- So Snapshot = { currentUTxOs = U0 + Txs, multisignature = [...] }
--   But! full state is not needed, so intead:
--     Snapshot = { txHashes :: [ Hash Tx ], Ui = Either U0 Snapshot }

-- Close:
--
