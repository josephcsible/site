--------------------------------------------------------------------------------
{-# LANGUAGE LambdaCase        #-}
{-# LANGUAGE OverloadedStrings #-}

import           Control.Monad
import           Data.Char           (toUpper)
import           Data.Maybe
import           Data.Monoid
import           Hakyll
import           Hakyll.Web.Series
import           Text.Pandoc         (Pandoc)
import           Text.Pandoc.Options

--------------------------------------------------------------------------------
main :: IO ()
main = hakyll $ do
    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match (fromList ["about.markdown", "contact.markdown"]) $ do
        route   $ setExtension "html"
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    match "assets/csl/*" $ compile cslCompiler

    match "assets/bib/*" $ compile biblioCompiler

    tags <- buildTags "posts/*" (fromCapture "tags/*.html")

    series <- buildSeries "posts/*" (fromCapture "series/*.html")

    tagsRules tags $ \tag pattrn -> do
        let title = "Posts tagged \"" ++ tag ++ "\""
        route idRoute
        compile $ do
            let ctx = postListCtx title $ recentFirst =<< loadAll pattrn
            makeItem ""
                >>= loadAndApplyTemplate "templates/tag.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    tagsRules series $ \(s:erie) pattrn -> do
        let title = toUpper s : erie
        route idRoute
        compile $ do
            let ctx = postListCtx title $ chronological =<< loadAll pattrn
            makeItem ""
                >>= loadAndApplyTemplate "templates/series.html" ctx
                >>= loadAndApplyTemplate "templates/default.html" ctx
                >>= relativizeUrls

    match "posts/*" $ do
        let ctx = postFullCtx tags series
        route $ setExtension "html"
        compile $ postCompiler
              >>= loadAndApplyTemplate "templates/post.html"    ctx
              >>= saveSnapshot "content"
              >>= loadAndApplyTemplate "templates/default.html" ctx
              >>= relativizeUrls

    match "index.html" $ do
        route idRoute
        compile $ do
            let indexCtx = postListCtx "Home" $ recentFirst =<< loadAll "posts/*"
            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    create ["rss.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = postCtx <> bodyField "description"
            posts <- fmap (take 10) . recentFirst =<<
                loadAllSnapshots "posts/*" "content"
            renderRss feedConfiguration feedCtx posts

    match "templates/*" $ compile templateBodyCompiler

--------------------------------------------------------------------------------

postCompiler :: Compiler (Item String)
postCompiler =
  writePandocWith (def { writerHTMLMathMethod = MathML Nothing
                       , writerHighlight = True }) <$>
  readPandocOptionalBiblio

readPandocOptionalBiblio :: Compiler (Item Pandoc)
readPandocOptionalBiblio = do
  item <- getUnderlying
  getMetadataField item "bibliography" >>= \case
    Nothing -> readPandocWith defaultHakyllReaderOptions =<< getResourceBody
    Just bibFile -> do
      maybeCsl <- getMetadataField item "csl"
      join $ readPandocBiblio defaultHakyllReaderOptions
                          <$> load (fromFilePath ("assets/csl/" ++ fromMaybe "chicago.csl" maybeCsl))
                          <*> load (fromFilePath ("assets/bib/" ++ bibFile))
                          <*> getResourceBody


--------------------------------------------------------------------------------

postCtx :: Context String
postCtx = mconcat
    [ dateField "date" "%B %e, %Y"
    , defaultContext ]

postFullCtx :: Tags -> Tags -> Context String
postFullCtx tags series = mconcat
  [ seriesField series
  , tagsField "tags" tags
  , postCtx ]


postListCtx :: String -> Compiler [Item String] -> Context String
postListCtx title posts = mconcat
  [ listField "posts" postCtx posts
  , constField "title" title
  , defaultContext ]

--------------------------------------------------------------------------------

feedConfiguration :: FeedConfiguration
feedConfiguration = FeedConfiguration
  { feedTitle = "Donnacha Oisin Kidney's Blog"
  , feedDescription = "Mainly writing about programming"
  , feedAuthorName = "Donnacha Oisin Kidney"
  , feedAuthorEmail = "mail@doisinkidney.com"
  , feedRoot = "http://oisdk.netsoc.co"}
