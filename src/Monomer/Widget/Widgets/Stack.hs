{-# LANGUAGE MultiWayIf #-}

module Monomer.Widget.Widgets.Stack (hstack, vstack) where

import Control.Monad
import Data.Sequence ((<|))

import qualified Data.Sequence as Seq

import Monomer.Common.Tree
import Monomer.Common.Types
import Monomer.Widget.Types
import Monomer.Widget.BaseContainer
import Monomer.Widget.Util

hstack :: (Monad m) => [WidgetInstance s e m] -> WidgetInstance s e m
hstack children = (defaultWidgetInstance "hstack" (makeStack True)) {
  _instanceChildren = Seq.fromList children
}

vstack :: (Monad m) => [WidgetInstance s e m] -> WidgetInstance s e m
vstack children = (defaultWidgetInstance "vstack" (makeStack False)) {
  _instanceChildren = Seq.fromList children
}

makeStack :: (Monad m) => Bool -> Widget s e m
makeStack isHorizontal = createContainer {
    _widgetPreferredSize = containerPreferredSize preferredSize,
    _widgetResize = containerResize resize
  }
  where
    preferredSize renderer app childrenPairs = Node reqSize childrenReqs where
      reqSize = SizeReq (calcPreferredSize childrenPairs) FlexibleSize FlexibleSize
      childrenReqs = fmap snd childrenPairs

    resize app viewport renderArea widgetInstance childrenPairs = (widgetInstance, assignedArea) where
      Rect l t w h = renderArea
      visibleChildren = Seq.filter (_instanceVisible . fst) childrenPairs
      policySelector = if isHorizontal then _sizePolicyWidth else _sizePolicyHeight
      sizeSelector = if isHorizontal then _w else _h
      rectSelector = if isHorizontal then _rw else _rh
      mSize = if isHorizontal then w else h
      mStart = if isHorizontal then l else t
      sChildren = Seq.filter (\c -> policySelector (nodeValue $ snd c) == StrictSize) visibleChildren
      fChildren = Seq.filter (\c -> policySelector (nodeValue $ snd c) == FlexibleSize) visibleChildren
      rChildren = Seq.filter (\c -> policySelector (nodeValue $ snd c) == RemainderSize) visibleChildren
      remainderCount = length rChildren
      remainderExist = not $ null rChildren
      sSize = sizeSelector $ calcPreferredSize sChildren
      fSize = sizeSelector $ calcPreferredSize fChildren
      fRatio = if | mSize - sSize > fSize &&     remainderExist -> 1
                  | mSize - sSize > fSize && not remainderExist -> (mSize - sSize) / fSize
                  | mSize - sSize > 0                           -> (mSize - sSize) / fSize
                  | otherwise                                   -> 0
      remainderTotal = mSize - (sSize + fSize * fRatio)
      remainderUnit = if remainderExist then max 0 remainderTotal / fromIntegral remainderCount else 0
      newViewports = Seq.reverse revViewports
      assignedArea = Seq.zip newViewports newViewports
      (revViewports, _) = foldl foldHelper (Seq.empty, mStart) childrenPairs
      foldHelper (accum, offset) childPair = (newSize <| accum, offset + rectSelector newSize) where
        newSize = resizeChild offset childPair
      resizeChild offset childPair = if not (_instanceVisible widgetInstance) then emptyRect else if isHorizontal then hRect else vRect where
        widgetInstance = fst childPair
        req = nodeValue $ snd childPair
        srSize = _sizeRequested req
        emptyRect = Rect l t 0 0
        hRect = Rect offset t newSize h
        vRect = Rect l offset w newSize
        newSize = case policySelector req of
          StrictSize -> sizeSelector srSize
          FlexibleSize -> sizeSelector srSize * fRatio
          RemainderSize -> remainderUnit

    calcPreferredSize childrenPairs = Size width height where
      visiblePairs = Seq.filter (_instanceVisible . fst) childrenPairs
      visibleChildren = fmap (nodeValue . snd) visiblePairs 
      maxWidth = if Seq.null visibleChildren then 0 else (maximum . fmap (_w . _sizeRequested)) visibleChildren
      sumWidth = (sum . fmap (_w . _sizeRequested)) visibleChildren
      maxHeight = if null visibleChildren then 0 else (maximum . fmap (_h . _sizeRequested)) visibleChildren
      sumHeight = (sum . fmap (_h . _sizeRequested)) visibleChildren
      width = if isHorizontal then sumWidth else maxWidth
      height = if isHorizontal then maxHeight else sumHeight
