Nimatic - a static site generator
=================================

Nimatic is a flexible static site generator written in Nim.

## Installation

Works like most Nim packages; build and install with `nimble install`.
It's available via the [Nimble package directory](https://nimble.directory/pkg/nimatic), so
you can do `nimble install nimatic` without having to clone this repository - though if you
install it that way you'll need to grab the example site manually if you want to take a look
at it.

## Layout overview

A Nimatic site has something like the following directory structure:

	assets/
		image.jpg
		style.css
	metapages/
		meta.py
	postprocessors/
		processor.py
	pages/
		index/
			meta.json
			page.md
		example-page/
			meta.json
			page.md
	templates/
		base.html
		page.html
		example.html
		
Nimatic then generates something like the following in a directory called `build`:

	assets/
		image.jpg
		style.css
	index.html
	example-page.html


## Writing a site

At the very least, you'll need to define a couple files:

* `templates/base.html` - this is the base template that Nimatic will cause all other templates to inherit from.
* One other non-base template for your pages/posts to use.
* An index page. Technically not necessary as far as Nimatic is concerned, but your site should probably have one.

Pages with Nimatic are directories underneath the `pages` directory, each containing two files: `meta.json`, which
defines some metadata about the page-to-be, and `page.md`, which is the Markdown content of the page-to-be.

If you want an example of how a bare-bones Nimatic site works, look at the one included in this repository. Running
Nimatic in this directory will cause the site to be built, and you can then view the result in your web browser.


### Nimatic templating

Nimatic templates are interpreted as plain text (though it makes sense to write them as HTML) with a couple special
strings that get replaced:

* `$title` - this is the title of the current page.
* `$content` - in a non-base template, this is the body of the page after it has been converted to HTML. In the base
  template, this is the content of the non-base template.
  
You can add your own template variables through each page's `meta.json` file, described below.


### meta.json

`meta.json` serves as a list of keys and their values that will get replaced inside the page body. For instance, given
a `meta.json` containing `"hello": "World!"` and a `page.md` that contained `$hello`, `$hello` would end up in the rendered
page as `World!`. There are a few required keys, however:

* `template` - this is the non-base template that the page should be rendered with.

There are some other keys with special meaning to Nimatic itself, namely:

* `title` - this ends up as the title of the page passed along to the template. If not given, the name of the directory
  containing `page.md` will be used instead.
* `output-name` - this is the filename of the page sans the `.html` extension. If not given, the name of the directory
  containing `page.md` will be used instead.
* `draft` - if present, and set to `true`, then Nimatic will skip building this 


### page.md

This is a file containing Markdown that will become the page's body.


## Metapages

Your site can have an optional `metapages/` directory, holding metapages. A metapage is simply an executable file that Nimatic passes the metadata
of every non-meta page it can find via `stdin`. The metapage should then output on its `stdout` JSON with the same format as
the regular `meta.json` with an extra `body` key containing the Markdown body of the generated page. In other words, you can
write programs in whatever language you like that generate pages for your static site, possibly based off of your site's metadata.
For instance, you could write a program that generates a listing of all the tags used in your blog, and which blog entries use which tags.


## Postprocessors

Your site can have an optional `postprocessors/` directory, containing postprocessors. A postprocessor is similar to a metapage,
in that it is an executable file - though for every compiled page (even ones generated by a metapage), Nimatic will pass it the contents of that page
over `stdin`, and will overwrite the page's contents on disk with the output from the program's `stdout`. You can use this feature to further tweak and
enhance the HTML of your pages to your liking after Nimatic has generated them.


## Deploying/serving a site

Nimatic, by design, does not handle this step. I personally use and recommend [rclone](https://rclone.org) for deployment,
and for local viewing/testing, I use Python 3's `http.server` module, via `python3 -m http.server` inside the `build/` directory
of my Nimatic site.


## Build caching

Nimatic leaves a `.nimatic-cache.json` file in the root directory of your site's source (not in the `build/` folder) that
uses the last-modified time of your site's static pages to determine whether or not to build them next time it's called. Currently,
metapages are built every time Nimatic is called without exception, as Nimatic has no way of knowing whether or not they should be
rebuilt. If, for whatever reason, you want to trigger a full site rebuild from scratch, you can remove `.nimatic-cache.json`.
