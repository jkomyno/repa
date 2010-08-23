{-# LANGUAGE PatternGuards, ScopedTypeVariables #-}

-- Repa buildbot
-- 	Used to automate building and performance testing of GHC and Repa
--
--	TODO: Add sleeping / build-at-midnight mode.
--
--	TODO: Capture output of system commands for logging on website.
--	      Make a log file for each of the stages, and post to web site along with results file.
--	      We might need to write a "tee" function in Haskell
--
--	TODO: Rewrite system cmds without using shell hacks.
--
--	TODO: Timestamp "current" build results file. Rename to results-DATE.
--
--	TODO: Set number of threads to test with for Repa on cmd line.
--
import BuildBox
import Args
import Config
import BuildRepa
import BuildGhc
import Control.Monad
import System.Console.ParseArgs	hiding (args)
import System.IO
import Data.Maybe

main :: IO ()
main 
 = do	args	<- parseArgsIO ArgsTrailing buildArgs
	mainWithArgs args

-- | Decide what to do
mainWithArgs :: Args BuildArg -> IO ()
mainWithArgs args

	-- Print usage help
	| gotArg args ArgHelp
	= usageError args ""

	-- Dump a results file.
	| Just fileName	<- getArg args ArgDoDump
	, []		<- argsRest args
	= do	contents	<- readFile fileName
		let results	=  (read contents) :: BuildResults
		putStrLn $ render $ ppr results

	-- Compare two results files.
	| gotArg args ArgDoCompare
	= do	let fileNames	= argsRest args
		contentss	<- mapM readFile fileNames
		let (results :: [BuildResults])
				= map read contentss
		
		let [baseline, current] 
				= map buildResultBench results

		putStrLn $ render $ pprComparisons baseline current
		
	
	-- Run some build process.
	| or $ map (gotArg args) 
		[ ArgDoTotal
		, ArgDoGhcUnpack,  ArgDoGhcBuild,  ArgDoGhcLibs
		, ArgDoRepaUnpack, ArgDoRepaBuild, ArgDoRepaTest]

	= do	-- All the build commands require a scratch dir.
		let tmpDir = fromMaybe 
			(error "You must specify --scratch with this command.")
			(getArg args ArgScratchDir)

		tmpDir `seq` return ()

		-- Load up cmd line args into our config structure.
		config	<- slurpConfig args tmpDir
		let buildConfig
			= BuildConfig
			{ buildConfigLogSystem	= if gotArg args ArgVerbose
			 				then Just stdout
							else Nothing }
							
		-- Decide if we're doing a daily, or one-shot build.
		if gotArg args ArgDaily
		 then	mainDaily args config buildConfig
		 else	mainBuild args config buildConfig

	| otherwise
	= usageError args "Nothing to do...\n"

-- | Run the build every day.
mainDaily :: Args BuildArg -> Config -> BuildConfig -> IO ()
mainDaily _args _config _buildConfig
 = do	putStrLn "Fucker\n"
	return ()


-- | Run a single-shot build.
mainBuild :: Args BuildArg -> Config -> BuildConfig -> IO ()
mainBuild _args config buildConfig
 = do	_	<- runBuildPrintWithConfig buildConfig (runTotal config)
	return ()


-- | The total build.
--   This only runs the stages set in the config.
runTotal :: Config -> Build ()
runTotal config
 = do	outLine
	outLn "Repa BuildBot\n"
	
	-- Check the current environment.
	env	<- getEnvironmentWith 
			[ ("GHC", getVersionGHC $ configWithGhc config)
			, ("GCC", getVersionGCC "gcc") ]
			
	outLn $ render $ ppr $ env
	
	outLine
	outBlank
	
	-- Unpack GHC
	when (configDoGhcUnpack config)
	 $ ghcUnpack config
	
	-- If we've been told to build GHC, then use
	-- 	the completed build as the default compiler.
	configNew
	  <- if configDoGhcBuild config
	      then do ghcBuild config
		      return config
				{ configWithGhc	   = configScratchDir config ++ "/ghc-head/inplace/bin/ghc-stage2"
				, configWithGhcPkg = configScratchDir config ++ "/ghc-head/inplace/bin/ghc-pkg" }
	      else return config
			
	-- Use cabal to install base libs into a GHC build.
	when (configDoGhcLibs configNew)
	 $ ghcLibs configNew
			
	-- Download the latest Repa repo.
	when (configDoRepaUnpack configNew)
	 $ repaUnpack configNew
	
	-- Build Repa packages and register then with the current compiler.
	when (configDoRepaBuild configNew)
	 $ repaBuild configNew
		
	-- Test Repa and write results to file, or mail them to the list.
	when (configDoRepaTest configNew)
	 $ repaTest configNew env

