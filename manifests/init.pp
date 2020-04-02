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
    ensure => installed
  }
  -> package { 'cuda-drivers':
    ensure => $driver_version,
  }
  # No need to trigger here has should touch /var/run/reboot-required which unattended-upgrades will pick up on

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
    require => [
      Package['cuda-drivers'],
      Class[docker::install],
    ],
  }
  ~> Service['docker']

  $gpu_ids = if 'gpus' in $facts {
    $facts['gpus'].map |$gpu| { $gpu['gpu_uuid'][0,11] }
  } else {
    []
  }
  Package['nvidia-docker2']
  -> augeas { 'daemon.json':
    lens    => 'Json.lns',
    incl    => '/etc/docker/daemon.json',
    changes => [
      'set dict/entry[. = "default-runtime"] default-runtime',
      'set dict/entry[. = "default-runtime"]/string nvidia',
      'set dict/entry[. = "node-generic-resources"] node-generic-resources',
      'touch dict/entry[. = "node-generic-resources"]/array',
    ] + $gpu_ids.map |Integer $i, String $gpu_id| {
      "set dict/entry[. = 'node-generic-resources']/array/string[${$i + 1}] 'gpu=${gpu_id}'"
    },
  }
  ~> Service['docker']

  Package['nvidia-docker2']
  -> file_line { 'uncomment-swarm-resource':
    path  => '/etc/nvidia-container-runtime/config.toml',
    line  => 'swarm-resource = "DOCKER_RESOURCE_GPU"',
    match => '^#?swarm-resource',
  }
  ~> Service['docker']

}
