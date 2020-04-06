import json
import markdown
import os
import osproc
import streams
import strformat
import strutils
import times

const
  metaFile = "meta.json"
  pageFile = "page.md"
  baseTemplateFile = "base.html"
  assetDir = "assets"
  buildDir = "build"
  templateDir = "templates"
  pageDir = "pages"
  postprocessorDir = "postprocessors"
  metapageDir = "metapages"
  cacheFile = ".nimatic-cache.json"


proc copyAssets() =
  if dirExists(buildDir) == false:
    createDir(buildDir)
  if dirExists(assetDir):
    echo "Copying assets"
    os.copyDir(assetDir, joinPath(buildDir, assetDir))

proc shouldRebuild(inputTimestamp: int64, outputName: string): bool =
  if fileExists(cacheFile) == false:
    return true
  var cacheData = parseFile(cacheFile)
  if cacheData.hasKey(outputName) == false:
    return true
  return cacheData[outputName]["timestamp"].getInt() < inputTimestamp
  

proc recordBuilt(outputName: string, outputTimestamp: int64) =
  var cacheData: JsonNode
  if fileExists(cacheFile):
    cacheData = parseFile(cacheFile)
  else:
    cacheData = newJObject()
  cacheData[outputName] = newJObject()
  cacheData[outputName]["timestamp"] = newJInt(outputTimestamp)
  cacheData[outputName]["unprocessed"] = newJBool(true)
  writeFile(cacheFile, cacheData.pretty)


proc shouldPreprocess(outputName: string): bool =
  if fileExists(cacheFile) == false:
    return true
  var cacheData = parseFile(cacheFile)
  if cacheData.hasKey(outputName) == false:
    return true
  return cacheData[outputName]["unprocessed"].getBool()

proc recordPreprocessed(outputName: string) =
  var cacheData = parseFile(cacheFile)
  cacheData[outputName]["unprocessed"] = newJBool(false)
  writeFile(cacheFile, cacheData.pretty)

proc compilePage(metadata: JsonNode, pageBody, outputName: string) =
  if metadata{"draft"}.getBool() == true:
    # don't compile drafts
    return
  var title = outputName
  if metadata.contains("title"):
    title = metadata["title"].getStr()
  var templateTarget: string
  if metadata.contains("template") == false:
    echo "No target template given for entry ", outputName
    quit(1)
  templateTarget = metadata["template"].getStr()
  var pageTemplate = readFile(joinPath(templateDir, templateTarget))
  var baseTemplate = readFile(joinPath(templateDir, baseTemplateFile))
  baseTemplate = baseTemplate.replace("$title", title)
  var compiledTemplate = baseTemplate.replace("$content", pageTemplate)
  for jsonKey, jsonValue in metadata.pairs:
    compiledTemplate = compiledTemplate.replace("$" & jsonKey, jsonValue.getStr())
  var compiledMarkdown = markdown(pageBody)
  var compiledPage = compiledTemplate.replace("$content", compiledMarkdown)
  var outputFilename = outputName & ".html"
  var outputPath = joinPath(buildDir, outputFilename)
  writeFile(outputPath, compiledPage)
  var currentTime = getTime().toUnix()
  recordBuilt(outputName, currentTime)
  echo "Compiled page ", outputName

proc compileMetapages() =
  if dirExists(metapageDir) == false:
    return
  echo "Compiling metapages"
  var allMetadata = newJArray()
  for kind, entry in walkDir(pageDir, relative=true):
    if kind != pcDir:
      continue
    var jsonContents = readFile(joinPath(pageDir, entry, metaFile))
    var singleMetadata = parseJson(jsonContents)
    if singleMetadata.contains("output-name") == false:
      singleMetadata.add("output-name", newJString(entry))
    var pageContents = readFile(joinPath(pageDir, entry, pageFile))
    singleMetadata.add("page-source", newJString(pageContents))
    if singleMetadata{"draft"}.getBool() == false:
      allMetadata.add(singleMetadata)
  for kind, entry in walkDir(metapageDir, relative=true):
    if kind != pcFile:
      continue
    var metapagePath = joinPath(metaPageDir, entry)
    if fpUserExec in getFilePermissions(metapagePath) == false:
      continue
    echo "Building metapage ", entry
    var metapage = startProcess(metapagePath)
    metapage.inputStream.write(allMetadata.pretty)
    metapage.inputStream.close()
    var errorCode = waitForExit(metapage)
    var metadata = metapage.outputStream.readAll()
    if errorCode != 0:
        echo entry, " exited with non-zero error code"
        echo metadata
        quit(errorCode)
    var metaJson = parseJson(metadata)
    var outputName = metaJson["output-name"].getStr()
    var pageBody = metaJson["body"].getStr() 
    compilePage(metaJson, pageBody, outputName)

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
      if metadata.contains("output-name"):
        outputName = metadata["output-name"].getStr()
    except JsonParsingError:
      echo "Error parsing meta.json for entry ", outputName, ": ", getCurrentExceptionMsg()
      quit(1)
    var pageLastModified = getFileInfo(joinPath(pageDir, entry, pageFile)).lastWriteTime
    var metaLastModified = getFileInfo(joinPath(pageDir, entry, metaFile)).lastWriteTime
    var lastModified = pageLastModified
    if metaLastModified > pageLastModified:
      lastModified = metaLastModified
    if shouldRebuild(lastModified.toUnix(), outputName):
      var markdownData = readFile(joinPath(pageDir, entry, pageFile))
      compilePage(metadata, markdownData, outputName)

proc runPostprocessors() =
  if dirExists(postprocessorDir) == false:
    echo postprocessorDir, " not found, not running postprocessors"
    return
  echo "Running postprocessors"
  for buildKind, buildEntry in walkDir(buildDir, relative=true):
    if buildKind != pcFile:
      continue
    var outputName = splitFile(buildEntry).name
    if shouldPreprocess(outputName) == false:
        continue
    for kind, entry in walkDir(postprocessorDir, relative=true):
      if kind != pcFile:
        continue
      var postprocessorPath = joinPath(postprocessorDir, entry)
      if fpUserExec in getFilePermissions(postprocessorPath) == false:
        continue
      var pagePath = joinPath(buildDir, buildEntry)
      var unprocessedData = readFile(pagePath)
      var postprocessor = startProcess(postprocessorPath)
      echo "Running postprocessor ", entry, " on built page ", buildEntry
      postprocessor.inputStream.write(unprocessedData)
      postprocessor.inputStream.close()
      var errorCode = waitForExit(postprocessor)
      var postprocessedData = postprocessor.outputStream.readAll()
      if errorCode != 0:
        echo entry, " exited with non-zero error code"
        echo postProcessedData
        quit(errorCode)
      writeFile(pagePath, postprocessedData)
    recordPreprocessed(outputName)

copyAssets()
compileMetapages()
compilePages()
runPostprocessors()
echo "Done!"
