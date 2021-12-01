provider "aws" {
  region = "eu-central-1"
}

module "network" {
  source = "git@github.com:DmitriyK0807/MyProject1.git/network"
}

module "instances" {
  source     = "git@github.com:DmitriyK0807/MyProject1.git/instances"
  depends_on = module.network
}
