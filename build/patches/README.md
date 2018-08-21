This directory contains Usernetes patch set for Kubernetes and its dependencies.
We will propose our patch set to the Kubernetes upstream later.

## Contributing

Please feel free to replace/add/remove `*.patch` files in this directory!

Steps (e.g. for Kubernetes):
* Clone the upstream Kubernetes (`git clone https://github.com/kubernetes/kubernetes.git`)
* Checkout `KUBERNETES_COMMIT` specified in [`../Taskfile.yml`](../Taskfile.yml)
* Apply patches in this directory (`git am *.patch`)
* Commit your own change with `Signed-off-by` line (`git commit -a -s`)
* Consider melding your change into existing commits if your change is trivial (`git rebase -i ...`)
* Run `git format-patch upstream/master` and put the new patch set into this directory.
* Open a PR to the Usernetes repo. For changes to the Kubernetes patch set, please sign [the Kubernetes CLA](https://github.com/kubernetes/community/blob/master/CLA.md).
  [_Your Github email address must match the same address you use when signing the CLA._](https://github.com/kubernetes/community/blob/master/CLA.md#4-ensure-your-github-e-mail-address-matches-address-used-to-sign-cla). When you contribute to the Usernetes repo first time, please include "[X] I signed the Kubernetes CLA" in your PR description text.

Note: We may squash your commit to another commit but we will keep your `Signed-off-by` line.
