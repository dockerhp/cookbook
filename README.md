# dockerhp Cookbook

Infrastructure to support a Docker-based deployment

* Monitoring
* Logging
* Base Host configuration

Supplementary material for the book [*Docker High Performance*](http://amzn.com/1785886800).

# Recipes

## dockerhp::base

The base recipe to setup a basic configuration of Docker. Adding this to the
run_list of a node does the following:

* docker daemon
* docker daemon to log to Debian Jessie's journal
* forward all rsyslog entries to a remote syslog.  It will forward to a Chef
  Node with an attribute `node['is_logstash'] = true`.
* collectd with basic and container metric collection. It will send Graphite
  metrics to a Chef Node with an attribute `node[is_graphite] = true`.

# License

Copyright 2016 Allan Espinosa

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
