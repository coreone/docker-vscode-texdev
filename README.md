# coreone/docker-vscode-texdev

## What is vscode-texdev

This is a multipurpose container image when developing with [Python][3], [Puppet][4], or
[Terraform][5].  This image is not meant as a base image to be inherited from.  Instead,
it is to be used with something like [VS Code][2] with devcontainer to run code while
developing and testing.

## How to use this image

Provided in this repository is a `devcontainer.json` file.  Place this file in a
`.devcontainer` directory under a repository, workspace, etc. so that [VS Code][2] will
recognize it as the configuration for a
[Dev Container](https://code.visualstudio.com/docs/remote/containers).  [VS Code][2]
should then run and connect to the container every time you open that repository,
workspace, etc.

[2]: https://code.visualstudio.com/ "VS Code"
[3]: https://www.python.org/ "Python"
[4]: https://puppet.com/ "Puppet"
[5]: https://www.terraform.io/ "Terraform"
