variable "target_host" {
  type        = string
  description = "DNS host to deploy to"
}

variable "target_user" {
  type        = string
  description = "SSH user used to connect to the target_host"
  default     = "root"
}

variable "target_port" {
  type        = number
  description = "SSH port used to connect to the target_host"
  default     = 22
}

variable "ssh_private_key" {
  type        = string
  description = "Content of private key used to connect to the target_host"
  default     = ""
}

variable "ssh_private_key_file" {
  type        = string
  description = "Path to private key used to connect to the target_host"
  default     = ""
}

variable "ssh_agent" {
  type        = bool
  description = "Whether to use an SSH agent. True if not ssh_private_key is passed"
  default     = null
}

variable "extra_build_args" {
  type        = list(string)
  description = "List of arguments to pass to the nix builder"
  default     = []
}

variable "build_on_target" {
  type        = bool
  description = "Avoid building on the deployer."
  default     = false
}

variable "triggers" {
  type        = map(string)
  description = "Triggers for deploy"
  default     = {}
}

variable "keys" {
  type        = map(string)
  description = "A map of filename to content to upload as secrets in /var/keys"
  default     = {}
}

variable "flake" {
  type        = string
  description = "Which flake to deploy."
}

variable "flake_host" {
  type = string
  description = "The flake host to instantiate."
}

variable "delete_older_than" {
  type        = string
  description = "Can be a list of generation numbers, the special value old to delete all non-current generations, a value such as 30d to delete all generations older than the specified number of days (except for the generation that was active at that point in time), or a value such as +5 to keep the last 5 generations ignoring any newer than current, e.g., if 30 is the current generation +5 will delete generation 25 and all older generations."
  default     = "+1"
}

# --------------------------------------------------------------------------

locals {
  triggers = {
    deploy_nixos_drv  = data.external.nixos-instantiate.result["drvPath"]
    deploy_nixos_keys = sha256(jsonencode(var.keys))
  }

  extra_build_args = concat([
    "--option", "substituters", data.external.nixos-instantiate.result["substituters"],
    "--option", "trusted-public-keys", data.external.nixos-instantiate.result["trustedPublicKeys"],
    ],
    var.extra_build_args,
  )
  ssh_private_key_file = var.ssh_private_key_file == "" ? "-" : var.ssh_private_key_file
  ssh_private_key      = local.ssh_private_key_file == "-" ? var.ssh_private_key : file(local.ssh_private_key_file)
  ssh_agent            = var.ssh_agent == null ? (local.ssh_private_key != "") : var.ssh_agent
  build_on_target      = var.build_on_target
}

# used to detect changes in the configuration
data "external" "nixos-instantiate" {
  program = [
    "${path.module}/nixos-instantiate.sh",
    var.flake,
    var.flake_host,
  ]
}

resource "null_resource" "deploy_nixos" {
  triggers = merge(var.triggers, local.triggers)

  connection {
    type        = "ssh"
    host        = var.target_host
    port        = var.target_port
    user        = var.target_user
    agent       = local.ssh_agent
    timeout     = "100s"
    private_key = local.ssh_private_key == "-" ? "" : local.ssh_private_key
  }

  # copy the secret keys to the host
  provisioner "file" {
    content     = jsonencode(var.keys)
    destination = "packed-keys.json"
  }

  # FIXME: move this to nixos-deploy.sh
  provisioner "file" {
    source      = "${path.module}/unpack-keys.sh"
    destination = "unpack-keys.sh"
  }

  # FIXME: move this to nixos-deploy.sh
  provisioner "file" {
    source      = "${path.module}/maybe-sudo.sh"
    destination = "maybe-sudo.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x unpack-keys.sh maybe-sudo.sh",
      "./maybe-sudo.sh ./unpack-keys.sh ./packed-keys.json",
    ]
  }

  # do the actual deployment
  provisioner "local-exec" {
    interpreter = concat([
      "${path.module}/nixos-deploy.sh",
      data.external.nixos-instantiate.result["drvPath"],
      data.external.nixos-instantiate.result["outPath"],
      "${var.target_user}@${var.target_host}",
      var.target_port,
      local.build_on_target,
      local.ssh_private_key == "" ? "-" : local.ssh_private_key,
      "switch",
      var.delete_older_than,
      ],
      local.extra_build_args
    )
    command = "ignoreme"
  }
}

# --------------------------------------------------------------------------

output "id" {
  description = "random ID that changes on every nixos deployment"
  value       = null_resource.deploy_nixos.id
}

