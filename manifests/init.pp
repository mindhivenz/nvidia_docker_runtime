# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include nvidia_docker_runtime

class nvidia_docker_runtime (
  String $nvidia_driver_version  = '418', # Driver versions: https://www.nvidia.com/object/unix.html
  String $cuda_version           = '10.1',
  String $nvidia_docker2_version = latest,
) {

  # TODO: Want to require docker but causes circular dependencies
  include apt

  # Fill this in from this page (or it's siblings): https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&target_distro=Ubuntu&target_version=1804&target_type=deblocal
  # Driver / CUDA version compatibility: https://docs.nvidia.com/deploy/cuda-compatibility/index.html#binary-compatibility__table-toolkit-driver
  $cuda_version_map_deb_url = {
    '10.1' =>
    'https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda-repo-ubuntu1804-10-0-local-10.0.130-410.48_1.0-1_amd64'
    ,
    '10.0' =>
    'https://developer.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda-repo-ubuntu1804-10-1-local-10.1.105-418.39_1.0-1_amd64.deb'
    ,
  }
  $cuda_key_pub = '7fa2af80'

  $linux_headers_package = "linux-headers-${$facts['kernelrelease']}"
  $cuda_deb_local_path = '/root/cuda.deb'
  $cuda_key_id = $cuda_key_pub.upcase

  package { ['software-properties-common', 'build-essential', $linux_headers_package]:
    ensure => latest
  }

  apt::ppa { 'ppa:graphics-drivers/ppa':
    require => Package['software-properties-common'],
  }

  package { ["nvidia-headless-${$nvidia_driver_version}", "nvidia-utils-${$nvidia_driver_version}"]:
    ensure  => latest,
    require => [Apt::Ppa['ppa:graphics-drivers/ppa']],
  }

  file { $cuda_deb_local_path:
    ensure => file,
    source => $cuda_version_map_deb_url[$cuda_version],
  }

  package { 'cuda-deb-install':
    source   => $cuda_deb_local_path,
    provider => dpkg,
    require  => File[$cuda_deb_local_path],
  }

  apt::key { $cuda_key_id:
    source  => "/var/cuda-repo-${$cuda_version}/${$cuda_key_pub}.pub",
    require => Package['cuda-deb-install'],
  }

  package { 'cuda-drivers':
    require => Apt::Key[$cuda_key_id],
  }

  apt::key { 'C95B321B61E88C1809C4F759DDCAE044F796ECB0':
    source => 'https://nvidia.github.io/nvidia-docker/gpgkey',
  }

  $distribution = "${$facts['operatingsystem'].downcase}${$facts['operatingsystemmajrelease']}"
  $nvidia_docker_sources_comment = "See: https://nvidia.github.io/nvidia-docker/${$distribution}/nvidia-docker.list"

  apt::source { 'libnvidia-container':
    comment  => $nvidia_docker_sources_comment,
    location => "https://nvidia.github.io/libnvidia-container/${$distribution}/$(ARCH)",
    release  => '/',
    repos    => '',
    require  => [Apt::Key['C95B321B61E88C1809C4F759DDCAE044F796ECB0']],
  }

  apt::source { 'nvidia-container-runtime':
    comment  => $nvidia_docker_sources_comment,
    location => "https://nvidia.github.io/nvidia-container-runtime/${$distribution}/$(ARCH)",
    release  => '/',
    repos    => '',
    require  => [Apt::Key['C95B321B61E88C1809C4F759DDCAE044F796ECB0']],
  }

  apt::source { 'nvidia-docker':
    comment  => $nvidia_docker_sources_comment,
    location => "https://nvidia.github.io/nvidia-docker/${$distribution}/$(ARCH)",
    release  => '/',
    repos    => '',
    require  => [Apt::Key['C95B321B61E88C1809C4F759DDCAE044F796ECB0']],
  }

  package { 'nvidia-docker2':
    ensure  => $nvidia_docker2_version,
    require => [
      Apt::Source['libnvidia-container'],
      Apt::Source['nvidia-container-runtime'],
      Apt::Source['nvidia-docker'],
      Package["nvidia-headless-${$nvidia_driver_version}"],
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
