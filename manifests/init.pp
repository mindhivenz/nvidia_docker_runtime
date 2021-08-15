# Installs NVIDIA runtime for Docker and the required NVIDIA/CUDA drivers
#
# @summary Allows the use of `docker run --runtime=nvidia ...`
#
# @param driver_version
#   NVIDIA/CUDA driver version, for exmaple: `440.64.00-1`. Use to lock down to a specific version. Default: `installed`
#
# @param nvidia_docker2_version
#   nvidia_docker2 version, for example: `2.2.2-1`. Use to lock down to a specific version. Default: `installed`
#
# Driver versions for CUDA versions: https://docs.nvidia.com/deploy/cuda-compatibility/index.html
#
# @example
#   include nvidia_docker_runtime
class nvidia_docker_runtime (
  String $driver_version         = installed,
  String $nvidia_docker2_version = installed,
) {

  include apt
  include docker

  $distribution = "${$facts[os][name].downcase}${$facts[os][release][major]}"
  $distribution_no_dot = regsubst($distribution, '\.', '', 'G')
  $cuda_arch = $facts[architecture] ? {
    'amd64' => 'x86_64',
    default => $facts[architecture],
  }
  $cuda_repo = "https://developer.download.nvidia.com/compute/cuda/repos/${$distribution_no_dot}/${cuda_arch}"

  $cuda_driver_dependencies = ['build-essential', "linux-headers-${$facts[kernelrelease]}"]
  ensure_packages($cuda_driver_dependencies)

  apt::key { 'AE09FE4BBD223A84B2CCFCE3F60F4B3D7FA2AF80':
    ensure => refreshed,
    source => "${cuda_repo}/7fa2af80.pub",
  }
  -> apt::source { 'cuda':
    comment  => 'Normally installed by the CUDA network deb installer',
    location => $cuda_repo,
    release  => '/',
    repos    => '',
  }
  ~> Exec['apt_update']
  -> package { 'cuda-drivers':
    ensure  => $driver_version,
    require => Package[$cuda_driver_dependencies],
  }
  ~> reboot { 'drivers-installed':
    apply => immediately,
  }

  Package['cuda-drivers']
  -> exec { 'Trigger if driver version mismatch':
    command  => '/bin/true',
    onlyif   => '/usr/bin/nvidia-smi 2>&1 | grep "version mismatch"',
    provider => shell,
  }
  ~> reboot { 'version-mismatch':
    apply => finished,
  }

  apt::key { 'C95B321B61E88C1809C4F759DDCAE044F796ECB0':
    ensure => refreshed,
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
    require => [
      Package['cuda-drivers'],
      Class[docker::install],
    ],
  }
  ~> Service['docker']

  # REVISIT: Is this needed or does nvidia-docker2 do it for us?
  # Package['nvidia-docker2']
  # -> augeas { 'daemon.json':
  #   lens    => 'Json.lns',
  #   incl    => '/etc/docker/daemon.json',
  #   changes => [
  #     'set dict/entry[. = "default-runtime"] default-runtime',
  #     'set dict/entry[. = "default-runtime"]/string nvidia',
  #   ],
  # }
  # ~> Service['docker']

  Class['nvidia_docker_runtime'] -> Docker::Exec <| |>
  Class['nvidia_docker_runtime'] -> Docker::Run <| |>
  Class['nvidia_docker_runtime'] -> Docker::Services <| |>
  Class['nvidia_docker_runtime'] -> Docker::Stack <| |>
  Class['nvidia_docker_runtime'] -> Docker_stack <| |>

}
