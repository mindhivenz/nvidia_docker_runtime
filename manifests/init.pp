# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include nvidia_docker_runtime

# TODO: facts:
# $ docker inspect -f '{{index .Config.Labels "com.nvidia.volumes.needed"}}' nvidia/cuda
# nvidia_driver
# $ docker inspect -f '{{index .Config.Labels "com.nvidia.cuda.version"}}' nvidia/cuda
# 7.5

# TODO: facts of installed versions of meta packages

# TODO: set default runtime?
# /etc/docker/daemon.json:
# "default-runtime": "nvidia",

# TODO: specify package versions using ensure

class nvidia_docker_runtime (
  String $nvidia_driver_version  = '418', # Driver versions: https://www.nvidia.com/object/unix.html
  String $cuda_version           = '10.1',
  String $nvidia_docker2_version = latest,
  # Boolean $nvidia_utils          = false,
) {

  # TODO: Want to require docker but causes circular dependencies
  include apt

  $distribution = "${$facts['operatingsystem'].downcase}${$facts['operatingsystemmajrelease']}"
  $repo_url_prefix = "https://developer.download.nvidia.com/compute/cuda/repos/${regsubst($distribution, '\.', '', 'G')}/x86_64/"

  # Fill this in from this page (or it's siblings): https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&target_distro=Ubuntu&target_version=1804&target_type=debnetwork
  # Links to the checksums can be found there too
  # Driver / CUDA version compatibility: https://docs.nvidia.com/deploy/cuda-compatibility/index.html#binary-compatibility__table-toolkit-driver
  $cuda_deb = {
    '10.0' => {
      url  => "${repo_url_prefix}cuda-repo-ubuntu1804_10.0.130-1_amd64.deb",
      checksum => '306fbaad179372f5f200c8d2c2c9b8bb',
    },
    '10.1' => {
      url  => "${repo_url_prefix}cuda-repo-ubuntu1804_10.1.105-1_amd64.deb",
      checksum => '68e4203b3a99a292109758d481f6d331',
    },
  }[$cuda_version]

  $linux_headers_package = "linux-headers-${$facts['kernelrelease']}"
  $nvidia_driver_pkg = "nvidia-headless-${$nvidia_driver_version}"
  $nvidia_key_id = 'C95B321B61E88C1809C4F759DDCAE044F796ECB0'

  $cache_dir = '/var/cache/nvidia_docker_runtime'
  $cuda_deb_path = "${$cache_dir}/cuda-${cuda_version}-network.deb"
  $cuda_drivers_pkg = "cuda-runtime-${regsubst($cuda_version, '\.', '-', 'G')}"
  $cuda_key_id = 'AE09FE4BBD223A84B2CCFCE3F60F4B3D7FA2AF80'

  package { ['software-properties-common', 'build-essential', $linux_headers_package]:
    ensure => latest
  }

  apt::ppa { 'ppa:graphics-drivers/ppa':
    require => Package['software-properties-common'],
  }

  package { $nvidia_driver_pkg:
    ensure  => latest,
    require => Apt::Ppa['ppa:graphics-drivers/ppa'],
  }

  # package { "nvidia-utils-${$nvidia_driver_version}":
  #   ensure => ($nvidia_utils ? latest: absent),
  #   require => Apt::Ppa['ppa:graphics-drivers/ppa'],
  # }

  file { $cache_dir:
    ensure => directory,
  }

  # TODO: Throw error if CUDA version map lookup finds nothing

  file { $cuda_deb_path:
    ensure         => present,
    source         => $cuda_deb['url'],
    checksum_value => $cuda_deb['checksum'],
    checksum       => 'md5',
    require        => File[$cache_dir],
  }

  package { 'cuda-deb-install':
    source   => $cuda_deb_path,
    provider => dpkg,
    require  => File[$cuda_deb_path],
  }

  apt::key { $cuda_key_id:
    source => "${repo_url_prefix}${$cuda_key_id[-8,8].downcase}.pub",
  }

  package { $cuda_drivers_pkg:
    require => [
      Package['build-essential'],
      Package[$linux_headers_package],
      Package['cuda-deb-install'],
      Apt::Key[$cuda_key_id],
    ],
  }

  apt::key { $nvidia_key_id:
    source => 'https://nvidia.github.io/nvidia-docker/gpgkey',
  }

  $nvidia_docker_sources_comment = "See: https://nvidia.github.io/nvidia-docker/${$distribution}/nvidia-docker.list"

  apt::source { 'libnvidia-container':
    comment  => $nvidia_docker_sources_comment,
    location => "https://nvidia.github.io/libnvidia-container/${$distribution}/$(ARCH)",
    release  => '/',
    repos    => '',
    require  => Apt::Key[$nvidia_key_id],
  }

  apt::source { 'nvidia-container-runtime':
    comment  => $nvidia_docker_sources_comment,
    location => "https://nvidia.github.io/nvidia-container-runtime/${$distribution}/$(ARCH)",
    release  => '/',
    repos    => '',
    require  => Apt::Key[$nvidia_key_id],
  }

  apt::source { 'nvidia-docker':
    comment  => $nvidia_docker_sources_comment,
    location => "https://nvidia.github.io/nvidia-docker/${$distribution}/$(ARCH)",
    release  => '/',
    repos    => '',
    require  => Apt::Key[$nvidia_key_id],
  }

  package { 'nvidia-docker2':
    ensure  => $nvidia_docker2_version,
    require => [
      Apt::Source['libnvidia-container'],
      Apt::Source['nvidia-container-runtime'],
      Apt::Source['nvidia-docker'],
      Package[$nvidia_driver_pkg],
      Package[$cuda_drivers_pkg],
    ],
  }

  exec { 'restart docker':
    command     => 'pkill -SIGHUP dockerd',
    path        => '/usr/sbin:/usr/bin:/sbin:/bin',
    refreshonly => true,
    subscribe   => Package['nvidia-docker2'],
  }

}
