node.set['apt']['confd']['install_recommends'] = false

include_recipe 'apt'

apt_repository 'docker' do
  uri 'http://apt.dockerproject.org/repo'
  components %w(debian-jessie main)
  keyserver 'p80.pool.sks-keyservers.net'
  key '58118E89F3A912897C070ADBF76221572C52609D'
  cache_rebuild true
end

docker_service 'default' do
  install_method 'package'
  log_driver 'journald'
end
