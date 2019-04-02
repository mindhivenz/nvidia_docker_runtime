# Installs NVIDIA runtime for Docker and the required NVIDIA/CUDA drivers
#
# @summary Allows the use of `docker run --runtime=nvidia ...`
#
# @param driver_version
#   NVIDIA/CUDA driver version, for exmaple: `418.*`. Use to lock down to a specific version. Default: `latest`
#
# @param nvidia_docker2_version
#   NVIDIA runtime version. Use to lock down to a specific version. Default: `latest`
#
# @example
#   include nvidia_docker_runtime

class nvidia_docker_runtime (
  # Driver versions for CUDA versions: https://docs.nvidia.com/deploy/cuda-compatibility/index.html
  String $driver_version         = latest,
  String $nvidia_docker2_version = latest,
) {

  # REVISIT: Want to require docker but causes circular dependencies
  include apt

  $distribution = "${$facts['operatingsystem'].downcase}${$facts['operatingsystemmajrelease']}"
  $cuda_repo = "https://developer.download.nvidia.com/compute/cuda/repos/${regsubst($distribution, '\.', '', 'G')}
    /x86_64"

  $linux_headers_package = "linux-headers-${$facts['kernelrelease']}"
  package { ['build-essential', $linux_headers_package]:
    ensure => latest
  }

  $cuda_key_id = 'AE09FE4BBD223A84B2CCFCE3F60F4B3D7FA2AF80'
  apt::key { $cuda_key_id:
    source => "${cuda_repo}/7fa2af80.pub",
  }

  apt::source { 'cuda':
    comment  => 'Normally installed by the CUDA network deb installer',
    location => $cuda_repo,
    release  => '/',
    repos    => '',
    require  => Apt::Key[$cuda_key_id],
  }

  package { 'cuda-drivers':
    ensure  => $driver_version,
    require => [
      Package['build-essential'],
      Package[$linux_headers_package],
      Apt::Source['cuda'],
    ],
  }

  $nvidia_docker_key_id = 'C95B321B61E88C1809C4F759DDCAE044F796ECB0'
  apt::key { $nvidia_docker_key_id:
    source => 'https://nvidia.github.io/nvidia-docker/gpgkey',
  }

  $nvidia_docker_sources_comment = "See: https://nvidia.github.io/nvidia-docker/${$distribution}/nvidia-docker.list"

  apt::source { 'libnvidia-container':
    comment  => $nvidia_docker_sources_comment,
    location => "https://nvidia.github.io/libnvidia-container/${$distribution}/$(ARCH)",
    release  => '/',
    repos    => '',
    require  => Apt::Key[$nvidia_docker_key_id],
  }

  apt::source { 'nvidia-container-runtime':
    comment  => $nvidia_docker_sources_comment,
    location => "https://nvidia.github.io/nvidia-container-runtime/${$distribution}/$(ARCH)",
    release  => '/',
    repos    => '',
    require  => Apt::Key[$nvidia_docker_key_id],
  }

  apt::source { 'nvidia-docker':
    comment  => $nvidia_docker_sources_comment,
    location => "https://nvidia.github.io/nvidia-docker/${$distribution}/$(ARCH)",
    release  => '/',
    repos    => '',
    require  => Apt::Key[$nvidia_docker_key_id],
  }

  package { 'nvidia-docker2':
    ensure  => $nvidia_docker2_version,
    require => [
      Apt::Source['libnvidia-container'],
      Apt::Source['nvidia-container-runtime'],
      Apt::Source['nvidia-docker'],
      Package['cuda-drivers'],
    ],
  }

  exec { 'restart docker':
    command     => 'pkill -SIGHUP dockerd',
    path        => '/usr/sbin:/usr/bin:/sbin:/bin',
    refreshonly => true,
    subscribe   => Package['nvidia-docker2'],
  }

}
