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

jenkins_user 'chef' do
  id "chef@#{Chef::Config[:node_name]}"
  full_name "Chef"
end


jenkins_script 'get list of latest plugins' do
  command <<-eos.gsub(/^\s+/, '')
    pm = jenkins.model.instance.pluginManager
    pm.doCheckUpdatesServer()
  eos

  not_if do
    update_frequency = 86_400 # daily
    update_file = '/var/lib/jenkins/updates/default.json'
    ::File.exists?(update_file) &&
      ::File.mtime(update_file) > Time.now - update_frequency
  end
end

jenkins_script 'update plugins' do
  command <<-eos.gsub(/^\s+/, '')
    import jenkins.model.Jenkins;

    pm = Jenkins.instance.pluginManager

    uc = Jenkins.instance.updateCenter
    updated = false
    pm.plugins.each { plugin ->
      if (uc.getPlugin(plugin.shortName).version != plugin.version) {
        update = uc.getPlugin(plugin.shortName).deploy(true)
        update.get()
        updated = true
      }
    }
    if (updated) {
      Jenkins.instance.restart()
    }
  eos
end

jenkins_script 'setup plugins' do
  command <<-eos.gsub(/^\s+/, '')
    import jenkins.model.Jenkins;

    pm = Jenkins.instance.pluginManager

    uc = Jenkins.instance.updateCenter
    pm.plugins.each { plugin ->
      plugin.disable()
    }

    deployed = false
    def activatePlugin(plugin) {
      if (! plugin.isEnabled()) {
        plugin.enable()
        deployed = true
      }

      plugin.getDependencies().each {
        activatePlugin(pm.getPlugin(it.shortName))
      }
    }

    ["git", "workflow-aggregator", "github-oauth", "job-dsl", "extended-read-permission"].each {
      if (! pm.getPlugin(it)) {
        deployment = uc.getPlugin(it).deploy(true)
        deployment.get()
      }
      activatePlugin(pm.getPlugin(it))
    }

    if (deployed) {
      Jenkins.instance.restart()
    }
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
    permissions.add(Jenkins.ADMINISTER, '#{resources('jenkins_user[chef]').id}')
    permissions.add(hudson.model.View.READ, 'anonymous')
    permissions.add(hudson.model.Item.READ, 'anonymous')
    permissions.add(Jenkins.READ, 'anonymous')

    Jenkins.instance.authorizationStrategy = permissions

    Jenkins.instance.save()
  eos
end

jenkins_script 'install seed-job' do
  command <<-eos.gsub(/^\s+/, '')
    import jenkins.model.Jenkins;
    import hudson.model.FreeStyleProject;

    job = Jenkins.instance.createProject(FreeStyleProject, 'seed-job')
    job.displayName = 'Seed Job'

    builder = new javaposse.jobdsl.plugin.ExecuteDslScripts(
      new javaposse.jobdsl.plugin.ExecuteDslScripts.ScriptLocation(
          'false',
          'samples.groovy',
          null),
      false,
      javaposse.jobdsl.plugin.RemovedJobAction.DELETE, 
      javaposse.jobdsl.plugin.RemovedViewAction.DELETE, 
      javaposse.jobdsl.plugin.LookupStrategy.JENKINS_ROOT, 
    )
    job.buildersList.add(builder)

    job.save()
  eos
  not_if { ::File.exists? '/var/lib/jenkins/jobs/seed-job/config.xml' }
end

directory '/var/lib/jenkins/jobs/seed-job/workspace' do
  owner 'jenkins'
end

cookbook_file '/var/lib/jenkins/jobs/seed-job/workspace/samples.groovy' do
  source 'samples.groovy'
  notifies :execute, 'jenkins_script[build seed-job]'
end

jenkins_script 'build seed-job' do
  command <<-eos.gsub(/^\s+/, '')
    import jenkins.model.Jenkins;
    job = Jenkins.instance.getItem('seed-job')
    job.scheduleBuild(new hudson.model.Cause.UserIdCause())
  eos
  action :nothing
end

package 'git-core'
