#/usr/bin/env bash

gem build staticPodGenerator.gemspec
sudo gem uninstall staticPodGenerator -a -x
sudo gem install staticPodGenerator-2.0.0.gem -n /usr/local/bin
rm staticPodGenerator-2.0.0.gem