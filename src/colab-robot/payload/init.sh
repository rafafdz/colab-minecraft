# The following variables will be set dinamically (injected by node):
# server_user
# server_pass
# server_domain
# server_ssh_port
# target_port
# connect_url
# cookies

# TODO: Create special user on Remote server for forwarding!

apt update
apt-get -qq install -o=Dpkg::Use-Pty=0 openssh-server pwgen
apt install -y sshpass tmux htop nano openjdk-8-jre-headless
update-java-alternatives --set java-1.8.0-openjdk-amd64

# Set default passowrd
# echo root:password | chpasswd

mkdir -p /var/run/sshd
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
mkdir ~/.ssh
touch ~/.ssh/known_hosts

cat colab_vps.pub > ~/.ssh/authorized_keys
chmod 600 colab_vps

# Start the ssh server!
sh -c /usr/sbin/sshd &

# Setup the keep-alive daemon!
nohup sh -c "while true; do curl -s $connect_url -H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) \
AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4182.0 Safari/537.36' \
-H 'x-colab-tunnel: Google' -H  'cookie: $cookies' >> out.log; sleep 30; done" &

# Add new user
adduser --disabled-password --gecos "" vps-user

# Copy the key so we can have direct access to the user also!
mkdir /home/vps-user/.ssh
cp ~/.ssh/authorized_keys /home/vps-user/.ssh/authorized_keys

# Fix for IP on servers!
touch /home/vps-user/ssh-mc-daemon.log
chmod ugo+x /home/vps-user/ssh-mc-daemon.log

# su vps-user -c "mkdir mc-server"
# Set with root privileges
# usermod -aG sudo vps-user
# echo "vps-user:vpspassword123" | chpasswd

# Execute the following commands as vps-user
# Should use the root account for tunnels and hav key for remtoe server!
sh -c "while true; do sshpass -p $server_pass ssh -p $server_ssh_port -NT \
-o ServerAliveInterval=60 -o 'ExitOnForwardFailure=yes' \
 -o 'UserKnownHostsFile=/dev/null' -o 'StrictHostKeyChecking=no' \
 -R $target_port:localhost:22 $server_user@$server_domain; done" &
