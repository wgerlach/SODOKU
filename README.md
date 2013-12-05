DeploySoftware
==============


deploys software.


Usage
--------

> deploy_software.pl --target=<target> [package ...]

Example:
> deploy_software.pl --target=/home/ubuntu/ aweclient

* use --new to overwrite existing files and directories
* use --repository to specify url to repository, default fetches repository.json from this git-repository

package name examples: 
* mypackage
* mypackage(arg1 arg2)
* mypackage==2.3(arg1 arg2)

Variables
---------
* ${target} installation target as specified in --target
* ${1}, ${2}.. package arguments 
* ${source-dir} directory of downloaded source repository
* ${source-file} filename of downloaded source file
* ${v1}, ${v2}.. version numbers
* ${ptarget} current package directory as defined by ptarget

problem: if packages expect parameter but does not get parameter, the unresolved package variable is passed to the bash which will replace the variable with the empty string. Be careful about that!


JSON fields
-----------
* *source*: one or more source of the same source-type
  * a source consists of a url and optionally a filename {"url":<url>, "filename":<filename>}
  * {"url":<url>} can also be directly written as url:<url>
  * examples: "url" or ["url1", "url2"] or [{"url":<url1>, "filename":<filename>}, "url2"]
  * creates variable ${source} that can be used in field build-exec
* *source-type*: will be autodetected if possible, otherwise: "git", "download"... download is for normales files like .tar.gz
* *source-temporary*: indicates that the source directory is needed only temporaryly and can be deleted after building
* *build-type*: exec(default), make, apt ...
* *build-exec*: is applied to each source !, uses variable ${source}
* *exec*: string or array of strings that are executed with perl system call in sequential order
  * is executed only once (even if you have multiple sources)
  * is executed after installation, if you need earlier execution use exec in subpackage
* *set-env*: sets environment variable in ~/.bashrc
* *_comment*: only way to make comments in json
* *ptarget* allows to define a package specfic target location that is different from global target location
* *dir*: boolean, short for ptarget=${target}<packagename>/
* *test*: command to test installation
* *depends*: list of packages that wil be installed first
  * TODO : arguments for dependencies not yet possible
* *subpackages*: have no names and are installed in sequential order,
  * other packages can not depend on these subpackages,
  * subpackages can inherit ${ptarget}
  * subpackages are installed after depends
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

