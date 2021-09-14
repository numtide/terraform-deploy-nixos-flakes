# terraform-deploy-nixos-flakes

This is a fork of https://github.com/tweag/terraform-nixos/tree/646cacb12439ca477c05315a7bfd49e9832bc4e3/deploy_nixos

The module was trying to do too many things at once. This one is just trying
to deploy flakes.

## Usage

### Secret handling

Keys can be passed to the "keys" attribute. Each key will be installed under
`/var/keys/${key}` with the content as the value.

For services to access one of the keys, add the service user to the "keys"
group.

The target machine needs `jq` installed prior to the deployment (as part of
the base image). If `jq` is not found it will try to use a version from
`<nixpkgs>`.

### Disabling sandboxing

Unfortunately some time it's required to disable the nix sandboxing. To do so,
add `["--option", "sandbox", "false"]` to the "extra_build_args" parameter.

If that doesn't work, make sure that your user is part of the nix
"trusted-users" list.

### Non-root `target_user`

It is possible to connect to the target host using a user that is not `root`
under certain conditions:

* sudo needs to be installed on the machine
* the user needs password-less sudo access on the machine

This would typically be provisioned in the base image.

### Binary cache configuration

One thing that might be surprising is that the binary caches (aka
substituters) are taken from the machine configuration. This implies that the
user Nix configuration will be ignored in that regard.

## Dependencies

* `bash` 4.0+
* `nix`
* `openssh`
* `readlink` with `-f` (coreutils or busybox)

## Known limitations

The deployment machine requires Nix with access to a remote builder with the
same system as the target machine.

Because Nix code is being evaluated at "terraform plan" time, deploying a lot
of machine in the same target will require a lot of RAM.

All the secrets share the same "keys" group.

When deploying as non-root, it assumes that passwordless `sudo` is available.

The target host must already have NixOS installed.

### config including computed values

The module doesn't work when `<computed>` values from other resources are
interpolated with the "config" attribute. Because it happens at evaluation
time, terraform will render an empty drvPath.

see also:
* https://github.com/hashicorp/terraform/issues/16380
* https://github.com/hashicorp/terraform/issues/16762
* https://github.com/hashicorp/terraform/issues/17034

<!-- terraform-docs-start -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.12 |

## Providers

| Name | Version |
|------|---------|
| external | n/a |
| null | n/a |

## Inputs

TODO: re-generate

## Outputs

| Name | Description |
|------|-------------|
| id | random ID that changes on every nixos deployment |

<!-- terraform-docs-end -->
