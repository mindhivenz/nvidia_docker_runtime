# Installs NVIDIA runtime for Docker and the required NVIDIA/CUDA drivers
#
# @summary Allows the use of `docker run --runtime=nvidia ...`
#
# @param driver_version
#   NVIDIA/CUDA driver version, for exmaple: `418.40.04-1`. Use to lock down to a specific version. Default: `latest`
#
# @param nvidia_docker2_version
#   NVIDIA Docker runtime version, for example: `2.0.3+docker18.09.4-1`. Use to lock down to a specific version. Default: `latest`
#
# Driver versions for CUDA versions: https://docs.nvidia.com/deploy/cuda-compatibility/index.html
#
# @example
#   include nvidia_docker_runtime
class nvidia_docker_runtime (
  String $driver_version         = latest,
  String $nvidia_docker2_version = latest,
) {

  include apt

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
  -> package { 'nvidia-docker2':
    ensure  => $nvidia_docker2_version,
    require => Package['cuda-drivers'],
  }
  ~> exec { 'restart docker':
    command     => 'pkill -SIGHUP dockerd',
    path        => '/usr/sbin:/usr/bin:/sbin:/bin',
    refreshonly => true,
    subscribe   => Package['nvidia-docker2'],
  }

}
