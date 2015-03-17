There is rake task ready for migration from default Redmine Documents module to DMSF. Example:
> ` rake redmine:dmsf_convert_documents RAILS_ENV="production" `

This is the default invocation. It goes through all projects and all those having Documents module active and DMSF inactive are converted.

Conversion of each project:
  1. Activates DMSF for project
  1. Creates folder for each document in Document module
  1. Creates file for each document attachment in corresponding folder
  1. All descriptions are transfered to DMSF
  1. Redmine's Documents module is deactivated

There are several options to task:
  * project => _id_ or _identifier_ of project (defaults to all projects)
  * dry => _true_ or _false_ (default _false_) to perform just check without any conversion
  * invalid=replace => to perform document title invalid characters replacement for '-'

Another example for testing conversion:
> ` rake redmine:dmsf_convert_documents project=test dry=true RAILS_ENV="production" `

**Always backup your current content before you try to convert content!**