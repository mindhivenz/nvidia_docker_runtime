# nvidia_docker_runtime

This is a PDK based module https://puppet.com/pdk/latest/pdk_generating_modules.html .

#### Table of Contents

1. [Description](#description)
2. [Usage - Configuration options and additional functionality](#usage)

## Description

Modifies Docker for use with NVIDIA GPU based containers, including in swarm mode.

## Usage

```puppet
class { 'nvidia_docker_runtime':
  driver_version         => '440.64.00-1',
  nvidia_docker2_version => '2.2.2-1',
}
```

## Limitations

Since GPU UUIDs are needed to specify `node-generic-resources`, and these are not available through facts until
the NVIDIA driver has been installed, it takes two applies to fully setup. Until then swarm cannot use gpu resources.

Due to Docker limitations you can only specify gpus in compose files for compose format 2.3. As `docker stack` requires format 3.0 this means you can't use gpus in stacks.
