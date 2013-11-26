DeploySoftware
==============


deploys software.


Variables
---------
minimalistic documentation:
 version number support:
 package name examples: mypackage mypackage(arg1 arg2) mypackage==2.3(arg1 arg2)
 supported variables:
${target} installation target
${source} local git repository in temp directory
 ${1}, ${2}.. package arguments
 variable issue: if packages expect parameter but does not get parameter, the unresolved package variable is passed to the bash which will replace the variable with the empty string. Be careful about that!

 ${v1}, ${v2}.. version numbers



execution order
---------------
 depends, subpackages, source , build(-exec), set-env, exec , test


json fields
-----------
source: one or more source of the same source-type
url, packages, files ; string or array of strings, creates variable ${source} that can be used in build-exec
   string=url
   hash{url, filename}
   array of above
source-type: "auto"(default), "git", "download"... download is for stuff like .tar.gz
source-temporary: indicates that the source id need only temporaryly and can be deleted after building
build-type: exec(default), make, apt ...
build-exec: is applied to each source !, uses variable ${source}
exec: string or array of strings that are executed with perl system call in sequential order
  is executed only once (even if you have multiple sources)
  is executed after installation, if you need earlier execution use exec in subpackage
set-env: sets environment variable in bashrc
_comment: only way to make comments in json
dir: create package directory in target with same name as target
test: command to test installation
depends: list of packages that wil be installed first
   TODO : arguments for dependencies not yet possible
subpackages: have no names and are installed in sequential order,
		other packages can not depend on these subpackages,
		otherwise subpackages are the same as packages (I think... )
       subpackages are installed after depends
version : not implemented yet, ${v1}.${v2}...

Uninstall is not supported, we may add an "uninstall" key to the package description if desired.

tip: use http://jsonlint.com/ json validator