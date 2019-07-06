Nimatic - a static site generator
=================================

Nimatic is a flexible static site generator written in Nim.


## Layout overview

A Nimatic site has the following directory structure:

	assets/
		image.jpg
		style.css
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
* An index page.


Pages with Nimatic are directories underneath the `pages` directory, each containing two files: `meta.json`, which
defines some metadata about the page-to-be, and `page.md`, which is the Markdown content of the page-to-be.


### Nimatic templating

Nimatic templates are plain text with a couple special strings that get replaced:

* `$title` - this is the title of the current page.
* `$published-on` - this is the content of the `published-on` key from the page's `meta.json` if the key is defined,
  but is empty otherwise.
* `$content` - in a non-base template, this is the body of the page after it has been converted to HTML. In the base
  template, this is the content of the non-base template.


### meta.json

There's a handful of valid keys in `meta.json`:

* `template` - required. This is the non-base template in the `templates` directory that should be used to build
  this page.
* `title` - optional. This is the title of the page-to-be; if not given, the directory name will be used instead.
* `published-on` -  optional. This is a string that can be used in your templates as the publishing date of the page.


### page.md

This is a file containing Markdown that will become the page's body.



## Deploying/serving a site

Nimatic, by design, does not handle this step. I personally use and recommend [rclone](https://rclone) for deployment,
and for local viewing/testing, I use Python 3's `http.server` module, via `python3 -m http.server` inside the `build/` directory
of my Nimatic site.
