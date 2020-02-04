# Installs NVIDIA runtime for Docker and the required NVIDIA/CUDA drivers
#
# @summary Allows the use of `docker run --runtime=nvidia ...`
#
# @param driver_version
#   NVIDIA/CUDA driver version, for exmaple: `418.40.04-1`. Use to lock down to a specific version. Default: `latest`
#
# @param nvidia_container_toolkit_version
#   NVIDIA container toolkit version, for example: `1.0.5-1`. Use to lock down to a specific version. Default: `latest`
#
# Driver versions for CUDA versions: https://docs.nvidia.com/deploy/cuda-compatibility/index.html
#
# @example
#   include nvidia_docker_runtime
class nvidia_docker_runtime (
  String $driver_version                   = latest,
  String $nvidia_container_toolkit_version = latest,
) {

  include apt
  include docker

  $distribution = "${$facts['operatingsystem'].downcase}${$facts['operatingsystemmajrelease']}"
  $distribution_no_dot = regsubst($distribution, '\.', '', 'G')
  $cuda_arch = $facts['architecture'] ? {
    'amd64' => 'x86_64',
    default => $facts['architecture'],
  }
  $cuda_repo = "https://developer.download.nvidia.com/compute/cuda/repos/${$distribution_no_dot}/${cuda_arch}"

  apt::key { 'AE09FE4BBD223A84B2CCFCE3F60F4B3D7FA2AF80':
    source => "${cuda_repo}/7fa2af80.pub",
  }
  -> apt::source { 'cuda':
    comment  => 'Normally installed by the CUDA network deb installer',
    location => $cuda_repo,
    release  => '/',
    repos    => '',
  }
  ~> Exec['apt_update']
  -> package { ['build-essential', "linux-headers-${$facts['kernelrelease']}"]:
    ensure => present
  }
  -> package { 'cuda-drivers':
    ensure => $driver_version,
  }

  apt::key { 'C95B321B61E88C1809C4F759DDCAE044F796ECB0':
    source => 'https://nvidia.github.io/nvidia-docker/gpgkey',
  }
  -> ['libnvidia-container', 'nvidia-container-runtime', 'nvidia-docker'].map |$source| {
    apt::source { $source:
      comment  => "See: https://nvidia.github.io/nvidia-docker/${$distribution}/nvidia-docker.list",
      location => "https://nvidia.github.io/${$source}/${$distribution}/$(ARCH)",
      release  => '/',
      repos    => '',
    }
  }
  ~> Exec['apt_update']
  -> package { 'nvidia-container-toolkit':
    ensure  => $nvidia_container_toolkit_version,
    require => Package['cuda-drivers'],
  }
  ~> Service['docker']

}
