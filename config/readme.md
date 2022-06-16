# Config JSON format

* `headless` : Wether to run without GUI or not. Usefull if running script in a headless server. Requires `xvfb-run` to be installed.
* `server_user`:  The user for the forwarding server. Will be used by the colab instance to open a reverse tunnel via ssh. You may want to create a separate user for increased security.
* `server_pass`:  SSH forwarding server password.
* `server_ssh_port`: Port of your SSH server. Tipically 22
* `server_domain`: Your public ip / domain so the Colab instance can find your server and open the reverse tunnels.
* `webserver_port`: The port where the webserver will be open on the colab-robot. 


Note: Please make sure that all the ports given are open for public connections. Port 25565 should be open too.

