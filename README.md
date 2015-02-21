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

- *On load/create commands:* For each workflow there are is a very specific set of vim commands that I want
  executed immediately.

This plugin is designed to make the creation of a set of note-taking-workflow specific vim commands,
as simple as configuring a few variables.

For example this configuration...

``` {.vim}
let g:struct_workflows = {
      \"Blog":    {
      \             'root': '~/blog/posts',
      \             'date': 1,
      \             'mandatory-title': 1,
      \             'ext': 'html'
      \           }
      \}
```

... will create a `:Blog <title>` command that creates a new blog post. It does this by opening a
new html file in `~/blog/posts`, naming the file using todays date (YYYY-MM-DD), followed by the title
with non-word chars removed and spaces replaced with dashes, so `:Blog This is awesome` would open
`~/blog/posts/2014-12-01-this-is-awesome.html` (assuming the command was executed on 1st December
2014)

That configuration will also create matching TBlog, SBlog and VBlog commands to open the file in a
new tab, split and vert split respectively.

## Managing lists of files

In addition to the commands which open new files, each workflow defines 4 commands to open the root
directory of that workflow. Using the above "Blog" example, these would be `:BlogList`,
`:VBlogList`, `:TBlogList` and `:SBlogList`. When combined with tpopes vim-vinegar plugin, this
makes for a simple but effective way to manage and navigate the files you've already created using a
particular workflow.

## Running commands automatically on load/create

If you add the 'onload' key to a workflow, then the value will be executed each time you load a file
using one of the workflow ex commands. Similarly, the 'oncreate' value will be executed each time you create
a new file using one of the workflow ex commands. The name of the file being created will be
available to this command as \<FILE\>

An example of this is the following workflow that I actually use.

``` {.vim}
    "Capture": {
                  'root': "~/Notes/capture",
                  'date': 1,
                  'ext': "md",
                  'oncreate': "Todo process '<FILE>'"
                },
```

Let's say I go into a meeting with my colleague Tom, I would run `:Capture meeting with tom`. This
opens a buffer containing a file called "2015-02-27-meeting-with-tom.md" which I use to take ad hoc
notes during that meeting. Since this is a new buffer, it also runs `:Todo process
/Users/simon/Notes/capture/2015-02-27-meeting-with-tom.md` which adds an item to my todo list to
process the notes in that file (either by migrating the notes to a more permanent location or by
actually taking action).

## Setting workflow specific autocmds

Sometimes it's also useful to set up vim autocmds within a file created by a workflow ex command.
Here's another example that I use:

    "Journal": {
                 'root': '~/journal/posts',
                 'date': 1,
                 'ext': 'md',
                 'autocmd': {
                   'BufWritePost': 'call PandocPreview("~/Desktop/out.html")'
                 }
               }

This sets up an autocmd which uses pandoc to regenerate an html version of the current file every
time the file is saved.

## Templates

You can also define a template for a newly created workflow file. To do this, first create a
template file like so:

``` {.markdown}
:date: {{{ b:date }}}
:title: {{{ b:title }}}

Content...
```

Sections enclosed with `{{{ ... }}}` will be evaluated as vimscript, with the variables b:title and
b:date set to the (unsanitised) string used for the filename and the current date respectively. You
can configure the format used for b:date using `g:workflow_template_date_format`, which will be
passed to the system `date` command.

Once you've created that template file you can use it in a workflow like this:

```
"Blog": {
          'root': '~/Blog/posts',
          'date': 1,
          'ext': 'md',
          'template': '~/Blog/template.md'
        }
```

## Upcoming features

The following features aren't working yet, but will any luck I'll add them soon.

- Autocompletion for ex commands
