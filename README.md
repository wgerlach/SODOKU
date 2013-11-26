DeploySoftware
==============


deploys software.


Packages
--------
package name examples: 
* mypackage
* mypackage(arg1 arg2)
* mypackage==2.3(arg1 arg2)

Variables
---------
* ${target} installation target as specified in --target=
* ${1}, ${2}.. package arguments, 
* ${source} local git repository in temp directory
* ${v1}, ${v2}.. version numbers

problem: if packages expect parameter but does not get parameter, the unresolved package variable is passed to the bash which will replace the variable with the empty string. Be careful about that!





JSON fields
-----------
* *source*: one or more source of the same source-type
   url, packages, files ; string or array of strings, creates variable ${source} that can be used in build-exec
   string=url
   hash{url, filename}
   array of above
* *source-type*: "auto"(default), "git", "download"... download is for normales files like .tar.gz
* *source-temporary*: indicates that the source id need only temporaryly and can be deleted after building
* *build-type*: exec(default), make, apt ...
* *build-exec*: is applied to each source !, uses variable ${source}
* *exec*: string or array of strings that are executed with perl system call in sequential order
  is executed only once (even if you have multiple sources)
  is executed after installation, if you need earlier execution use exec in subpackage
* *set-env*: sets environment variable in bashrc
* *_comment*: only way to make comments in json
* *dir*: create package directory in target directory with same name as package
* *test*: command to test installation
* *depends*: list of packages that wil be installed first
   TODO : arguments for dependencies not yet possible
* *subpackages*: have no names and are installed in sequential order,
		other packages can not depend on these subpackages,
		otherwise subpackages are the same as packages (I think... )
       subpackages are installed after depends
* *version*: specifies default version, e.g. v2.5 ['2','5']

Execution order
---------------
1. depends
2. subpackages
3. source
4. build(-exec)
5. set-env
6. exec
7. test

Comments
--------
Uninstall is not supported, we may add an "uninstall" key to the package description if desired.

use http://jsonlint.com/ json validator

