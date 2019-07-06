import json
import markdown
import os
import strformat
import strutils

const
  metaFile = "meta.json"
  pageFile = "page.md"
  baseTemplateFile = "base.html"
  assetDir = "assets"
  buildDir = "build"
  templateDir = "templates"
  pageDir = "pages"


proc copyAssets() =
  echo "Copying assets"
  os.copyDir(assetDir, joinPath(buildDir, assetDir))

proc compilePages() =
  echo "Compiling pages"
  for kind, entry in walkDir(pageDir, relative=true):
    if kind != pcDir:
      # ignore non-dir entries in the pages directory
      continue
    # assume by default that the output page name is the same as the directory
    var outputName = entry
    var metadata: JsonNode
    try:
      var jsonContents = readFile(joinPath(pageDir, entry, metaFile))
      metadata = parseJson(jsonContents)
    except JsonParsingError:
      echo "Error parsing meta.json for entry ", outputName, ": ", getCurrentExceptionMsg()
      quit(1)
    if metadata.contains("output-name"):
      outputName = metadata["output-name"].getStr()
    var title = outputName
    if metadata.contains("title"):
      title = metadata["title"].getStr()
    var publishDate = ""
    if metadata.contains("published-on"):
      publishDate = metadata["published-on"].getStr()
    var templateTarget: string
    if metadata.contains("template") == false:
      echo "No target template given for entry ", outputName
      quit(1)
    templateTarget = metadata["template"].getStr()
    var pageTemplate = readFile(joinPath(templateDir, templateTarget))
    pageTemplate = pageTemplate.replace("$title", title)
    pageTemplate = pageTemplate.replace("$published-on", publishDate)
    var baseTemplate = readFile(joinPath(templateDir, baseTemplateFile))
    baseTemplate = baseTemplate.replace("$title", title)
    var compiledTemplate = baseTemplate.replace("$content", pageTemplate)
    var markdownData = readFile(joinPath(pageDir, entry, pageFile))
    var compiledMarkdown = markdown(markdownData)
    var compiledPage = compiledTemplate.replace("$content", compiledMarkdown)
    var outputFilename = outputName & ".html"
    var outputPath = joinPath(buildDir, outputFilename)
    writeFile(outputPath, compiledPage)
    echo "Compiled page ", outputName 

copyAssets()
compilePages()
echo "Done!"
