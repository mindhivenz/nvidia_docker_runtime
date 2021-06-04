# nvidia_docker_runtime

## Description

Installs NVIDIA CUDA drivers and modifies Docker for use with NVIDIA GPU based containers, including in swarm mode.

## Usage

```puppet
class { 'nvidia_docker_runtime':
  driver_version         => '460.73.01-1',
  nvidia_docker2_version => '2.5.0-1',
}
```

## Limitations

Since GPU UUIDs are needed to specify `node-generic-resources`, and these are not available through facts until
the NVIDIA driver has been installed, it takes two applies to fully setup. Swarm cannot use gpu resources until the second apply.
