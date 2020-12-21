#/usr/bin/env bash

gem build staticPodGenerator.gemspec
sudo gem uninstall staticPodGenerator -a -x
sudo gem install staticPodGenerator-3.0.3.gem -n /usr/local/bin
rm staticPodGenerator-3.0.3.gem