# THIS IS NOT FINISHED YET!
This plugin is work in progress, so the instructions below aren't implemented yet (or alternatively
they're wrong).

If the concept of this plugin interests you though, it's probably worth checking back once every
couple of weeks or so... I *will* finish it within a couple of months at most, because I actually
need to use it!

# workflow.vim

I take lots of notes in vim for lots of different purposes and in lots of different ways. Over time
I've started to notice several distinct note taking workflows, and there are a number of patterns
and features that are shared between some or all of these workflows.

- *Directory structure:* Each workflow has a single directory which contains all the files relevant
  for that workflow. Within that directory there is a predictable path structure that is
consistently applied for all files within that workflow, but not necessarily the same as for any
other workflows. Sometimes the directory structure is nested, sometimes it's flat.

- *File type:* Although not all note-like files share the same filetype, all files within a
  particular workflow share the same filetype.

- *File naming conventions:* Many workflows contain files of the form 'YYYY-MM-DD' or
  'YYYY-MM-DD-TITLE' where the date is almost always the date the file was first created. All my
workflows use only word chars and '-' in the file names.

- *On load commands:* For each workflow there are is a very specific set of vim commands that I want
  executed immediately.

This plugin is designed to make the creation of a set of note-taking-workflow specific vim commands,
as simple as configuring a few variables.

For example this configuration...

``` {.vim}
let blog = {}
let blog['name'] = "Blog"
let blog['use-date'] = 1
let blog['root'] = '~/MyBlog'
let blog['nested'] = 0
let blog['title-mandatory'] = 1
let blog['filetype'] = 'html'
let blog['on-load'] = 'DoWhat :w<CR>:!open %'

call notes#createWorkflow(blog)
```

... will create a `:Blog <title>` command that creates a new blog post. It does this by opening a
new html file in `~/MyBlog`. It names the file using todays date (YYYY-MM-DD), followed by the title
with non-word chars removed and spaces replaced with dashes. The file is opened with the `:DoWhat`
command preset to `:w<CR>:!open %`.

That configuration will also create matching TBlog, SBlog and VBlog commands to open the file in a
new tab, split and vert split respectively.
