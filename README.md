Scripts for building [Orange](http://orange.biolab.si/) application installers

[![Build macOS dmg](https://github.com/ales-erjavec/orange3-installers/actions/workflows/build-macos-installer.yml/badge.svg)](https://github.com/ales-erjavec/orange3-installers/actions/workflows/build-macos-installer.yml)

[![Build Windows Conda Installer](https://github.com/ales-erjavec/orange3-installers/actions/workflows/build-conda-installer.yml/badge.svg)](https://github.com/ales-erjavec/orange3-installers/actions/workflows/build-conda-installer.yml)

[![Build Windows Pip Installer](https://github.com/ales-erjavec/orange3-installers/actions/workflows/build-win-installer.yml/badge.svg)](https://github.com/ales-erjavec/orange3-installers/actions/workflows/build-win-installer.yml)

[![Build Windows Portable Installer](https://github.com/ales-erjavec/orange3-installers/actions/workflows/build-win-portable.yml/badge.svg)](https://github.com/ales-erjavec/orange3-installers/actions/workflows/build-win-portable.yml)


To build installers for a specific release, create a new branch under releases e.g.`releases/3.8.0`,
edit the GH Actions config files to replace BUILD_BRANCH with the required branch or
tag (i.e. `3.8.0`) in the orange3 git repo. Also replace `BUILD_LOCAL` from `1` to `""` if
binary packages are already available from conda-forge/PyPi.

Built installers are kept as build artefacts of the workflow runs.
