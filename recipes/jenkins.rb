include_recipe 'dockerhp::base'

resources('service[collectd]').action :nothing

node.default['apt']['confd']['install_recommends'] = false
include_recipe 'apt'

package 'openjdk-7-jre-headless'

node.default['jenkins']['master']['install_method'] = 'package'
node.default['jenkins']['master']['version'] = '1.642.3'
include_recipe 'jenkins::master'

repo = resources('apt_repository[jenkins]')
repo.uri 'http://pkg.jenkins-ci.org/debian-stable'

group 'docker' do
  action :modify
  members %w(jenkins)
  notifies :restart, 'service[jenkins]'
end

ruby_block 'load jenkins credential' do
  block do
    require 'openssl'
    require 'net/ssh'

    key = ::OpenSSL::PKey::RSA.new ::File.read Chef::Config[:client_key]

    node.run_state[:jenkins_private_key] = key.to_pem

    jenkins = resources('jenkins_user[chef]')
    jenkins.public_keys ["#{key.ssh_type} #{[key.to_blob].pack('m0')}"]
  end
end

jenkins_user 'chef'

# FIXME Make this more idempotent
jenkins_script 'update plugins' do
  command <<-eos.gsub(/^\s+/, '')
    import jenkins.model.Jenkins;

    pm = Jenkins.instance.pluginManager
    pm.doCheckUpdatesServer()

    uc = Jenkins.instance.updateCenter
    pm.plugins.each { plugin ->
      update = uc.getPlugin(plugin.shortName).deploy(true)
      update.get()
    }
    Jenkins.instance.restart()
  eos
end

# FIXME Make this more idempotent
jenkins_script 'setup plugins' do
  command <<-eos.gsub(/^\s+/, '')
    import jenkins.model.Jenkins;

    pm = Jenkins.instance.pluginManager

    uc = Jenkins.instance.updateCenter
    pm.plugins.each { plugin ->
      plugin.disable()
    }

    def activatePlugin(plugin) {
      if (! plugin.isEnabled()) {
        plugin.enable()
      }

      plugin.getDependencies().each {
        activatePlugin(pm.getPlugin(it.shortName))
      }
    }

    ["git", "workflow-aggregator", "github-oauth"].each {
      if (! pm.getPlugin(it)) {
        deployment = uc.getPlugin(it).deploy(true)
        deployment.get()
      }
      activatePlugin(pm.getPlugin(it))
    }
    Jenkins.instance.restart()
  eos
end

jenkins_script 'secure jenkins' do
  command <<-eos.gsub(/^\s+/, '')
    import jenkins.model.Jenkins;
    import org.jenkinsci.plugins.GithubSecurityRealm;

    Jenkins.instance.securityRealm = new GithubSecurityRealm(
        'https://github.com', 'https://api.github.com', 'x', 'y')

    permissions = new hudson.security.GlobalMatrixAuthorizationStrategy()

    permissions.add(Jenkins.ADMINISTER, 'aespinosa')
    permissions.add(Jenkins.ADMINISTER, 'chef')
    permissions.add(hudson.model.View.READ, 'anonymous')
    permissions.add(hudson.model.Item.READ, 'anonymous')
    permissions.add(Jenkins.READ, 'anonymous')

    Jenkins.instance.authorizationStrategy = permissions

    Jenkins.instance.save()
  eos
end
