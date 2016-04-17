node.set['apt']['confd']['install_recommends'] = false

include_recipe 'apt'

apt_repository 'docker' do
  uri 'http://apt.dockerproject.org/repo'
  distribution 'debian-jessie'
  components %w(main)
  keyserver 'p80.pool.sks-keyservers.net'
  key '58118E89F3A912897C070ADBF76221572C52609D'
  cache_rebuild true
end

docker_service 'default' do
  install_method 'package'
  package_version '1.11.0-0~jessie'
  log_driver 'journald'
end

# Doesn't do anything. But useful for placing this recipe in a test hardness
# using proxy repositories. Makes the tests much much faster
docker_registry 'wrap' do
  action :nothing
end

service 'rsyslog'

logstash_machine = search(:node, 'is_logstash:true').first

template '/etc/rsyslog.d/10-forward.conf' do
  source 'forward-syslog.conf.erb'
  variables lazy { {syslog_endpoint: logstash_machine['fqdn']} }
  notifies :restart, 'service[rsyslog]'
  not_if { logstash_machine.nil? }
end

package 'collectd-core' # FIXME just make this a dependency

apt_repository 'allan_vendor' do
  uri 'https://packagecloud.io/allan/vendor/debian'
  components %w(main)
  key 'https://packagecloud.io/gpg.key'
  cache_rebuild true
end

package 'libpython2.7'
package 'docker-collectd-plugin' # FIXME just make this a dependency

service 'collectd' do
  action [:enable, :start]
end

graphite_machine = search(:node, 'is_graphite:true').first

template '/etc/collectd/collectd.conf' do
  source 'collectd.conf.erb'
  variables lazy { {graphite_endpoint: graphite_machine['fqdn']} }
  notifies :restart, 'service[collectd]'
  not_if { graphite_machine.nil? }
end
