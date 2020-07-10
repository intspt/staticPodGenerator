#/usr/bin/env bash

gem build staticPodGenerator.gemspec
sudo gem uninstall staticPodGenerator -a -x
sudo gem install staticPodGenerator-0.1.2.gem -n /usr/local/bin
rm staticPodGenerator-0.1.2.gem