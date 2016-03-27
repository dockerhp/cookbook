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

jenkins_script 'setup plugins' do
  command <<-eos.gsub(/^\s+/, '')
    import jenkins.model.Jenkins;

    pm = Jenkins.instance.pluginManager

    pm.plugins.each { it.disable() }

    pm.doCheckUpdatesServer()
    uc = Jenkins.instance.updateCenter

    def activatePlugin(plugin) {
      if (! plugin.isEnabled()) {
        plugin.enable()
      }

      plugin.getDependencies().each {
        activatePlugin(pm.getPlugin(it.shortName))
      }
    }

    ["git", "workflow-aggregator"].each {
      if (! pm.getPlugin(it)) {
        deployment = uc.getPlugin(it).deploy(true)
        deployment.get()
      }
      activatePlugin(pm.getPlugin(it))
    }
  eos
end
