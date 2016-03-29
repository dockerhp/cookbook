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

    ["git", "workflow-aggregator"].each {
      if (! pm.getPlugin(it)) {
        deployment = uc.getPlugin(it).deploy(true)
        deployment.get()
      }
      activatePlugin(pm.getPlugin(it))
    }
    Jenkins.instance.restart()
  eos
end
