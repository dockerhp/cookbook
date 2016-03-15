include_recipe 'dockerhp::base'

apt_repository 'elasticsearch' do
  uri 'http://packages.elastic.co/elasticsearch/1.7/debian'
  components %w(stable main)
  keyserver 'pgp.mit.edu'
  key '46095ACC8548582C1A2699A9D27D666CD88E42B4'
  cache_rebuild true
end

package 'elasticsearch'

package 'openjdk-7-jre-headless'

service 'elasticsearch' do
  action [:enable, :start]
end

docker_image 'kibana' do
  tag '4.1.1'
end

docker_container 'kibana' do
  tag '4.1.1'
  port '80:5601'
  env ["ELASTICSEARCH_URL=http://#{node[:ipaddress]}:9200"]
  action :create
end

systemd_service 'kibana' do
  description 'Kibana'

  requires 'docker.service elasticsearch.service'
  after 'docker.service elasticsearch.service'

  service do
    exec_start '/usr/bin/docker start -a kibana'
    exec_stop '/usr/bin/docker stop kibana'
  end

  install do
    wanted_by 'multi-user.target'
  end
end

service 'kibana' do
  action [:enable, :start]
end

docker_image 'aespinosa/logstash'

docker_container 'logstash' do
  command '-f /etc/logstash.conf'
  extra_hosts ["elasticsearch:#{node[:ipaddress]}"]
  repo aespinosa/logstash'
  port '514:1514/udp'
  action :create
end

systemd_service 'logstash' do
  description 'Logstash'

  requires 'docker.service elasticsearch.service'
  after 'docker.service elasticsearch.service'

  service do
    exec_start '/usr/bin/docker start -a logstash'
    exec_stop '/usr/bin/docker stop logstash'
  end

  install do
    wanted_by 'multi-user.target'
  end
end

service 'logstash' do
  action [:enable, :start]
  notifies :run, 'ruby_block[set logstash toggle]'
end

ruby_block 'set logstash toggle' do
  block do
    node.set['is_logstash'] = true
  end
  action :nothing
end
