#!/usr/bin/env spack-python

import argparse

parser = argparse.ArgumentParser(description="Your script description")

parser.add_argument('-s', '--scheduler', action='store_true', help="Enable scheduler")
parser.add_argument('-c', '--concretize-args', type=str, help="Concretize arguments (provide a single string)")
parser.add_argument('-i', '--install-args', type=str, help="Install arguments (provide a single string)")
parser.add_argument('-r', '--redeploy-existing', action='store_true', help="Redeploy existing deployments")

parser.add_argument('deployments', nargs='*', help="List of deployments to apply (default is all)")

args = parser.parse_args()

import collections
import os
import yaml

import spack.extensions
spack.extensions.load_extension("stack")
from spack.extensions.stack.cmd.stack_cmds.create import *
import spack.environment

spack_stack_dir = os.getenv("SPACK_STACK_DIR")

def get_env_dir_basename(deployment):
    base = deployment["template"]
    base = base.replace("unified-dev", "ue")
    base = base.replace("-dev", "")
    return "-".join([base, deployment["compiler"]])

def deployment_already_exists(env_dir_basename, args):
    path_to_check = os.path.join(spack_stack_dir, "envs", env_dir_basename)
    return os.path.isdir(path_to_check)

def is_deployment_requested(env_dir_basename, deployment, args):
    if deployment["template"] in args.deployments:
        return True
    if deployment["template"] + "/" + deployment["compiler"] in args.deployments:
        return True
    if args.redeploy_existing:
        return True
    return not deployment_already_exists(env_dir_basename, args)

def get_create_env_settings(env_dir_basename, deployment, deployments):
    dict = {}
    dict["site"] = "acorn"
    dict["template"] = deployment["template"]
    dict["dir"] = os.path.join(spack_stack_dir, "envs")
    dict["name"] = env_dir_basename
    if "upstreams" in deployment:
        upstream_full_paths = []
        for upstream_template in deployment["upstreams"]:
            for _candidate_upstream in deployments.values():
                if (_candidate_upstream["template"] == upstream_template) and (_candidate_upstream["compiler"] == deployment["compiler"]):
                    upstream_basename = get_env_dir_basename(_candidate_upstream)
                    upstream_full_path = os.path.join(spack_stack_dir, "envs", upstream_basename, "install")
                    upstream_full_paths.append(upstream_full_path)
                    break
        dict["upstreams"] = upstream_full_paths
    dict["compiler"] = deployment["compiler"]

    return dict

# Load deployments.yaml configuration
print("Loading deployments.yaml")
script_directory = os.path.dirname(os.path.abspath(__file__))
deployments_yaml_path = os.path.join(script_directory, "deployments.yaml")
with open(deployments_yaml_path, "r") as f:
    deployments_yaml = yaml.safe_load(f)

# Generate deployments object, including iterating over compilers
deployments = collections.OrderedDict()

for _deployment in deployments_yaml["core_deployments"]: # + deployments_yaml["addon_deployments"]:
    for _compiler in _deployment["compilers"]:
        deployment = _deployment.copy()
        del(deployment["compilers"])
        deployment["compiler"] = _compiler
        env_dir_basename = get_env_dir_basename(deployment)
        deployments[env_dir_basename] = deployment
        print("Registered deployment:", env_dir_basename)

print("="*30)

# Create and install each deployment
for env_dir_basename, deployment in deployments.items():
    if not is_deployment_requested(env_dir_basename, deployment, args):
        continue
    print("="*30)
    # Create env based on config
    stack_settings = get_create_env_settings(env_dir_basename, deployment, deployments)
    env_dir_full_path = os.path.join(spack_stack_dir, "envs", env_dir_basename)
    print(f"Creating environment for {deployment['template']}/{deployment['compiler']}")
    print(f"  at {env_dir_full_path}")
    stack_env = StackEnv(**stack_settings)
    stack_env.write()
    stack_env.check_umask()
    env = spack.environment.Environment(env_dir_full_path)
    spack.environment.activate(env)
    env.concretize()
## Install (PBS Pro if --scheduler/-s)
