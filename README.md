
# nvidia_docker_runtime

This is a PDK based module https://puppet.com/pdk/latest/pdk_generating_modules.html .

#### Table of Contents

1. [Description](#description)
3. [Usage - Configuration options and additional functionality](#usage)

## Description

Modifies Docker for use with NVIDIA GPU based containers, including in swarm mode. 

## Setup

## Usage

```puppet
class { 'nvidia_docker_runtime':
  driver_version         => '440.64.00-1',
  nvidia_docker2_version => '2.2.2-1',
}
```
