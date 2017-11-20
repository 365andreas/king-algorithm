{-# LANGUAGE DeriveAnyClass     #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}

module Messages where

import Control.Distributed.Process (Process, ProcessId, say, send)
import Data.Binary
import Data.Typeable
import GHC.Generics

type Command  = Int
type Delay    = Int
type Phase    = Int

-- | The 'Timeout' message is used for synchronization
-- purposes.
data Timeout = Timeout
    deriving (Generic, Typeable, Binary, Show)

-- | The 'Info' message contains all nodes pids, n, f ans
-- master's pid.
data Info = Info [ProcessId] Int Int ProcessId [ProcessId]
    deriving (Generic, Typeable, Binary, Show)

-- | The 'Value' message is the one the node sends to the
-- others in line 3.
newtype Value = Value Command -- Phase
    deriving (Generic, Typeable, Binary, Show, Eq, Ord)

-- | The 'Propose' message is the one sent by the node to
-- the others in line 5.
newtype Propose = Propose Command -- Phase ProcessId
    deriving (Generic, Typeable, Binary, Show, Eq, Ord)


-- | The 'King' message is the one sent by the king to
-- the others in line 11.
newtype King = King Command -- Phase ProcessId
    deriving (Generic, Typeable, Binary, Show, Eq, Ord)

-- | The 'Executed' message is an additional message we
-- just use for this exercise. It's sent by the nodes to
-- the master at the end of the protocol.
newtype Executed = Executed Command
    deriving (Generic, Typeable, Binary, Show)

broadcast :: (Binary a,Typeable a,Show a) => [ProcessId] -> a -> Process ()
broadcast ls msg = do
  say $ "\tBroadcasting " ++ show msg
  mapM_ (`send` msg) ls

-- | 1s = 1,000,000us
second :: Int
second = 1000000