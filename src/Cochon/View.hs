{-# LANGUAGE PatternSynonyms, OverloadedStrings, TypeFamilies,
  MultiParamTypeClasses, LambdaCase, LiberalTypeSynonyms #-}

module Cochon.View where

import Control.Applicative
import Control.Monad
import Control.Monad.Error
import Control.Monad.State
import qualified Data.Foldable as Foldable
import Data.Monoid
import Data.List
import Data.String
import Data.Traversable
import Data.Void

import Cochon.CommandLexer
import Cochon.Controller
import Cochon.Error
import Cochon.Model
import Cochon.Tactics
import DisplayLang.Lexer
import DisplayLang.Name
import DisplayLang.TmParse
import DisplayLang.DisplayTm
import DisplayLang.PrettyPrint
import DisplayLang.Reactify
import DisplayLang.Scheme
import Distillation.Distiller
import Distillation.Scheme
import Elaboration.Elaborator
import Elaboration.Scheduler
import Elaboration.ElabProb
import Elaboration.ElabMonad
import Elaboration.MakeElab
import Elaboration.RunElab
import Evidences.Eval hiding (($$))
import qualified Evidences.Eval (($$))
import Evidences.Tm
import Kit.BwdFwd
import Kit.ListZip
import Kit.Parsley
import NameSupply.NameSupply
import ProofState.Edition.ProofContext
import ProofState.Edition.ProofState
import ProofState.Edition.Entries
import ProofState.Edition.GetSet
import ProofState.Edition.Navigation
import ProofState.Edition.Scope
import ProofState.Interface.Search
import ProofState.Interface.ProofKit
import ProofState.Interface.Lifting
import ProofState.Interface.Module
import ProofState.Interface.NameResolution
import ProofState.Interface.Solving
import ProofState.Interface.Parameter
import ProofState.Structure.Developments
import ProofState.Structure.Entries

import Tactics.Data
import Tactics.Elimination
import Tactics.IData
import Tactics.Matching
import Tactics.ProblemSimplify
import Tactics.PropositionSimplify
import Tactics.Record
import Tactics.Relabel
import Tactics.ShowHaskell
import Tactics.Unification

import GHCJS.Foreign
import GHCJS.Types
import Lens.Family2
import React hiding (label_)
import React.MaterialUI

import Kit.Trace


instance Reactive EntityAnchor where
    reactify x = span_ [ class_ "anchor" ] $ fromString $ show x


page :: InteractionState -> InteractionReact
page state = div_ [ class_ "page" ] $ do
    div_ [ class_ "left-pane" ] $ do
        div_ [ class_ "top-pane" ] $ do
            -- div_ [ class_ "ctx-layers" ] $
            --     proofCtxLayers (pcLayers (_proofCtx state))
            -- elabTrace (show (_proofCtx state))
            -- elabTrace (renderHouseStyle (pretty (_proofCtx state) maxBound))
            proofCtxDisplay $ _proofCtx state
        div_ [ class_ "bottom-pane" ] $ do
            locally $ autocompleteView (_autocomplete state)
            prompt state
            -- locally $ workingOn state
    rightPane state


-- The autocomplete overlay
type Autocomplete a = a AutocompleteState Void ()


-- proofCtxLayers :: Bwd Layer -> InteractionReact
-- proofCtxLayers layers = ol_ $ Foldable.forM_ layers $ \layer ->
--     li_ "layer"


rightPane :: InteractionState -> InteractionReact
rightPane s = do
    when (s^.rightPaneVisible == Visible) (innerRightPane s)
    paneToggle s


paneToggle :: InteractionState -> InteractionReact
paneToggle s = button_ [ class_ "pane-bar"
                       , onClick handleToggleRightPane
                       ] $ do
    let cls = case s^.rightPaneVisible of
          Invisible -> "pane-bar-icon icon ion-arrow-left-b"
          Visible   -> "icon ion-arrow-right-b"
    i_ [ class_ cls ] ""


choosePaneButtons :: Pane -> InteractionReact
choosePaneButtons pane = div_ [ class_ "choose-pane" ] $ do
    let go x = if x == pane then "selected-pane" else ""
    div_ [ class_ (go Log)
         , onClick (handleSelectPane Log)
         ] "Command Log"
    div_ [ class_ (go Commands)
         , onClick (handleSelectPane Commands)
         ] "Commands"
    div_ [ class_ (go Settings)
         , onClick (handleSelectPane Settings)
         ] "Settings"


innerRightPane :: InteractionState -> InteractionReact
innerRightPane InteractionState{_currentPane=pane, _interactions=ixs} =
    div_ [ class_ "right-pane" ] $ do
        choosePaneButtons pane
        locally $ case pane of
            Log -> interactionLog ixs
            Commands -> tacticList
            Settings -> "TODO(joel) - settings"


autocompleteView :: AutocompleteState -> Autocomplete React'
autocompleteView mtacs = case mtacs of
    Stowed -> ""
    CompletingTactics tacs -> div_ [ class_ "autocomplete" ] $
        innerAutocomplete tacs
    CompletingParams tac -> locally $ case ctHelp tac of
        Left react -> div_ [ class_ "tactic-help" ] react
        Right tacticHelp -> longHelp tacticHelp


innerAutocomplete :: ListZip CochonTactic -> Autocomplete React'
innerAutocomplete (ListZip early focus late) = do
    let desc :: Foldable a => a CochonTactic -> Autocomplete React'
        desc tacs = Foldable.forM_ tacs (div_ . fromString . ctName)

    desc early

    locally $ div_ [ class_ "autocomplete-focus" ] $ do
        div_ $ fromString $ ctName focus
        div_ $ renderHelp $ ctHelp focus

    desc late


promptArrow :: Pure React'
promptArrow = i_ [ class_ "icon ion-ios-arrow-forward" ] ""


prompt :: InteractionState -> InteractionReact
prompt state = div_ [ class_ "prompt" ] $ do
    locally promptArrow
    input_ [ class_ "prompt-input"
           , value_ (toJSString (userInput state))
           , autofocus_ True
           , onChange handleCmdChange
           , onKeyDown handleKey
           ]


workingOn :: InteractionState -> Pure React'
workingOn InteractionState{_proofCtx=_ :< loc} =
    let runner :: ProofState (Pure React', Pure React')
        runner = do
            mty <- optional' getHoleGoal
            goal <- case mty of
                Just (_ :=>: ty) -> showGoal ty
                Nothing          -> return ""

            mn <- optional' getCurrentName
            let name = fromString $ case mn of
                    Just n   -> showName n
                    Nothing  -> ""

            return (goal, name)

        val :: Pure React'
        val = case runProofState runner loc of
            Left err -> err
            Right ((goal, name), loc') -> goal >> name

    in div_ [ class_ "working-on" ] val


showGoal :: TY -> ProofState (Pure React')
showGoal ty@(LABEL _ _) = do
    h <- infoHypotheses
    s <- reactHere . (SET :>:) =<< bquoteHere ty
    return $ div_ [ class_ "goal" ] $ do
        h
        "Programming: "
        s
showGoal ty = do
    s <- reactHere . (SET :>:) =<< bquoteHere ty
    return $ div_ [ class_ "goal" ] $ do
        "Goal: "
        s


interactionLog :: InteractionHistory -> Pure React'
interactionLog logs = div_ [ class_ "interaction-log" ] $
    Foldable.forM_ logs $ \(Command cmdStr _ _ out) ->
        div_ [ class_ "log-elem" ] $ do
            div_ [ class_ "log-prompt" ] $ do
                promptArrow
                " "
                fromString cmdStr
            div_ [ class_ "log-output" ] out


proofCtxDisplay :: Bwd ProofContext -> InteractionReact
proofCtxDisplay (_ :< ctx) = proofContextView ctx

-- proofCtxDisplay :: Bwd ProofContext -> InteractionReact
-- proofCtxDisplay (_ :< ctx) = div_ [ class_ "ctx-display" ] $
--     case runProofState reactProofState ctx of
--         Left err -> locally err
--         Right (display, _) -> display


longHelp :: TacticHelp -> Pure React'
longHelp (TacticHelp template example summary args) =
    div_ [ class_ "tactic-help" ] $ do
        div_ [ class_ "tactic-template" ] template

        div_ [ class_ "tactic-example" ] $ do
            div_ [ class_ "tactic-help-title" ] "Example"
            div_ [ class_ "tactic-help-body" ] $ fromString example

        div_ [ class_ "tactic-summary" ] $ do
            div_ [ class_ "tactic-help-title" ] "Summary"
            div_ [ class_ "tactic-help-body" ] $ fromString summary

        Foldable.forM_ args $ \(argName, argSummary) ->
            div_ [ class_ "tactic-arg-help" ] $ do
                div_ [ class_ "tactic-help-title" ] $ fromString argName
                div_ [ class_ "tactic-help-body" ] $ fromString argSummary


renderHelp :: Either (Pure React') TacticHelp -> Pure React'
renderHelp (Left react) = react
renderHelp (Right (TacticHelp _ _ summary _)) = fromString summary


tacticList :: Pure React'
tacticList = div_ [ class_ "tactic-list" ] $
    Foldable.forM_ cochonTactics $ \tactic ->
        li_ [ class_ "tactic-info" ] $ renderHelp $ ctHelp tactic


numEntries :: Layer -> Int
numEntries (Layer aboveEntries _ belowEntries _ _ _) =
    foldableSize aboveEntries + 1 + foldableSize belowEntries


-- TODO(joel) use Lens lengthOf
foldableSize :: Foldable t => t a -> Int
foldableSize = getSum . Foldable.foldMap (const $ Sum 1)


layerView :: Layer -> InteractionReact
layerView layer@(Layer aboveEntries currentEntry belowEntries tip _ suspend) =
    div_ [ class_ "layer" ] $ do
        flatButton
            [ class_ "layer-button"
            , label_ (reasonableName currentEntry)
            , onClick (handleGoTo (currentEntryName currentEntry)) ] $
                -- locally $ currentEntryView currentEntry
                return ()
        locally $ div_ [ class_ "layer-info" ] $ do
            fromString $ "size: " ++ show (numEntries layer)
            suspendView suspend


-- = CDefinition DefKind REF (String, Int) INTM EntityAnchor Bool
-- | CModule Name Bool ModulePurpose
--
-- data DefKind = LETG |  PROG (Scheme INTM)
--
-- References are the key way we represent free variables, declared,
-- defined, and deluded. References carry not only names, but types and
-- values, and are shared.
--
-- data REF = (:=) { refName :: Name, refBody :: (RKind :<: TY)}


reasonableName :: CurrentEntry -> JSString -- Pure React'
reasonableName = fromString . fst . last . currentEntryName


entryReasonableName :: Traversable f => Entry f -> JSString
entryReasonableName = fromString . fst . last . entryName


-- currentEntryView :: CurrentEntry -> Pure React'
-- currentEntryView entry@(CDefinition _ _ _ _ _ expanded) =
--     div_ [ class_ "current-entry cdefinition" ] $
--         reasonableName entry
-- currentEntryView entry@(CModule _ expanded purpose) =
--     div_ [ class_ "current-entry cmodule" ] $
--         reasonableName entry


-- TODO(joel) think about how to guarantee an ol_'s children are li_'s

entryView :: Traversable f => Entry f -> InteractionReact
entryView entry@(EEntity _ _ entity term anchor expanded) = li_ [] $
    div_ [ class_ "entity" ] $ do
        flatButton
            [ label_ (entryReasonableName entry)
            , onClick (handleGoTo (entryName entry)) ] $
                return ()
        ul_ $ do
            li_ $ fromString $ show anchor
            li_ $ fromString $ "expanded: " ++ show expanded
entryView entry@(EModule _ dev expanded purpose) = li_ [] $
    div_ [ class_ "module" ] $ do
        flatButton
            [ label_ (entryReasonableName entry)
            , onClick (handleGoTo (entryName entry)) ] $
                return ()
        div_ $ do
            span_ "(module)"
            span_ $ fromString $ "purpose: " ++ showPurpose purpose


devView :: Traversable f => Dev f -> InteractionReact
devView (Dev entries tip _ suspend) = div_ [ class_ "dev" ] $ do
    locally $ div_ [ class_ "dev-header" ] $ do
        tipView tip
        div_ [ class_ "dev-header-suspend" ] $ suspendView suspend
    ol_ [ class_ "dev-entries" ] $ Foldable.forM_ entries entryView


-- class Classes a where
--     classes_ :: JSString -> a

-- instance Classes (AttrOrHandler b) where
--     classes_ = class_

-- instance Classes a => Classes (a -> AttrOrHandler b) where
--     classes_ x =


suspendView :: SuspendState -> Pure React'
suspendView state =
    let (elem, cls) = case state of
            SuspendNone -> ("not suspended", "none")
            SuspendStable -> ("suspended (stable)", "stable")
            SuspendUnstable -> ("suspended (unstable!)", "unstable")

    in div_ [ class_ (fromString ("suspend-state " ++ cls)) ] elem


tipView :: Tip -> Pure React'
tipView Module = div_ [ class_ "tip" ] $ "(module)"
tipView (Unknown (ty :=>: _)) = div_ [ class_ "tip" ] $ "unknown"
    -- hk <- getHoleKind
    -- tyd <- reactHere (SET :>: ty)
    -- return $ div_ [ class_ "tip" ] $ do
    --     reactHKind hk
    --     reactKword KwAsc
    --     tyd
tipView (Suspended (ty :=>: _) prob) = div_ [ class_ "tip" ] $ "suspended"
    -- hk <- getHoleKind
    -- tyd <- reactHere (SET :>: ty)
    -- return $ div_ [ class_ "tip" ] $ do
    --     fromString $ "(SUSPENDED: " ++ show prob ++ ")"
    --     reactHKind hk
    --     reactKword KwAsc
    --     tyd
tipView (Defined tm (ty :=>: tyv)) = div_ [ class_ "tip" ] $ "defined"
    -- tyd <- reactHere (SET :>: ty)
    -- tmd <- reactHereAt (tyv :>: tm)
    -- return $ div_ [ class_ "tip" ] $ do
    --     tmd
    --     reactKword KwAsc
    --     tyd


proofContextView :: ProofContext -> InteractionReact
proofContextView (PC layers aboveCursor belowCursor) =
    div_ [ class_ "proof-context" ] $ do
        div_ [ class_ "proof-context-layers" ] $ do
            h2_ "layers"
            -- TODO(joel) - disable current layer
            ol_ $ do
                -- TODO(joel) - this is hacky - remove duplication in
                -- layerView
                div_ [ class_ "layer first-layer" ] $ do
                    flatButton
                        [ class_ "layer-button"
                        , label_ "root"
                        , onClick (handleGoTo []) ] $
                            return ()
                Foldable.forM_ layers layerView
        devView aboveCursor
        locally $ div_ [ class_ "proof-context-below-cursor" ] $
            ol_ $ Foldable.forM_ belowCursor entryView


-- The `reactProofState` command generates a reactified representation of
-- the proof state at the current location.
reactProofState :: ProofState InteractionReact
reactProofState = renderReact


-- Render a bunch of entries!
renderReact :: ProofState InteractionReact
renderReact = do
    me <- getCurrentName
    entry <- getCurrentEntry

    -- TODO(joel) - we temporarily replace entries above the cursor and
    -- contexts below the cursor with nothing, then put them back later
    -- (below). Why?
    es <- replaceEntriesAbove B0
    cs <- putBelowCursor F0

    case (entry, es, cs) of
        (CModule _ _ DevelopData, _, _) -> viewDataDevelopment entry es
        (CDefinition _ _ _ _ AnchDataDef _, _, _) -> viewDataDevelopment entry es
        (_, B0, F0) -> reactEmptyTip
        _ -> do
            d <- reactEntries (es <>> F0)

            d' <- case cs of
                F0 -> return d
                _ -> do
                    d'' <- reactEntries cs
                    return (d >> "---" >> d'')

            tip <- reactTip
            putEntriesAbove es
            putBelowCursor cs

            return $ div_ [ class_ "proof-state" ] $ do
                -- div_ [ class_ "entries-name" ] $ do
                --     "Entries name: "
                --     fromString $
                --         case me of
                --             [] -> "(no name)"
                --             _ -> fst $ last me
                div_ [ class_ "proof-state-inner" ] d'
                tip


dataWeCareAbout :: Entry a -> Bool
dataWeCareAbout (EEntity _ _ _ _ (AnchConName _) _) = True
dataWeCareAbout (EEntity _ _ _ _ AnchDataDef _) = True
dataWeCareAbout (EEntity _ _ _ _ AnchDataDesc _) = True
dataWeCareAbout _ = False


viewDataDevelopment :: CurrentEntry -> Entries -> ProofState InteractionReact
viewDataDevelopment (CDefinition _ (name := _) _ _ _ _) entries = do
    let weCareAbout = filterBwd dataWeCareAbout entries
    entries <- reactEntries (weCareAbout <>> F0)

    return $ div_ [ class_ "data-develop" ] entries


reactEmptyTip :: ProofState InteractionReact
reactEmptyTip = do
    tip <- getDevTip
    case tip of
        Module -> return $ div_ [ class_ "empty-empty-tip" ]
                                "[empty]"
        _ -> do
            tip' <- reactTip
            return $ div_ [ class_ "empty-tip" ] $
                reactKword KwDefn >> " " >> tip'


reactEntries :: Fwd (Entry Bwd) -> ProofState InteractionReact
reactEntries F0 = return ""
reactEntries (e :> es) = do
    putEntryAbove e
    reactEntry e
    reactEntries es


reactEntry :: Entry Bwd -> ProofState InteractionReact
reactEntry (EPARAM (_ := DECL :<: ty) (x, _) k _ anchor expanded)  = do
    ty' <- bquoteHere ty
    tyd <- reactHereAt (SET :>: ty')

    return $ reactBKind k $ div_ [ class_ "entry entry-param" ] $ do
        div_ [ class_ "tm-name" ] $ fromString x
        -- TODO(joel) - show anchor in almost same way as below?
        reactKword KwAsc
        div_ [ class_ "ty" ] (locally tyd)

reactEntry e = do
    description <- if entryExpanded e
         then do
            goIn
            r <- renderReact
            goOut
            return r
         else return ""

    let anchor = case entryAnchor e of
         AnchNo -> ""
         otherAnchor -> div_ [ class_ "anchor" ] $ do
             "[["
             reactify $ entryAnchor e
             "]]"

    -- TODO entry-module vs entry-entity
    return $ div_ [ class_ "entry entry-entity" ] $ do
        locally anchor
        entryHeader e
        description


entryHeader :: Traversable f => Entry f -> InteractionReact
entryHeader e = entryHeader' (entryName e)


entryHeader' :: Name -> InteractionReact
entryHeader' name = do
    let displayName = fromString $ fst $ last name

    div_ [ class_ "entry-header" ] $ do
        button_
            [ onClick (handleToggleEntry name)
            , class_ "toggle-entry"
            ] "toggle"
        div_ [ class_ "tm-name" ] displayName


-- anchorLink :: EntityAnchor -> AttrOrHandler a
-- anchorLink

-- "Developments can be of different nature: this is indicated by the Tip"

reactTip :: ProofState InteractionReact
reactTip = do
    -- anchor <- getCurrentAnchor
    -- let link = anchorLink anchor

    tip <- getDevTip
    return $ locally (tipView tip)


reactHKind :: HKind -> Pure React'
reactHKind kind = span_ [ class_ "hole" ] $ case kind of
    Waiting    -> "?"
    Hoping     -> "HOPE?"
    (Crying s) -> fromString ("CRY <<" ++ s ++ ">>")
