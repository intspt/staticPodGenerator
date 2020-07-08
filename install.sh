#/usr/bin/env bash

gem build staticPodGenerator.gemspec
sudo gem uninstall staticPodGenerator
sudo gem install staticPodGenerator-0.1.1.gem -n /usr/local/bin
rm staticPodGenerator-0.1.1.gem