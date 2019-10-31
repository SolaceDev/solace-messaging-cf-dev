sudo locale-gen en_CA.UTF-8
apt-get update

echo "Adding Ruby"
sudo apt-get -y install ruby ruby-dev

# Installing ruby following instructions from https://tecadmin.net/install-ruby-on-rails-on-ubuntu/
echo "Installing rvm (ruby version manager)"
sudo apt-get -y install gnupg2
sudo gpg2 --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | bash -s stable
source /home/vagrant/.rvm/scripts/rvm
source /home/vagrant/.rvm/scripts/rvm || source /etc/profile.d/rvm.sh

# Ruby for Tile-generator
echo "Installing ruby 2.3.3"
rvm requirements
rvm install 2.3.3
rvm use 2.3.3 --default

sudo gem install colorize
sudo apt-get -y install zsh
sudo chsh -s $(which zsh)
sudo apt-get -y install subversion
sudo apt-get -y install rake
sudo apt-get -y install git

echo "Installing bosh cli"
wget -q --directory-prefix=/tmp https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-2.0.40-linux-amd64
sudo mv /tmp/bosh-cli-2.0.40-linux-amd64 /usr/local/bin/bosh
sudo chmod +x /usr/local/bin/bosh
echo "Installed bosh: "`bosh -v`


echo "Adding cf"
sudo curl -s -L "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" | tar -zx && mv cf /usr/bin/cf
which cf

echo "Adding jq"
sudo apt-get -y install jq
which jq

echo "Adding Python tools"
sudo apt-get -y install python-virtualenv
sudo apt-get -y install python-pip python3-pip
sudo pip install shyaml
sudo pip3 install pyyaml

echo "Adding Java"
sudo add-apt-repository ppa:openjdk-r/ppa -y
sudo apt-get update   
sudo apt-get -y install openjdk-8-jdk 
sudo apt-get -y install openjdk-8-jre
sudo apt-get -y install ant

sudo apt-get -y install watch

echo "Adding supporting perl modules used by rs-* scripts"
sudo apt-get -y install libexpect-perl
sudo apt-get -y install libterm-readkey-perl

echo "Installing ruby"
sudo apt-get -y install ruby ruby-dev

sudo gem install bundle

echo "Installing Cloud Foundry uaac"
sudo gem install cf-uaac



echo '' >> .profile
if [ -n "$PUBSUBPLUS_CF_DEV_REPO" ]; then
	echo "export PUBSUBPLUS_CF_DEV_REPO=${PUBSUBPLUS_CF_DEV_REPO}" >> .profile
else
	echo 'export PUBSUBPLUS_CF_DEV_REPO=${PUBSUBPLUS_CF_DEV_REPO:-"https://github.com/SolaceLabs/pubsubplus-cf-dev.git"}' >> .profile
fi
echo 'echo "Will use pubsubplus-cf-dev from git repo $PUBSUBPLUS_CF_DEV_REPO"' >> .profile

if [ -n "$CF_PUBSUBPLUS_DEPLOYMENT" ]; then 
	echo "export CF_PUBSUBPLUS_DEPLOYMENT_REPO=$CF_PUBSUBPLUS-DEPLOYMENT" >> .profile
fi


if [ -n "$BRANCH" ]; then
	echo "export BRANCH=${BRANCH}" >> .profile
fi

echo 'if [ ! -d ~/pubsubplus-cf-dev ]; then' >> .profile
echo ' echo "Fetching pubsubplus-cf-dev inside cli-tools"' >> .profile 
echo ' git clone $PUBSUBPLUS_CF_DEV_REPO' >> .profile
echo ' if [ ! -z "$BRANCH" ]; then' >> .profile
echo '    cd pubsubplus-cf-dev' >> .profile
echo '    git checkout $BRANCH' >> .profile
echo '    git submodule update --init --recursive' >> .profile
# in older versions of git if you use --init option, already initialized submodules may not be updated. (this is why there are two git submodule updates) 
echo '    git submodule update --recursive' >> .profile
echo ' fi' >> .profile
echo 'fi' >> .profile

echo '' >> .profile
echo '# Using pubsubplus-cf-dev/.profile' >> .profile
echo '[[ -e ~/pubsubplus-cf-dev/.profile ]] && source ~/pubsubplus-cf-dev/.profile || echo "~/pubsubplus-cf-dev/.profile was not found"' >> .profile
echo '' >> .profile

