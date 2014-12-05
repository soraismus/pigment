\section{Cochon (Command-line Interface)}

%if False

> {-# OPTIONS_GHC -F -pgmF she #-}
> {-# LANGUAGE TypeOperators, TypeSynonymInstances, GADTs,
>     DeriveFunctor, DeriveFoldable, DeriveTraversable, OverloadedStrings,
>     CPP #-}

> module Cochon.Cochon where

> import Control.Applicative
> import Control.Monad.State
> import Control.Monad.Except
> import Data.Foldable as Foldable
> import Data.List hiding (find)
> import Data.Ord
> import Data.String
> import Data.Traversable

> import NameSupply.NameSupply

> import Evidences.Tm hiding (In)

> import DisplayLang.Lexer
> import DisplayLang.Name
> import DisplayLang.TmParse
> import DisplayLang.DisplayTm
> import DisplayLang.PrettyPrint

> import ProofState.Edition.ProofContext
> import ProofState.Edition.ProofState
> import ProofState.Edition.Entries
> import ProofState.Edition.GetSet
> import ProofState.Edition.Navigation

> import ProofState.Interface.Search
> import ProofState.Interface.ProofKit
> import ProofState.Interface.Module
> import ProofState.Interface.NameResolution
> import ProofState.Interface.Solving
> import ProofState.Interface.Parameter

> import Tactics.Elimination
> import Tactics.PropositionSimplify
> import Tactics.ProblemSimplify
> import Tactics.Information
> import Tactics.Gadgets
> import Tactics.Data
> import Tactics.IData
> import Tactics.Relabel
> import Tactics.ShowHaskell
> import Tactics.Matching
> import Tactics.Unification

> import Elaboration.Elaborator
> import Elaboration.Scheduler

> import Distillation.Distiller

> import Cochon.CommandLexer
> import Cochon.Error

> import Compiler.Compiler

> import Kit.BwdFwd
> import Kit.Parsley
> import Kit.MissingLibrary

#ifdef __HASTE__
> import Haste hiding (fromString, prompt)
> import Haste.JSON
> import Haste.Prim
#endif
> import React hiding (key)
> import qualified React

%endif

Here we have a very basic command-driven interface to the proof state monad.

Model
=====

> type CTData = (CochonTactic, [CochonArg])

Controller Helpers
==================

Should this be part of a transformer stack including Maybe and IO?

> getProofState :: PageM (ProofState PureReact)
> getProofState = PageM $ \state -> (_proofState state, state)

> setProofState :: ProofState PureReact -> PageM ()
> setProofState pfSt = PageM $ \state -> ((), state{_proofState=pfSt})

> setCtx :: Bwd ProofContext -> PageM ()
> setCtx ctx = PageM $ \state -> ((), state{_proofCtx=ctx})

> getInteractionState :: PageM InteractionState
> getInteractionState = PageM $ \state -> (state, state)

> setInteractionState :: InteractionState -> PageM ()
> setInteractionState state = PageM $ \_ -> ((), state)

> getCtx :: PageM (Bwd ProofContext)
> getCtx = PageM $ \state -> (_proofCtx state, state)

> displayUser :: PureReact -> PageM ()
> displayUser react =
>     let elem = div_ <! class_ "log-elem" $ react
>     in PageM $ \state -> ((), state{_outputLog=elem:(_outputLog state)})

> tellUser :: String -> PageM ()
> tellUser = displayUser . fromString

> resetUserInput :: PageM ()
> resetUserInput = PageM $ \state -> ((), state{_userInput=""})

View
====

> page :: InteractionReact
> page = div_ <! class_ "page" $ do
>     nest proofCtx proofCtxDisplay
>     div_ <! class_ "right-pane" $ do
>         prompt
>         nest outputLog interactionLog
>     tacticList

> prompt :: InteractionReact
> prompt = div_ <! class_ "prompt" $ do
>     InteractionState{_userInput=v} <- getState
>     input_ <! class_ "prompt-input"
>            <! value_ (toJSStr v)
>            <! onChange handleChange
>            <! onKeyPress handleKey

> handleChange :: InteractionState -> ChangeEvent -> InteractionState
> handleChange state evt = state{_userInput=(fromJSStr (targetValue evt))}

> handleKey :: InteractionState -> KeyboardEvent -> InteractionState
> handleKey state KeyboardEvent{React.key="Enter"} = do
>     let action = case parseCmd (_userInput state) of
>             Left err -> tellUser err
>             Right interaction -> do
>                 interaction
>                 locs :< loc <- getCtx
>                 pfSt <- getProofState
>                 let (msg, maybeCtx) = runProofState pfSt loc
>                 displayUser msg
>                 case maybeCtx of
>                     Just loc' -> do
>                         setCtx (locs :< loc')
>                         resetUserInput
>                     Nothing -> return ()
>     unPageM action state
> handleKey state _ = state

> interactionLog :: StatefulReact [PureReact] ()
> interactionLog = div_ <! class_ "interaction-log" $ do
>     logs <- getState
>     Foldable.forM_ logs pureNest

> proofCtxDisplay :: StatefulReact (Bwd ProofContext) ()
> proofCtxDisplay = div_ <! class_ "ctx-display" $ do
>     _ :< ctx <- getState
>     pureNest $ pre_ $ fst $ runProofState reactProofState ctx

> tacticList :: InteractionReact
> tacticList = div_ <! class_ "tactic-list" $
>     Foldable.forM_ cochonTactics $ \tactic ->
>         div_ <! class_ "tactic-info" $ pureNest $ ctHelp tactic

Controller
==========

We start out here. Main calls `cochon emptyContext`.

> cochon :: ProofContext -> IO ()
> cochon loc = do
>     Just e <- elemById "inject"
>     let pc = B0 :< loc
>         startState = InteractionState pc "" [] showPrompt
>     validateDevelopment pc
>     render startState e page

> cochon' :: PageM ()
> cochon' = do
>     locs :< loc <- getCtx
>     pfSt <- getProofState
>     let (msg, state') = runProofState pfSt loc
>     displayUser msg

TODO refactor / rename this

> parseCmd :: String -> Either String (PageM ())
> parseCmd l = case parse tokenize l of
>     Left  pf -> Left ("Tokenize failure: " ++ describePFailure pf id)
>     Right ts -> case parse pCochonTactics ts of
>         Left pf -> Left $
>             "Parse failure: " ++
>             describePFailure pf (intercalate " " . map crushToken)
>         Right cds -> Right $ doCTactics cds

> paranoid = False
> veryParanoid = False

XXX(joel) refactor this whole thing
  - remove putStrLn
  - make it PageM
  - fix line length
  - surely this can be expressed more compactly

> validateDevelopment :: Bwd ProofContext -> IO ()
> validateDevelopment locs@(_ :< loc) = if veryParanoid
>     then Foldable.mapM_ validateCtxt locs -- XXX: there must be a better way to do that
>     else if paranoid
>         then validateCtxt loc
>         else return ()
>   where validateCtxt loc =
>             case evalStateT (validateHere `catchError` catchUnprettyErrors) loc of
>               Left ss -> do
>                   putStrLn "*** Warning: definition failed to type-check! ***"
>                   putStrLn $ renderHouseStyle $ prettyStackError ss
>               _ -> return ()


> showPrompt :: ProofState PureReact
> showPrompt = do
>     mty <- optional' getHoleGoal
>     case mty of
>         Just (_ :=>: ty)  -> (|(showGoal ty) >> showInputLine|)
>         Nothing           -> showInputLine
>   where
>     showGoal :: TY -> ProofState PureReact
>     showGoal ty@(LABEL _ _) = do
>         h <- infoHypotheses
>         s <- prettyHere . (SET :>:) =<< bquoteHere ty
>         return $ h >> (fromString ("\nProgramming: " ++ show s ++ "\n"))
>     showGoal ty = do
>         s <- prettyHere . (SET :>:) =<< bquoteHere ty
>         return $ fromString $ "Goal: " ++ show s ++ "\n"
>
>     showInputLine :: ProofState PureReact
>     showInputLine = do
>         mn <- optional' getCurrentName
>         return $ fromString $ case mn of
>             Just n   -> showName n ++ " > "
>             Nothing  -> "> "


> describePFailure :: PFailure a -> ([a] -> String) -> String
> describePFailure (PFailure (ts, fail)) f = (case fail of
>     Abort        -> "parser aborted."
>     EndOfStream  -> "end of stream."
>     EndOfParser  -> "end of parser."
>     Expect t     -> "expected " ++ f [t] ++ "."
>     Fail s       -> s
>   ) ++ (if length ts > 0
>        then "\nSuccessfully parsed: ``" ++ f ts ++ "''."
>        else "")


A Cochon tactic consists of:
\begin{description}
\item[|ctName|] the name of this tactic
\item[|ctParse|] a parser that parses the arguments for this tactic
\item[|ctxTrans|] a state transition to perform for a given list of arguments and current context
\item[|ctHelp|] the help text for this tactic
\end{description}

> data CochonTactic =
>     CochonTactic  {  ctName   :: String
>                   ,  ctParse  :: Parsley Token (Bwd CochonArg)
>                   ,  ctxTrans :: [CochonArg] -> PageM ()
>                   ,  ctHelp   :: PureReact
>                   }

> instance Show CochonTactic where
>     show = ctName

> instance Eq CochonTactic where
>     ct1 == ct2 =  ctName ct1 == ctName ct2

> instance Ord CochonTactic where
>     compare = comparing ctName


The |tacticsMatching| function identifies Cochon tactics that match the
given string, either exactly or as a prefix.

> tacticsMatching :: String -> [CochonTactic]
> tacticsMatching x = case find ((x ==) . ctName) cochonTactics of
>     Just ct  -> [ct]
>     Nothing  -> filter (isPrefixOf x . ctName) cochonTactics

> tacticNames :: [CochonTactic] -> String
> tacticNames = intercalate ", " . map ctName


Given a proof state command and a context, we can run the command with
|runProofState| to produce a message (either the response from the command or
the error message) and |Maybe| a new proof context.

> runProofState
>     :: ProofState PureReact
>     -> ProofContext
>     -> (PureReact, Maybe ProofContext)
> runProofState m loc =
>     case runStateT (m `catchError` catchUnprettyErrors) loc of
>         Right (s, loc') -> (s, Just loc')
>         Left ss         -> (fromString $ renderHouseStyle $ prettyStackError ss, Nothing)


> simpleOutput :: ProofState PureReact -> PageM ()
> simpleOutput eval = do
>     locs :< loc <- getCtx
>     case runProofState (eval <* startScheduler) loc of
>         (s, Just loc') -> do
>             setCtx (locs :< loc :< loc')
>             displayUser s
>         (s, Nothing) -> do
>             setCtx (locs :< loc)
>             displayUser "I'm sorry, Dave. I'm afraid I can't do that."
>             displayUser s

>     case runProofState (eval <* startScheduler) loc of
>         (s, Just loc') -> do
>             setCtx (locs :< loc :< loc')
>             displayUser s
>         (s, Nothing) -> do
>             displayUser s
>             displayUser "I'm sorry, Dave. I'm afraid I can't do that."


We have some shortcuts for building common kinds of tactics:
|simpleCT| builds a tactic that works in the proof state,
and there are various specialised versions of it for nullary and
unary tactics.

> simpleCT :: String -> Parsley Token (Bwd CochonArg)
>     -> ([CochonArg] -> ProofState PureReact) -> String -> CochonTactic
> simpleCT name parser eval help = CochonTactic
>     {  ctName = name
>     ,  ctParse = parser
>     ,  ctxTrans = simpleOutput . eval
>     ,  ctHelp = fromString help
>     }

> nullaryCT :: String -> ProofState PureReact -> String -> CochonTactic
> nullaryCT name eval help = simpleCT name (pure B0) (const eval) help

> unaryExCT :: String -> (DExTmRN -> ProofState PureReact) -> String -> CochonTactic
> unaryExCT name eval help = simpleCT
>     name
>     (| (B0 :<) tokenExTm
>      | (B0 :<) tokenAscription |)
>     (eval . argToEx . head)
>     help

> unaryInCT :: String -> (DInTmRN -> ProofState PureReact) -> String -> CochonTactic
> unaryInCT name eval help = simpleCT
>     name
>     (| (B0 :<) tokenInTm |)
>     (eval . argToIn . head)
>     help

> unDP :: DExTm p x -> x
> unDP (DP ref ::$ []) = ref

> unaryNameCT :: String -> (RelName -> ProofState PureReact) -> String -> CochonTactic
> unaryNameCT name eval help = simpleCT
>     name
>     (| (B0 :<) tokenName |)
>     (eval . unDP . argToEx . head)
>     help

> unaryStringCT :: String
>               -> (String -> ProofState PureReact)
>               -> String
>               -> CochonTactic
> unaryStringCT name eval help = simpleCT
>     name
>     (| (B0 :<) tokenString |)
>     (eval . argToStr . head)
>     help

The master list of Cochon tactics.

> cochonTactics :: [CochonTactic]
> cochonTactics = sort (

Construction tactics:


>     nullaryCT "apply" (apply >> return "Applied.")
>       "apply - applies the last entry in the development to a new subgoal."
>   : nullaryCT "done" (done >> return "Done.")
>       "done - solves the goal with the last entry in the development."
>   : unaryInCT "give" (\tm -> elabGiveNext tm >> return "Thank you.")
>       "give <term> - solves the goal with <term>."
>   : simpleCT
>         "lambda"
>          (| (|bwdList (pSep (keyword KwComma) tokenString) (%keyword KwAsc%)|) :< tokenInTm
>           | bwdList (pSep (keyword KwComma) tokenString)
>           |)
>          (\ args -> case args of
>             [] -> return "This lambda needs no introduction!"
>             _ -> case last args of
>               InArg ty  -> Data.Traversable.mapM (elabLamParam . (:<: ty) . argToStr) (init args)
>                                >> return "Made lambda!"
>               _         -> Data.Traversable.mapM (lambdaParam . argToStr) args
>                                >> return "Made lambda!"
>            )
>          ("lambda <labels> - introduces one or more hypotheses.\n"++
>           "lambda <labels> : <type> - introduces new module parameters or hypotheses.")

>   : simpleCT
>         "let"
>         (| (| (B0 :< ) tokenString |) :< tokenScheme |)
>         (\ [StrArg x, SchemeArg s] -> do
>             elabLet (x :<: s)
>             optional' problemSimplify
>             optional' seekGoal
>             return (fromString $ "Let there be " ++ x ++ "."))
>         "let <label> <scheme> : <type> - set up a programming problem with a scheme."

>   : simpleCT
>         "make"
>         (| (|(B0 :<) tokenString (%keyword KwAsc%)|) :< tokenInTm
>          | (|(B0 :<) tokenString (%keyword KwDefn%) |) <><
>              (| (\ (tm :<: ty) -> InArg tm :> InArg ty :> F0) pAscription |)
>          |)
>         (\ (StrArg s:tyOrTm) -> case tyOrTm of
>             [InArg ty] -> do
>                 elabMake (s :<: ty)
>                 goIn
>                 return "Appended goal!"
>             [InArg tm, InArg ty] -> do
>                 elabMake (s :<: ty)
>                 goIn
>                 elabGive tm
>                 return "Made."
>         )
>        ("make <x> : <type> - creates a new goal of the given type.\n"
>            ++ "make <x> := <term> - adds a definition to the context.")

>   : unaryStringCT "module" (\s -> makeModule s >> goIn >> return "Made module.")
>       "module <x> - creates a module with name <x>."

>   : simpleCT
>         "pi"
>          (| (|(B0 :<) tokenString (%keyword KwAsc%)|) :< tokenInTm |)
>         (\ [StrArg s, InArg ty] -> elabPiParam (s :<: ty) >> return "Made pi!")
>         "pi <x> : <type> - introduces a pi."

>   : simpleCT
>       "program"
>       (|bwdList (pSep (keyword KwComma) tokenString)|)
>       (\ as -> elabProgram (map argToStr as) >> return "Programming.")
>       "program <labels>: set up a programming problem."

>   : nullaryCT "ungawa" (ungawa >> return "Ungawa!")
>       "ungawa - tries to solve the current goal in a stupid way."


Navigation tactics:

>   : nullaryCT "in" (goIn >> return "Going in...")
>       "in - moves to the bottom-most development within the current one."
>   : nullaryCT "out" (goOutBelow >> return "Going out...")
>       "out - moves to the development containing the current one."
>   : nullaryCT "up" (goUp >> return "Going up...")
>       "up - moves to the development above the current one."
>   : nullaryCT "down" (goDown >> return "Going down...")
>       "down - moves to the development below the current one."
>   : nullaryCT "top" (many' goUp >> return "Going to top...")
>       "top - moves to the top-most development at the current level."
>   : nullaryCT "bottom" (many' goDown >> return "Going to bottom...")
>       "bottom - moves to the bottom-most development at the current level."
>   : nullaryCT "previous" (prevGoal >> return "Going to previous goal...")
>       "previous - searches for the previous goal in the proof state."
>   : nullaryCT "root" (many' goOut >> return "Going to root...")
>       "root - moves to the root of the proof state."
>   : nullaryCT "next" ( nextGoal >> return "Going to next goal...")
>       "next - searches for the next goal in the proof state."
>   : nullaryCT "first"  (some' prevGoal >> return "Going to first goal...")
>       "first - searches for the first goal in the proof state."
>   : nullaryCT "last"   (some' nextGoal >> return "Going to last goal...")
>       "last - searches for the last goal in the proof state."

>   : unaryNameCT "jump" (\ x -> do
>       (n := _) <- resolveDiscard x
>       goTo n
>       return $ fromString $ "Jumping to " ++ showName n ++ "..."
>     )
>       "jump <name> - moves to the definition of <name>."


Miscellaneous tactics:

>      : CochonTactic
>          {  ctName = "help"
>          ,  ctParse = (| (B0 :<) tokenString
>                        | B0
>                        |)
>          ,  ctxTrans = (\args ->
>              case args of
>                  [] -> tellUser $ "Tactics available: " ++ tacticNames cochonTactics
>                  [StrArg s] -> case tacticsMatching s of
>                      [] -> tellUser "There is no tactic by that name."
>                      cts -> displayUser $ Prelude.mapM_ ctHelp cts
>            )
>          ,  ctHelp = fromString $ "help - displays a list of supported tactics.\n"
>                 ++ "help <tactic> - displays help about <tactic>.\n\n"
>                 ++ "What, you expected 'help help' to produce an amusing response?"
>          }

>     : CochonTactic
>         {  ctName = "undo"
>         ,  ctParse = pure B0
>         ,  ctxTrans = (\_ -> do
>                locs :< loc <- getCtx
>                case locs of
>                    B0  -> tellUser "Cannot undo."  >> setCtx (locs :< loc)
>                    _   -> tellUser "Undone."       >> setCtx locs
>          )
>         ,  ctHelp = fromString "undo - goes back to a previous state."
>         }

>     : nullaryCT "validate" (validateHere >> return "Validated.")
>         "validate - re-checks the definition at the current location."

Import more tactics from an aspect:

>     import <- CochonTactics
>     : [] )

> import <- CochonTacticsCode


> doCTacticsAt :: [(Name, [CTData])] -> PageM ()
> doCTacticsAt [] = return ()
> doCTacticsAt ((_, []):ncs) = doCTacticsAt ncs
> doCTacticsAt ((n, cs):ncs) = do
>     locs :< loc <- getCtx
>     let Right loc' = execStateT (goTo n) loc
>     setCtx (locs :< loc :< loc')
>     doCTactics cs
>     doCTacticsAt ncs

> doCTactics :: [CTData] -> PageM ()
> doCTactics = Foldable.mapM_ doCTactic
>     where doCTactic :: CTData -> PageM ()
>           doCTactic = uncurry ctxTrans

> pFileName :: Parsley Token String
> pFileName = ident


> tokenizeCommands :: Parsley Char [String]
> tokenizeCommands = (|id ~ [] (% pEndOfStream %)
>                     |id (% oneLineComment %)
>                         (% consumeUntil' endOfLine %)
>                         tokenizeCommands
>                     |id (% openBlockComment %)
>                         (% (eatNestedComments 0) %)
>                         tokenizeCommands
>                     |id (spaces *> endOfLine *> tokenizeCommands)
>                     |consumeUntil' endOfCommand :
>                      tokenizeCommands
>                     |)
>     where endOfCommand = tokenEq ';' *> spaces *> endOfLine
>                      <|> pEndOfStream *> pure ()
>           endOfLine = tokenEq (head "\n") <|> pEndOfStream
>           oneLineComment = tokenEq '-' *> tokenEq '-'
>           openBlockComment = tokenEq '{' *> tokenEq '-'
>           closeBlockComment = tokenEq '-' *> tokenEq '}'
>           spaces = many $ tokenEq ' '
>           eatNestedComments (-1) = (|id ~ ()|)
>           eatNestedComments i = (|id  (% openBlockComment %)
>                                       (eatNestedComments (i+1))
>                                  |id (% closeBlockComment %)
>                                      (eatNestedComments (i-1))
>                                  |id (% nextToken %)
>                                      (eatNestedComments i) |)

> pCochonTactics :: Parsley Token [CTData]
> pCochonTactics = pSepTerminate (keyword KwSemi) pCochonTactic


> pCochonTactic :: Parsley Token CTData
> pCochonTactic  = do
>     x <- (|id ident
>           |key anyKeyword
>           |)
>     case tacticsMatching x of
>         [ct] -> do
>             args <- ctParse ct
>             return (ct, trail args)
>         [] -> fail "unknown tactic name."
>         cts -> fail $
>             "ambiguous tactic name (could be " ++ tacticNames cts ++ ").")
