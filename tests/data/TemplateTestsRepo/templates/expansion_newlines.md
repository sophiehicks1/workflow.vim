When template expansion code is on its own line, that line is removed if the
expansion returns null, but preserved if the expansion returns content

before null expansion
{{{ return v:null }}}
after null expansion

before contentful expansion
{{{ return 'content from expansion' }}}
after contentful expansion

Inline template expansion code like "{{{ return v:null }}}" that returns null
has no newlines removed.
