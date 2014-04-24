#/bin/bash
set -x
set -e

apt-get install build-essential cpanminus git
cpanm install JSON LWP::UserAgent LWP::Protocol::http::SocketUnixAlt Config::IniFiles File::Slurp
cpanm install git://github.com/wgerlach/USAGEPOD.git

# SHOCK::Client
mkdir -p /usr/share/perl5/SHOCK
wget -o /usr/share/perl5/SHOCK/Client.pm https://raw.githubusercontent.com/MG-RAST/Shock/master/libs/SHOCK/Client.pm

wget https://raw.githubusercontent.com/wgerlach/SODOKU/master/deploy_software.pl
chmod +x deploy_software.pl