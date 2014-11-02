{-# OPTIONS_GHC -Wall #-}
-----------------------------------------------------------------------------
-- |
-- Copyright   :  (C) 2014 Edward Kmett and Gabríel Arthúr Pétursson
-- License     :  BSD-style (see the file LICENSE)
-- Maintainer  :  Edward Kmett <ekmett@gmail.com>
-- Stability   :  experimental
-- Portability :  portable
--
----------------------------------------------------------------------------
module Module
  ( Module(..)
  , Export(..)
  , Body(..)
  , renderModule
  , saveModule
  ) where

import Utils
import System.Directory
import System.FilePath
import Text.Printf

data Module = Module
  { moduleName :: String
  , moduleExport :: [Export]
  , moduleBody :: [Body]
  } deriving (Eq, Show)

data Export
  = Section
    { sectionHeading :: String
    , sectionExport :: [String]
    }
  | Subsection
    { sectionHeading :: String
    , sectionExport :: [String]
    } deriving (Eq, Show)

data Body 
  = Import [String]
  | Function String String String
  | Pattern String String String
  | Code String
  deriving (Eq, Show)

renderModule :: Module -> String
renderModule m =
  printf 
    ("-- This file was automatically generated.\n" ++
    "{-# LANGUAGE ScopedTypeVariables, PatternSynonyms #-}\n" ++
    "module %s%s where\n\n%s")
     (moduleName m) (renderExports $ moduleExport m) (joinOn "\n\n" . map renderBody $ moduleBody m)


renderExports :: [Export] -> String
renderExports [] = ""
renderExports exports =
    printf " (\n%s)"
  . joinOn "\n" . map (uncurry renderExport)
  . zip (True : repeat False)
  $ filter nonEmpty exports
  where
    renderExport :: Bool -> Export -> String
    renderExport first (Section heading export) =
      printf "  -- * %s\n  %s %s"
        heading
        (if first then " " else ",")
        ((++"\n") . joinOn "\n  , " $ export)
    renderExport first (Subsection heading export) =
      printf "  -- ** %s\n  %s %s"
        heading
        (if first then " " else ",")
        ((++"\n") . joinOn "\n  , " $ export)
    nonEmpty :: Export -> Bool
    nonEmpty (Section _ []) = False
    nonEmpty (Subsection _ []) = False
    nonEmpty _ = True

renderBody :: Body -> String
renderBody body = case body of
  Import m -> joinOn "\n" $ map (printf "import %s") m
  Function name signature b -> printf "%s :: %s\n%s %s" name signature name b
  Pattern name signature b -> printf "pattern %s %s :: %s" name b signature
  Code code -> code

saveModule :: FilePath -> Module -> IO ()
saveModule fp m = do
  createDirectoryIfMissing True folderPath
  writeFile filePath $ renderModule m
  where
    filePath = fp </> replace "." [pathSeparator] (moduleName m) <.> "hs"
    folderPath = (joinOn [pathSeparator] . init $ splitOn [pathSeparator] filePath)
