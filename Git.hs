{-# LANGUAGE OverloadedStrings #-}

-- | Git commands.

module Git where

import           Control.Concurrent.Lifted
import           Control.Monad
import           Control.Monad.IO.Class
import           Control.Monad.Logger
import           Control.Monad.Trans.Control
import           Data.Conduit.Process
import           Data.Monoid
import           Data.Text (Text)
import qualified Data.Text as T
import           Prelude
import           System.Directory
import           System.Exit

-- | Git repo instance.
newtype Git =
  Git {unGit :: MVar ()}

-- | Make a new git instance.
newGit :: IO Git
newGit = fmap Git (newMVar ())

-- | Run the given git command and arguments.
git :: (MonadIO m,MonadBaseControl IO m,MonadLogger m)
    => Git                    -- ^ Git instance.
    -> [String]               -- ^ Arguments.
    -> m (Either String Text) -- ^ Either stderr or stdout.
git lock args =
  withMVar (unGit lock)
           (const (do (code,err,out) <-
                        liftIO (readProcessWithExitCode "git" args "")
                      case code of
                        ExitSuccess ->
                          do logging "succeeded"
                             return (Right (T.pack out))
                        ExitFailure{} ->
                          do logging ("failed: "  <> T.pack err <> T.pack out)
                             return (Left (err <> out))))
  where logging text =
          $logDebug ("git " <>
                     T.intercalate " "
                                   (map T.pack args) <>
                     ": " <>
                     text)

-- | Clone a repo.
clone :: (MonadIO m,MonadBaseControl IO m,MonadLogger m)
      => Git -> String -> FilePath -> m ()
clone lock url target =
  do exists <- liftIO (doesDirectoryExist target)
     unless exists
            (do result <- git lock ["clone",url,"-q"]
                case result of
                  Left err -> error err
                  _ -> return ())

-- | Pull on a repo.
pull :: (MonadIO m,MonadBaseControl IO m,MonadLogger m)
      => Git -> FilePath -> Bool -> m ()
pull lock repo rebase =
  do result <-
       git lock (concat [["-C",repo],["pull"],["--rebase" | rebase]])
     case result of
       Left err -> error err
       _ -> return ()
