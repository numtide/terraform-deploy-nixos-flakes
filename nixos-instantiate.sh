#! /usr/bin/env bash
set -euo pipefail

# Args
flake=$1
flake_host=$2
shift 2

flakeFlags=(--extra-experimental-features 'nix-command flakes')

# --recreate-lock-file|--no-update-lock-file|--no-write-lock-file|--no-registries|--commit-lock-file)
#   lockFlags+=("$i")

nixosEval() {
  nix "${flakeFlags[@]}" eval --json "$flake#nixosConfigurations.\"$flake_host\".$1"
}

# Evals
currentSystem=$(nixosEval config.nixpkgs.system)
drvPath=$(nixosEval config.system.build.toplevel.drvPath)
outPath=$(nixosEval config.system.build.toplevel.outPath)
substituters=$(nixosEval config.nix.binaryCaches | jq 'join(" ")')
trustedPublicKeys=$(nixosEval config.nix.binaryCachePublicKeys | jq 'join(" ")')

# Output JSON
cat <<JSON
{
  "currentSystem": $currentSystem,
  "drvPath": $drvPath,
  "outPath": $outPath,
  "substituters": $substituters,
  "trustedPublicKeys": $trustedPublicKeys
}
JSON
