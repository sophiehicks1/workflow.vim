# TL;DR;

workflow.vim is a highly customizable note taking plugin for structured note taking workflows. It's
a little like a "Build your own Evernote" kit for vim.

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

```{.vim}
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

If the `'date'` parameter is set to 0, then you can autocomplete with these commands. This won't
work with dated workflows though, since there's currently no way to prevent them from prepending
today's date to the file.

## Periodic files

Here's another real example of a workflow that I use for planning my upcoming week:

```{.vim}
      \ "Plan": {
      \   'root': '~/Weekly/plans',
      \   'date': 1,
      \   'period': 'weekly',
      \   'ext': 'md'
      \ },
```

Adding the `'period': 'weekly'` parameter means that this file is only updated weekly. In other
words whenever you run this workflow, it will normalize the date the Monday from that week, so that
you can run the `:Plan` command any time during the week and still get the same file.

Supported options are `'daily'`, `'weekly'` and `'monthly'`. Setting `'period': 'daily'` is the same
as not setting a period at all.

## Managing lists of files

In addition to the commands which open new files, each workflow defines a command to open the root
directory of that workflow. Using the above "Blog" example, that would be `:BlogList`. When combined
with tpopes vim-vinegar plugin, this makes for a simple but effective way to manage and navigate the
files you've already created using a particular workflow.

Finally, each workflow also defines a command to grep the contents of the existing files within the
workflow's root directory, loading the results into the quickfix list. Again, taking the above
"Blog" example that whould be `:BlogGrep`. Behind the scenes, running this...

```{.vim}
:BlogGrep this is a search query
```

... would delegate to this grep command ...

```{.bash}
grep -r 'this is a search query' '/Users/simon/blog/posts'
```

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
/Users/simon/Notes/capture/2015-02-27-meeting-with-tom.md` which uses [another
plugin](https://github.com/simonhicks/todo.vim) to add an item to my todo list to process the notes
in that file.

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
time the file is saved (the `PandocPreview()` function is defined in my `.vimrc`... not this plugin).

## Setting up workflow specific mappings

You can also set up workflow specific mappings, which are added as buffer local mappings at the same
phase as any onload hooks. Here's a slightly contrived example.

    "Journal": {
                 'root': '~/journal/posts',
                 'date': 1,
                 'ext': 'md',
                 'nmap': {
                   '<C-w><C-c>': ':!wc -w %<CR>'
                 },
                 'autocmd': {
                   'BufWritePost': 'call PandocPreview("~/Desktop/out.html")'
                 }
               }

Hopefully this is pretty obvious. Whenever you open a file using the `:Journal` command, the
resulting buffer will have a mapping in normal mode which counts the number of words in the file.
This also works with 'imap', 'inoremap', 'nnoremap', 'cmap' and 'cnoremap'.

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

## Running hooks manually

In addition to the above commands, for each workflow `:<workflow>LoadHooks` and
`:<workflow>CreateHooks` are created. LoadHooks, will run all the "onload" hooks and set up all the
autocommands and mappings as if the current file had been loaded as a `<workflow>` file.
`:<workflow>CreateHooks` does the same, except it runs the "oncreate" hooks too.

## Rapidly inserting paths for workflow generated files

Okay, I realise this is getting pretty esoteric at this point but stick with me!! Some of my note
taking workflows need to link to each other (for example I often include a link from one 'Note'
workflow file to another, or from an item in my todo list to a 'Capture' or 'Note' workflow file so
I can rapidly `gf` between them. Obviously you *could* use `<C-X><C-F>` to autocomplete using file
paths, but that breaks the workflow abstraction which is kind of lame. So... workflow.vim has the
option to add a `:<workflow>InsertPath' command. Here is another version of my "Capture" workflow
(described above).

```
"Capture": {
             'root': '~/Notes/capture',
             'date': 1,
             'ext': 'md',
             'insertPath': {
               'globalImap': '<c-i><c-f>',
             },
             'oncreate': "Todo process '<FILE>'"
           }
```
 
This will add a `:CaptureInsertPath <relative-path>` command which converts the given relative path
to an absolute path (so that it works with `gf`) and then append it after the cursor. The real value
here is in the tab completion, which delegates to `find /path/to/capture/root -name '*query*`. In
other words "foo" would tab complete to "2015-07-21-this-is-foo.md".

By adding the `'globalImap'` key to the config object, I'm telling workflow.vim that I also want an
insert mode mapping (which will be available throughout vim) to invoke this command. In other words
adding that `'globalImap'` value is equivalent to having the following line in your .vimrc:

```{.vim}
inoremap <c-i><c-f> <C-o>:CaptureInsertPath<space>
```

That means, if you want to insert a link to `/home/simon/Notes/capture/2015-07-21-this-is-foo.md`
you could simply type `<C-i><C-f>foo<Tab><CR>` and carry on typing (i.e. you'd still be in insert
mode after pressing enter). 

If you want the `:<workflow>InsertPath` command to be available, but don't want the global insert
mode mapping then you should just leave the `'insertPath'` config object empty (i.e. `'insertPath':
{}'`)

## KNOWN ISSUES

Several bits of this don't work on windows (I've had issues with dates, templates and grep so far,
but there may be more issues). If someone tells me they want to use those features on windows,
I can probably fix them... so let me know.
